#include "quick_add_window.h"
#include "resource.h"
#include <iostream>
#include <sstream>
#include <ctime>
#include <cmath>
#include <dwmapi.h>
#include <algorithm>
#include <windowsx.h>
#include <commctrl.h>

#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "comctl32.lib")

// Static member definitions
const wchar_t* QuickAddWindow::kWindowClassName = L"AmberQuickAddWindow";
bool QuickAddWindow::class_registered_ = false;

// ============================================================================
// Constructor / Destructor
// ============================================================================

QuickAddWindow::QuickAddWindow(const std::wstring& windowId, const flutter::EncodableMap* arguments)
    : window_id_(windowId) {

    // Initialize GDI+
    Gdiplus::GdiplusStartupInput gdiplusStartupInput;
    Gdiplus::GdiplusStartup(&gdiplus_token_, &gdiplusStartupInput, nullptr);

    // Parse initial arguments
    if (arguments) {
        auto dateIt = arguments->find(flutter::EncodableValue("selectedDate"));
        if (dateIt != arguments->end()) {
            if (auto* val = std::get_if<double>(&dateIt->second)) {
                selected_date_ms_ = *val;
            }
        }

        auto tagsIt = arguments->find(flutter::EncodableValue("tags"));
        if (tagsIt != arguments->end()) {
            const auto* tagsList = std::get_if<flutter::EncodableList>(&tagsIt->second);
            if (tagsList) {
                for (const auto& tag : *tagsList) {
                    if (auto* str = std::get_if<std::string>(&tag)) {
                        available_tags_.push_back(NativeWindowManager::Utf8ToWString(*str));
                    }
                }
            }
        }

        auto listsIt = arguments->find(flutter::EncodableValue("taskLists"));
        if (listsIt != arguments->end()) {
            const auto* listsList = std::get_if<flutter::EncodableList>(&listsIt->second);
            if (listsList) {
                for (const auto& listItem : *listsList) {
                    if (const auto* map = std::get_if<flutter::EncodableMap>(&listItem)) {
                        std::wstring id, name;
                        auto idIt = map->find(flutter::EncodableValue("id"));
                        auto nameIt = map->find(flutter::EncodableValue("name"));
                        if (idIt != map->end()) {
                            if (auto* str = std::get_if<std::string>(&idIt->second)) {
                                id = NativeWindowManager::Utf8ToWString(*str);
                            }
                        }
                        if (nameIt != map->end()) {
                            if (auto* str = std::get_if<std::string>(&nameIt->second)) {
                                name = NativeWindowManager::Utf8ToWString(*str);
                            }
                        }
                        if (!id.empty() && !name.empty()) {
                            available_task_lists_.push_back({id, name});
                        }
                    }
                }
            }
        }
    }

    if (selected_date_ms_ == 0) {
        selected_date_ms_ = static_cast<double>(std::time(nullptr)) * 1000.0;
    }

    // Create brushes
    white_brush_ = CreateSolidBrush(kWhiteColor);
    amber_brush_ = CreateSolidBrush(kAmberColor);
    gray_brush_ = CreateSolidBrush(kLightGrayColor);

    // Get DPI for font scaling (before window creation)
    HDC hdc = GetDC(nullptr);
    int dpiX = GetDeviceCaps(hdc, LOGPIXELSX);
    ReleaseDC(nullptr, hdc);
    float fontScale = dpiX / 96.0f;

    // Create fonts (matching macOS: Segoe UI, medium weight)
    // Font sizes scaled by DPI
    main_font_ = CreateFontW(
        static_cast<int>(-18 * fontScale), 0, 0, 0, FW_MEDIUM, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");

    title_font_ = CreateFontW(
        static_cast<int>(-24 * fontScale), 0, 0, 0, FW_MEDIUM, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");

    button_font_ = CreateFontW(
        static_cast<int>(-13 * fontScale), 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");

    placeholder_font_ = CreateFontW(
        static_cast<int>(-18 * fontScale), 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");

    // Load logo from embedded resource
    LoadLogoFromResource();
}

QuickAddWindow::~QuickAddWindow() {
    Destroy();

    // Delete GDI objects
    if (main_font_) DeleteObject(main_font_);
    if (title_font_) DeleteObject(title_font_);
    if (button_font_) DeleteObject(button_font_);
    if (placeholder_font_) DeleteObject(placeholder_font_);
    if (white_brush_) DeleteObject(white_brush_);
    if (amber_brush_) DeleteObject(amber_brush_);
    if (gray_brush_) DeleteObject(gray_brush_);

    // Release logo bitmap
    logo_bitmap_.reset();

    // Shutdown GDI+
    if (gdiplus_token_) {
        Gdiplus::GdiplusShutdown(gdiplus_token_);
    }
}

// ============================================================================
// Logo Loading from Embedded Resource
// ============================================================================

bool QuickAddWindow::LoadLogoFromResource() {
    HMODULE hModule = GetModuleHandle(nullptr);
    HRSRC hResource = FindResourceW(hModule, MAKEINTRESOURCEW(IDB_AMBER_LOGO), L"RCDATA");
    if (!hResource) {
        std::cerr << "[QuickAddWindow] Failed to find logo resource" << std::endl;
        return false;
    }

    HGLOBAL hMemory = LoadResource(hModule, hResource);
    if (!hMemory) {
        std::cerr << "[QuickAddWindow] Failed to load logo resource" << std::endl;
        return false;
    }

    DWORD size = SizeofResource(hModule, hResource);
    void* pData = LockResource(hMemory);
    if (!pData || size == 0) {
        std::cerr << "[QuickAddWindow] Failed to lock logo resource" << std::endl;
        return false;
    }

    // Create IStream from memory
    IStream* pStream = nullptr;
    HGLOBAL hBuffer = GlobalAlloc(GMEM_MOVEABLE, size);
    if (hBuffer) {
        void* pBuffer = GlobalLock(hBuffer);
        if (pBuffer) {
            memcpy(pBuffer, pData, size);
            GlobalUnlock(hBuffer);
            if (SUCCEEDED(CreateStreamOnHGlobal(hBuffer, TRUE, &pStream))) {
                // Load bitmap from stream
                logo_bitmap_ = std::make_unique<Gdiplus::Bitmap>(pStream);
                pStream->Release();
                if (logo_bitmap_->GetLastStatus() == Gdiplus::Ok) {
                    std::cout << "[QuickAddWindow] Logo loaded successfully: "
                              << logo_bitmap_->GetWidth() << "x" << logo_bitmap_->GetHeight() << std::endl;
                    return true;
                }
            }
        }
        GlobalFree(hBuffer);
    }

    std::cerr << "[QuickAddWindow] Failed to create logo bitmap" << std::endl;
    return false;
}

void QuickAddWindow::DrawLogo(HDC hdc, int x, int y, int size) {
    Gdiplus::Graphics graphics(hdc);
    graphics.SetSmoothingMode(Gdiplus::SmoothingModeHighQuality);

    // If PNG loaded successfully, use it
    if (logo_bitmap_ && logo_bitmap_->GetLastStatus() == Gdiplus::Ok) {
        graphics.SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic);
        graphics.DrawImage(logo_bitmap_.get(), x, y, size, size);
        return;
    }

    // Fallback: Draw a 4-pointed sparkle/star in amber color
    // This matches the macOS sparkle icon style
    float cx = x + size / 2.0f;
    float cy = y + size / 2.0f;
    float r = size / 2.0f;

    // Amber gradient brush (dark amber to light amber)
    Gdiplus::Color amberDark(255, 213, 145, 30);   // Darker amber
    Gdiplus::Color amberLight(255, 245, 166, 35);  // Main amber #F5A623

    // Create linear gradient
    Gdiplus::LinearGradientBrush gradientBrush(
        Gdiplus::PointF(cx - r, cy - r),
        Gdiplus::PointF(cx + r, cy + r),
        amberLight, amberDark);

    // Draw 4-pointed star (sparkle shape)
    // Points: top, right, bottom, left with inner points between them
    Gdiplus::PointF starPoints[8];
    float outerR = r * 0.95f;
    float innerR = r * 0.35f;

    for (int i = 0; i < 8; i++) {
        float angle = static_cast<float>(i * 3.14159265f / 4.0f - 3.14159265f / 2.0f);
        float radius = (i % 2 == 0) ? outerR : innerR;
        starPoints[i].X = cx + radius * cos(angle);
        starPoints[i].Y = cy + radius * sin(angle);
    }

    graphics.FillPolygon(&gradientBrush, starPoints, 8);

    // Draw a subtle glow/highlight
    Gdiplus::SolidBrush highlightBrush(Gdiplus::Color(80, 255, 255, 255));
    float highlightR = innerR * 0.6f;
    graphics.FillEllipse(&highlightBrush,
                         cx - highlightR - r * 0.1f,
                         cy - highlightR - r * 0.1f,
                         highlightR * 2, highlightR * 2);
}

// ============================================================================
// Window Class Registration
// ============================================================================

bool QuickAddWindow::RegisterWindowClass() {
    if (class_registered_) return true;

    WNDCLASSEXW wcex = {};
    wcex.cbSize = sizeof(WNDCLASSEXW);
    wcex.style = CS_HREDRAW | CS_VREDRAW | CS_DROPSHADOW;
    wcex.lpfnWndProc = WindowProc;
    wcex.hInstance = GetModuleHandle(nullptr);
    wcex.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wcex.hbrBackground = nullptr;  // We handle painting ourselves
    wcex.lpszClassName = kWindowClassName;

    if (!RegisterClassExW(&wcex)) {
        std::cerr << "[QuickAddWindow] Failed to register window class" << std::endl;
        return false;
    }

    class_registered_ = true;
    return true;
}

// ============================================================================
// Window Initialization
// ============================================================================

bool QuickAddWindow::InitWindow() {
    if (!RegisterWindowClass()) return false;

    // Get DPI scaling factor for proper sizing
    HDC hdc = GetDC(nullptr);
    int dpiX = GetDeviceCaps(hdc, LOGPIXELSX);
    ReleaseDC(nullptr, hdc);
    float dpiScale = dpiX / 96.0f;

    // Scale dimensions for DPI
    int scaledWidth = static_cast<int>(kWindowWidth * dpiScale);
    int scaledHeight = static_cast<int>(kCompactHeight * dpiScale);

    // Calculate center position (upper part of screen, like Spotlight)
    int screenWidth = GetSystemMetrics(SM_CXSCREEN);
    int screenHeight = GetSystemMetrics(SM_CYSCREEN);
    int x = (screenWidth - scaledWidth) / 2;
    int y = screenHeight / 4;  // 1/4 from top

    std::cout << "[QuickAddWindow] DPI: " << dpiX << ", scale: " << dpiScale
              << ", size: " << scaledWidth << "x" << scaledHeight << std::endl;

    // Create borderless popup window
    window_handle_ = CreateWindowExW(
        WS_EX_TOPMOST | WS_EX_TOOLWINDOW,
        kWindowClassName,
        L"Amber Quick Add",
        WS_POPUP,
        x, y, scaledWidth, scaledHeight,
        nullptr, nullptr, GetModuleHandle(nullptr), this);

    if (!window_handle_) {
        std::cerr << "[QuickAddWindow] Failed to create window" << std::endl;
        return false;
    }

    // Store DPI scale for later use
    dpi_scale_ = dpiScale;

    // Enable DWM rounded corners (Windows 11)
    DWM_WINDOW_CORNER_PREFERENCE corner = DWMWCP_ROUND;
    DwmSetWindowAttribute(window_handle_, DWMWA_WINDOW_CORNER_PREFERENCE, &corner, sizeof(corner));

    // Create controls
    CreateCompactControls();

    return true;
}

// ============================================================================
// Compact Mode Controls
// ============================================================================

void QuickAddWindow::CreateCompactControls() {
    // Scale all dimensions by DPI
    int padding = static_cast<int>(kPadding * dpi_scale_);
    int logoSize = static_cast<int>(kLogoSize * dpi_scale_);
    int logoGap = static_cast<int>(12 * dpi_scale_);
    int editHeight = static_cast<int>(28 * dpi_scale_);
    int btnWidth = static_cast<int>(36 * dpi_scale_);
    int btnHeight = static_cast<int>(32 * dpi_scale_);
    int windowWidth = static_cast<int>(kWindowWidth * dpi_scale_);
    int windowHeight = static_cast<int>(kCompactHeight * dpi_scale_);

    // Edit control (input field)
    // Position: after logo (padding + logoSize + gap), centered vertically
    int editX = padding + logoSize + logoGap;
    int editY = (windowHeight - editHeight) / 2;
    int editWidth = windowWidth - editX - padding - btnWidth - static_cast<int>(8 * dpi_scale_);

    edit_control_ = CreateWindowExW(
        0, L"EDIT", L"",
        WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
        editX, editY, editWidth, editHeight,
        window_handle_, reinterpret_cast<HMENU>(static_cast<INT_PTR>(ID_EDIT)),
        GetModuleHandle(nullptr), nullptr);

    SendMessage(edit_control_, WM_SETFONT, reinterpret_cast<WPARAM>(main_font_), TRUE);

    // Set placeholder text (cue banner) - Chinese: "Add task...(Tab to expand)"
    SendMessage(edit_control_, EM_SETCUEBANNER, TRUE,
                reinterpret_cast<LPARAM>(L"\x6DFB\x52A0\x4EFB\x52A1...\xFF08Tab \x5C55\x5F00\x8BE6\x60C5\xFF09"));

    // Subclass edit control to handle Enter/ESC/Tab
    SetWindowSubclass(edit_control_, EditSubclassProc, 0, reinterpret_cast<DWORD_PTR>(this));

    // Submit button (amber, owner-draw)
    int btnX = windowWidth - padding - btnWidth;
    int btnY = (windowHeight - btnHeight) / 2;

    submit_button_ = CreateWindowExW(
        0, L"BUTTON", L"\x21B5",  // Return symbol
        WS_CHILD | WS_VISIBLE | BS_OWNERDRAW,
        btnX, btnY, btnWidth, btnHeight,
        window_handle_, reinterpret_cast<HMENU>(static_cast<INT_PTR>(ID_SUBMIT_BUTTON)),
        GetModuleHandle(nullptr), nullptr);

    std::cout << "[QuickAddWindow] Controls created: editX=" << editX << ", editY=" << editY
              << ", editW=" << editWidth << ", btnX=" << btnX << std::endl;
}

// ============================================================================
// Edit Control Subclass (Enter/ESC/Tab handling)
// ============================================================================

LRESULT CALLBACK QuickAddWindow::EditSubclassProc(
    HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam,
    UINT_PTR subclassId, DWORD_PTR refData) {

    QuickAddWindow* self = reinterpret_cast<QuickAddWindow*>(refData);

    if (msg == WM_KEYDOWN) {
        if (wparam == VK_RETURN) {
            // Enter: submit task
            self->SubmitTask();
            return 0;
        } else if (wparam == VK_ESCAPE) {
            // ESC: cancel
            self->CancelInput();
            return 0;
        } else if (wparam == VK_TAB) {
            // Tab: expand to detail mode
            if (!self->is_expanded_) {
                self->ExpandToDetailMode();
            }
            return 0;
        }
    }

    return DefSubclassProc(hwnd, msg, wparam, lparam);
}

// ============================================================================
// Window Procedure
// ============================================================================

LRESULT CALLBACK QuickAddWindow::WindowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
    QuickAddWindow* self = nullptr;

    if (message == WM_NCCREATE) {
        CREATESTRUCT* cs = reinterpret_cast<CREATESTRUCT*>(lparam);
        self = reinterpret_cast<QuickAddWindow*>(cs->lpCreateParams);
        SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
    } else {
        self = reinterpret_cast<QuickAddWindow*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
    }

    if (self) {
        return self->HandleMessage(hwnd, message, wparam, lparam);
    }

    return DefWindowProc(hwnd, message, wparam, lparam);
}

LRESULT QuickAddWindow::HandleMessage(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
    switch (message) {
        case WM_PAINT:
            OnPaint();
            return 0;

        case WM_CTLCOLOREDIT: {
            HDC hdc = reinterpret_cast<HDC>(wparam);
            HWND hwndEdit = reinterpret_cast<HWND>(lparam);
            return OnCtlColorEdit(hdc, hwndEdit);
        }

        case WM_CTLCOLORSTATIC: {
            // Make STATIC controls (like title label) have white background
            HDC hdc = reinterpret_cast<HDC>(wparam);
            SetBkMode(hdc, TRANSPARENT);
            SetTextColor(hdc, kBlackColor);
            return reinterpret_cast<LRESULT>(white_brush_);
        }

        case WM_DRAWITEM:
            OnDrawItem(reinterpret_cast<DRAWITEMSTRUCT*>(lparam));
            return TRUE;

        case WM_COMMAND: {
            int id = LOWORD(wparam);
            int code = HIWORD(wparam);

            if (code == BN_CLICKED) {
                switch (id) {
                    case ID_SUBMIT_BUTTON:
                    case ID_CONFIRM_BUTTON:
                        SubmitTask();
                        break;
                    case ID_CANCEL_BUTTON:
                        CancelInput();
                        break;
                    case ID_LIST_BUTTON:
                        // Toggle between Task and Note mode (no menu, direct switch)
                        is_note_mode_ = !is_note_mode_;
                        UpdateListSelectorText();
                        UpdateListButtonText();
                        break;
                    case ID_TAG_BUTTON:
                        ShowTagMenu();
                        break;
                    case ID_DATE_BUTTON:
                        ShowDateMenu();
                        break;
                    case ID_PRIORITY_BUTTON:
                        ShowPriorityMenu();
                        break;
                    case ID_LIST_SELECTOR:
                        ShowListSelectorMenu();  // Inbox and task lists
                        break;
                }
            }

            // Menu commands
            if (id >= ID_MENU_TODAY && id <= ID_MENU_LIST_BASE + 100) {
                OnMenuCommand(id);
            }
            return 0;
        }

        case WM_ACTIVATE:
            if (LOWORD(wparam) == WA_INACTIVE) {
                // Window lost focus - hide like Spotlight
                Hide();
                NativeWindowManager::GetInstance().NotifyFlutter("onQuickAddCancelled", {
                    {flutter::EncodableValue("windowType"), flutter::EncodableValue("quick_add")},
                    {flutter::EncodableValue("windowId"), flutter::EncodableValue(NativeWindowManager::WStringToUtf8(window_id_))}
                });
            }
            return 0;

        case WM_DESTROY:
            window_handle_ = nullptr;
            return 0;

        default:
            return DefWindowProc(hwnd, message, wparam, lparam);
    }
}

// ============================================================================
// Painting
// ============================================================================

void QuickAddWindow::OnPaint() {
    PAINTSTRUCT ps;
    HDC hdc = BeginPaint(window_handle_, &ps);

    // Get client rect
    RECT rect;
    GetClientRect(window_handle_, &rect);

    // Create memory DC for double buffering
    HDC memDC = CreateCompatibleDC(hdc);
    HBITMAP memBitmap = CreateCompatibleBitmap(hdc, rect.right, rect.bottom);
    HBITMAP oldBitmap = static_cast<HBITMAP>(SelectObject(memDC, memBitmap));

    // Fill with white background
    FillRect(memDC, &rect, white_brush_);

    // Scale dimensions by DPI
    int padding = static_cast<int>(kPadding * dpi_scale_);
    int logoSize = static_cast<int>(kLogoSize * dpi_scale_);
    int compactHeight = static_cast<int>(kCompactHeight * dpi_scale_);
    int expandedHeight = static_cast<int>(kExpandedHeight * dpi_scale_);

    // Draw logo only in compact mode (vertically centered in compact height)
    // In expanded mode, the logo is hidden to match macOS behavior
    if (!is_expanded_) {
        int logoY = (compactHeight - logoSize) / 2;
        DrawLogo(memDC, padding, logoY, logoSize);
    }

    // If expanded, draw additional UI elements
    if (is_expanded_) {
        // Draw separators
        HPEN grayPen = CreatePen(PS_SOLID, 1, kLightGrayColor);
        HPEN oldPen = static_cast<HPEN>(SelectObject(memDC, grayPen));

        // Separator after title
        int sep1Y = static_cast<int>(56 * dpi_scale_);
        MoveToEx(memDC, 0, sep1Y, nullptr);
        LineTo(memDC, rect.right, sep1Y);

        // Separator before footer
        int sep2Y = expandedHeight - static_cast<int>(56 * dpi_scale_);
        MoveToEx(memDC, 0, sep2Y, nullptr);
        LineTo(memDC, rect.right, sep2Y);

        SelectObject(memDC, oldPen);
        DeleteObject(grayPen);
    }

    // Copy to screen
    BitBlt(hdc, 0, 0, rect.right, rect.bottom, memDC, 0, 0, SRCCOPY);

    // Cleanup
    SelectObject(memDC, oldBitmap);
    DeleteObject(memBitmap);
    DeleteDC(memDC);

    EndPaint(window_handle_, &ps);
}

LRESULT QuickAddWindow::OnCtlColorEdit(HDC hdc, HWND hwndEdit) {
    // Make edit control transparent with white background
    SetBkMode(hdc, TRANSPARENT);
    SetTextColor(hdc, kBlackColor);
    return reinterpret_cast<LRESULT>(white_brush_);
}

void QuickAddWindow::OnDrawItem(DRAWITEMSTRUCT* dis) {
    if (!dis) return;

    bool isAmber = (dis->CtlID == ID_SUBMIT_BUTTON || dis->CtlID == ID_CONFIRM_BUTTON);
    bool isHovered = (dis->itemState & ODS_SELECTED);

    // Get button text
    wchar_t text[64] = {};
    GetWindowTextW(dis->hwndItem, text, 64);

    // Determine highlight color based on selection state
    // 0 = gray (default), 1 = amber, 2 = green, 3 = orange, 4 = red
    int highlightColor = 0;
    switch (dis->CtlID) {
        case ID_TAG_BUTTON:
            // Amber highlight when tags are selected
            if (!selected_tags_.empty()) highlightColor = 1;
            break;
        case ID_DATE_BUTTON:
            // Amber highlight when date is selected
            if (has_selected_date_) highlightColor = 1;
            break;
        case ID_PRIORITY_BUTTON:
            // Color based on priority level: 1=green, 2=orange, 3=red
            if (selected_priority_ == 1) highlightColor = 2;       // Green for low
            else if (selected_priority_ == 2) highlightColor = 3;  // Orange for medium
            else if (selected_priority_ == 3) highlightColor = 4;  // Red for high
            break;
    }

    // Determine icon type based on control ID
    // 0=none, 1=return, 2=list(三横线), 3=tag, 4=calendar, 5=flag, 6=note, 7=inbox
    int iconType = 0;
    switch (dis->CtlID) {
        case ID_SUBMIT_BUTTON: iconType = 1; break;
        case ID_LIST_BUTTON: iconType = is_note_mode_ ? 6 : 2; break;  // Note or List icon
        case ID_TAG_BUTTON: iconType = 3; break;
        case ID_DATE_BUTTON: iconType = 4; break;
        case ID_PRIORITY_BUTTON: iconType = 5; break;
        case ID_LIST_SELECTOR: iconType = is_note_mode_ ? 6 : 7; break;  // Note or Inbox icon
    }

    DrawRoundedButton(dis->hDC, dis->rcItem, text, isAmber, isHovered, iconType, highlightColor);
}

void QuickAddWindow::DrawRoundedButton(HDC hdc, RECT rect, const std::wstring& text, bool isAmber, bool isHovered, int iconType, int highlightColor) {
    // iconType: 0=none, 1=return, 2=list, 3=tag, 4=calendar, 5=flag, 6=note, 7=inbox
    // highlightColor: 0=gray, 1=amber, 2=green, 3=orange, 4=red
    // Scale corner radius by DPI
    int cornerRadius = static_cast<int>(8 * dpi_scale_);

    // First fill entire rect with white to clear any background artifacts in corners
    FillRect(hdc, &rect, white_brush_);

    // Create rounded rectangle region
    HRGN rgn = CreateRoundRectRgn(rect.left, rect.top, rect.right + 1, rect.bottom + 1, cornerRadius, cornerRadius);

    // Fill background
    HBRUSH fillBrush;
    bool needDeleteBrush = false;
    if (isAmber) {
        if (isHovered) {
            fillBrush = CreateSolidBrush(RGB(213, 145, 30));
            needDeleteBrush = true;
        } else {
            fillBrush = amber_brush_;
        }
    } else {
        fillBrush = isHovered ? gray_brush_ : white_brush_;
    }

    FillRgn(hdc, rgn, fillBrush);

    // Draw border for non-amber buttons
    if (!isAmber) {
        HPEN borderPen = CreatePen(PS_SOLID, 1, kLightGrayColor);
        HPEN oldPen = static_cast<HPEN>(SelectObject(hdc, borderPen));
        FrameRgn(hdc, rgn, gray_brush_, 1, 1);
        SelectObject(hdc, oldPen);
        DeleteObject(borderPen);
    }

    // Draw content based on icon type
    Gdiplus::Graphics graphics(hdc);
    graphics.SetSmoothingMode(Gdiplus::SmoothingModeHighQuality);

    float btnH = static_cast<float>(rect.bottom - rect.top);
    float iconSize = btnH * 0.5f;
    float padding = 6.0f * dpi_scale_;

    // Gray color for toolbar icons
    Gdiplus::Color grayColor(180, 128, 128, 128);
    Gdiplus::Pen grayPen(grayColor, 1.5f * dpi_scale_);
    grayPen.SetStartCap(Gdiplus::LineCapRound);
    grayPen.SetEndCap(Gdiplus::LineCapRound);
    grayPen.SetLineJoin(Gdiplus::LineJoinRound);
    Gdiplus::SolidBrush grayBrush(grayColor);

    if (iconType == 1 && isAmber) {
        // Return arrow icon (for submit button)
        float cx = (rect.left + rect.right) / 2.0f;
        float cy = (rect.top + rect.bottom) / 2.0f;
        float sz = btnH * 0.45f;

        Gdiplus::Pen whitePen(Gdiplus::Color(255, 255, 255, 255), 2.5f * dpi_scale_);
        whitePen.SetStartCap(Gdiplus::LineCapRound);
        whitePen.SetEndCap(Gdiplus::LineCapRound);
        whitePen.SetLineJoin(Gdiplus::LineJoinRound);

        float startX = cx + sz * 0.3f;
        float startY = cy - sz * 0.5f;
        float cornerX = startX;
        float cornerY = cy + sz * 0.2f;
        float endX = cx - sz * 0.5f;
        float endY = cornerY;

        Gdiplus::GraphicsPath path;
        path.AddLine(startX, startY, cornerX, cornerY);
        path.AddLine(cornerX, cornerY, endX, endY);
        graphics.DrawPath(&whitePen, &path);

        float arrowSize = sz * 0.35f;
        Gdiplus::PointF arrowPoints[3] = {
            Gdiplus::PointF(endX, endY),
            Gdiplus::PointF(endX + arrowSize, endY - arrowSize * 0.7f),
            Gdiplus::PointF(endX + arrowSize, endY + arrowSize * 0.7f)
        };
        Gdiplus::SolidBrush whiteBrush(Gdiplus::Color(255, 255, 255, 255));
        graphics.FillPolygon(&whiteBrush, arrowPoints, 3);
    } else if (iconType >= 2 && iconType <= 7) {
        // Toolbar buttons with icon + text
        float iconX = rect.left + padding;
        float iconY = rect.top + (btnH - iconSize) / 2.0f;

        // Determine icon color based on highlightColor or iconType
        // highlightColor: 0=gray, 1=amber, 2=green, 3=orange, 4=red
        Gdiplus::Color iconColor;
        COLORREF textColor;
        if (iconType == 6) {
            // Note mode button - always amber
            iconColor = Gdiplus::Color(255, 245, 166, 35);  // Amber
            textColor = kAmberColor;
        } else if (highlightColor == 1) {
            // Amber highlight (tags selected, date selected)
            iconColor = Gdiplus::Color(255, 245, 166, 35);  // Amber
            textColor = kAmberColor;
        } else if (highlightColor == 2) {
            // Green highlight (low priority)
            iconColor = Gdiplus::Color(255, 76, 175, 80);   // Green
            textColor = kGreenColor;
        } else if (highlightColor == 3) {
            // Orange highlight (medium priority)
            iconColor = Gdiplus::Color(255, 255, 152, 0);   // Orange
            textColor = kOrangeColor;
        } else if (highlightColor == 4) {
            // Red highlight (high priority)
            iconColor = Gdiplus::Color(255, 244, 67, 54);   // Red
            textColor = kRedColor;
        } else {
            // Default gray
            iconColor = grayColor;
            textColor = kGrayColor;
        }

        Gdiplus::Pen iconPen(iconColor, 1.5f * dpi_scale_);
        iconPen.SetStartCap(Gdiplus::LineCapRound);
        iconPen.SetEndCap(Gdiplus::LineCapRound);
        iconPen.SetLineJoin(Gdiplus::LineJoinRound);
        Gdiplus::SolidBrush iconBrush(iconColor);

        if (iconType == 2) {
            // List icon (三横线) - always gray since it doesn't have selection state
            float lineY1 = iconY + iconSize * 0.2f;
            float lineY2 = iconY + iconSize * 0.5f;
            float lineY3 = iconY + iconSize * 0.8f;
            float lineW = iconSize * 0.8f;
            graphics.DrawLine(&iconPen, iconX, lineY1, iconX + lineW, lineY1);
            graphics.DrawLine(&iconPen, iconX, lineY2, iconX + lineW, lineY2);
            graphics.DrawLine(&iconPen, iconX, lineY3, iconX + lineW, lineY3);
        } else if (iconType == 3) {
            // Tag icon (圆形标签) - uses iconPen for highlight color
            float tagSize = iconSize * 0.7f;
            float tagX = iconX;
            float tagY = iconY + (iconSize - tagSize) / 2.0f;
            graphics.DrawEllipse(&iconPen, tagX, tagY, tagSize, tagSize);
            // Small dot inside
            float dotSize = tagSize * 0.25f;
            float dotX = tagX + tagSize * 0.25f;
            float dotY = tagY + tagSize * 0.25f;
            graphics.FillEllipse(&iconBrush, dotX, dotY, dotSize, dotSize);
        } else if (iconType == 4) {
            // Calendar icon - uses iconPen for highlight color
            float calW = iconSize * 0.8f;
            float calH = iconSize * 0.7f;
            float calX = iconX;
            float calY = iconY + (iconSize - calH) / 2.0f;
            // Calendar outline
            graphics.DrawRectangle(&iconPen, calX, calY + calH * 0.15f, calW, calH * 0.85f);
            // Top binding
            float bindY = calY;
            graphics.DrawLine(&iconPen, calX + calW * 0.25f, bindY, calX + calW * 0.25f, calY + calH * 0.25f);
            graphics.DrawLine(&iconPen, calX + calW * 0.75f, bindY, calX + calW * 0.75f, calY + calH * 0.25f);
        } else if (iconType == 5) {
            // Flag/Priority icon - uses iconPen for highlight color
            float flagW = iconSize * 0.6f;
            float flagH = iconSize * 0.9f;
            float flagX = iconX + iconSize * 0.1f;
            float flagY = iconY + (iconSize - flagH) / 2.0f;
            // Pole
            graphics.DrawLine(&iconPen, flagX, flagY, flagX, flagY + flagH);
            // Flag shape (triangle)
            Gdiplus::PointF flagPoints[3] = {
                Gdiplus::PointF(flagX, flagY),
                Gdiplus::PointF(flagX + flagW, flagY + flagH * 0.2f),
                Gdiplus::PointF(flagX, flagY + flagH * 0.4f)
            };
            graphics.DrawPolygon(&iconPen, flagPoints, 3);
        } else if (iconType == 6) {
            // Note icon (文档/笔记图标) - amber colored
            float noteW = iconSize * 0.7f;
            float noteH = iconSize * 0.85f;
            float noteX = iconX;
            float noteY = iconY + (iconSize - noteH) / 2.0f;
            // Document outline
            graphics.DrawRectangle(&iconPen, noteX, noteY, noteW, noteH);
            // Text lines inside
            float lineX = noteX + noteW * 0.15f;
            float lineW = noteW * 0.7f;
            graphics.DrawLine(&iconPen, lineX, noteY + noteH * 0.3f, lineX + lineW, noteY + noteH * 0.3f);
            graphics.DrawLine(&iconPen, lineX, noteY + noteH * 0.5f, lineX + lineW, noteY + noteH * 0.5f);
            graphics.DrawLine(&iconPen, lineX, noteY + noteH * 0.7f, lineX + lineW * 0.6f, noteY + noteH * 0.7f);
        } else if (iconType == 7) {
            // Inbox icon (收件箱图标) - envelope/tray style, uses iconPen for color
            float boxW = iconSize * 0.85f;
            float boxH = iconSize * 0.7f;
            float boxX = iconX;
            float boxY = iconY + (iconSize - boxH) / 2.0f;
            // Tray outline (open top box)
            Gdiplus::PointF trayPoints[5] = {
                Gdiplus::PointF(boxX, boxY + boxH * 0.3f),                    // Top left
                Gdiplus::PointF(boxX + boxW * 0.2f, boxY + boxH),             // Bottom left
                Gdiplus::PointF(boxX + boxW * 0.8f, boxY + boxH),             // Bottom right
                Gdiplus::PointF(boxX + boxW, boxY + boxH * 0.3f),             // Top right
                Gdiplus::PointF(boxX, boxY + boxH * 0.3f)                     // Back to start
            };
            graphics.DrawLines(&iconPen, trayPoints, 5);
            // Arrow pointing down into tray
            float arrowCX = boxX + boxW * 0.5f;
            float arrowTop = boxY;
            float arrowBottom = boxY + boxH * 0.5f;
            float arrowW = boxW * 0.25f;
            // Vertical line
            graphics.DrawLine(&iconPen, arrowCX, arrowTop, arrowCX, arrowBottom - arrowW * 0.3f);
            // Arrow head
            Gdiplus::PointF arrowHead[3] = {
                Gdiplus::PointF(arrowCX, arrowBottom),
                Gdiplus::PointF(arrowCX - arrowW, arrowBottom - arrowW),
                Gdiplus::PointF(arrowCX + arrowW, arrowBottom - arrowW)
            };
            graphics.DrawPolygon(&iconPen, arrowHead, 3);
        }

        // Draw text after icon (use textColor determined by highlightColor)
        SetBkMode(hdc, TRANSPARENT);
        SetTextColor(hdc, textColor);
        HFONT oldFont = static_cast<HFONT>(SelectObject(hdc, button_font_));
        RECT textRect = rect;
        textRect.left = static_cast<int>(iconX + iconSize + padding * 0.5f);
        DrawTextW(hdc, text.c_str(), -1, &textRect, DT_LEFT | DT_VCENTER | DT_SINGLELINE);
        SelectObject(hdc, oldFont);
    } else {
        // Normal text button (no icon)
        SetBkMode(hdc, TRANSPARENT);
        SetTextColor(hdc, isAmber ? kWhiteColor : kBlackColor);
        HFONT oldFont = static_cast<HFONT>(SelectObject(hdc, button_font_));
        DrawTextW(hdc, text.c_str(), -1, &rect, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
        SelectObject(hdc, oldFont);
    }

    // Cleanup
    DeleteObject(rgn);
    if (needDeleteBrush) {
        DeleteObject(fillBrush);
    }
}

// ============================================================================
// Mode Switching
// ============================================================================

void QuickAddWindow::ExpandToDetailMode() {
    if (is_expanded_) return;
    is_expanded_ = true;

    // Resize window
    ResizeWindow(kExpandedHeight);

    // Hide compact mode button
    ShowWindow(submit_button_, SW_HIDE);

    // Create expanded mode controls
    CreateExpandedControls();

    // Transfer text from compact edit to content edit
    int len = GetWindowTextLengthW(edit_control_);
    if (len > 0) {
        std::wstring text(len + 1, L'\0');
        GetWindowTextW(edit_control_, &text[0], len + 1);
        text.resize(len);
        SetWindowTextW(content_edit_, text.c_str());
    }

    // Hide compact edit, focus content edit
    ShowWindow(edit_control_, SW_HIDE);
    SetFocus(content_edit_);

    InvalidateRect(window_handle_, nullptr, TRUE);
}

void QuickAddWindow::CollapseToCompactMode() {
    if (!is_expanded_) return;
    is_expanded_ = false;

    // Destroy expanded controls
    DestroyExpandedControls();

    // Resize window
    ResizeWindow(kCompactHeight);

    // Show compact controls
    ShowWindow(edit_control_, SW_SHOW);
    ShowWindow(submit_button_, SW_SHOW);

    // Clear and focus edit
    SetWindowTextW(edit_control_, L"");
    SetFocus(edit_control_);

    InvalidateRect(window_handle_, nullptr, TRUE);
}

void QuickAddWindow::CreateExpandedControls() {
    // Scale all dimensions by DPI
    int margin = static_cast<int>(20 * dpi_scale_);
    int smallMargin = static_cast<int>(16 * dpi_scale_);
    int windowWidth = static_cast<int>(kWindowWidth * dpi_scale_);
    int expandedHeight = static_cast<int>(kExpandedHeight * dpi_scale_);

    // Title label - Chinese: "What to do?"
    title_label_ = CreateWindowExW(
        0, L"STATIC", L"\x51C6\x5907\x505A\x4EC0\x4E48?",
        WS_CHILD | WS_VISIBLE | SS_LEFT,
        margin, margin, static_cast<int>(300 * dpi_scale_), static_cast<int>(30 * dpi_scale_),
        window_handle_, nullptr, GetModuleHandle(nullptr), nullptr);
    SendMessage(title_label_, WM_SETFONT, reinterpret_cast<WPARAM>(title_font_), TRUE);

    // Content edit (multi-line)
    int contentY = static_cast<int>(68 * dpi_scale_);
    int contentHeight = static_cast<int>(80 * dpi_scale_);
    content_edit_ = CreateWindowExW(
        0, L"EDIT", L"",
        WS_CHILD | WS_VISIBLE | ES_MULTILINE | ES_AUTOVSCROLL | ES_WANTRETURN,
        margin, contentY, windowWidth - margin * 2, contentHeight,
        window_handle_, reinterpret_cast<HMENU>(static_cast<INT_PTR>(ID_CONTENT_EDIT)),
        GetModuleHandle(nullptr), nullptr);
    SendMessage(content_edit_, WM_SETFONT, reinterpret_cast<WPARAM>(main_font_), TRUE);

    // Subclass content edit for ESC handling
    SetWindowSubclass(content_edit_, EditSubclassProc, 1, reinterpret_cast<DWORD_PTR>(this));

    // Toolbar buttons (right-aligned)
    int btnY = static_cast<int>(160 * dpi_scale_);
    int btnHeight = static_cast<int>(24 * dpi_scale_);
    int btnSpacing = static_cast<int>(8 * dpi_scale_);
    int btn60 = static_cast<int>(60 * dpi_scale_);
    int btn50 = static_cast<int>(50 * dpi_scale_);

    // Priority button - Chinese: "Priority"
    priority_button_ = CreateWindowExW(
        0, L"BUTTON", L"\x4F18\x5148\x7EA7",
        WS_CHILD | WS_VISIBLE | BS_OWNERDRAW,
        windowWidth - margin - btn60, btnY, btn60, btnHeight,
        window_handle_, reinterpret_cast<HMENU>(static_cast<INT_PTR>(ID_PRIORITY_BUTTON)),
        GetModuleHandle(nullptr), nullptr);

    // Date button - Chinese: "Date"
    date_button_ = CreateWindowExW(
        0, L"BUTTON", L"\x65E5\x671F",
        WS_CHILD | WS_VISIBLE | BS_OWNERDRAW,
        windowWidth - margin - btn60 - btnSpacing - btn50, btnY, btn50, btnHeight,
        window_handle_, reinterpret_cast<HMENU>(static_cast<INT_PTR>(ID_DATE_BUTTON)),
        GetModuleHandle(nullptr), nullptr);

    // Tag button - Chinese: "Tag"
    tag_button_ = CreateWindowExW(
        0, L"BUTTON", L"\x6807\x7B7E",
        WS_CHILD | WS_VISIBLE | BS_OWNERDRAW,
        windowWidth - margin - btn60 - btnSpacing - btn50 - btnSpacing - btn50, btnY, btn50, btnHeight,
        window_handle_, reinterpret_cast<HMENU>(static_cast<INT_PTR>(ID_TAG_BUTTON)),
        GetModuleHandle(nullptr), nullptr);

    // List button - Chinese: "List"
    list_button_ = CreateWindowExW(
        0, L"BUTTON", L"\x5217\x8868",
        WS_CHILD | WS_VISIBLE | BS_OWNERDRAW,
        windowWidth - margin - btn60 - btnSpacing - btn50 - btnSpacing - btn50 - btnSpacing - btn50, btnY, btn50, btnHeight,
        window_handle_, reinterpret_cast<HMENU>(static_cast<INT_PTR>(ID_LIST_BUTTON)),
        GetModuleHandle(nullptr), nullptr);

    // Footer area
    int footerY = expandedHeight - static_cast<int>(44 * dpi_scale_);
    int footerBtnH = static_cast<int>(32 * dpi_scale_);
    int footerBtnW = static_cast<int>(64 * dpi_scale_);
    int listBtnW = static_cast<int>(80 * dpi_scale_);
    int listBtnH = static_cast<int>(28 * dpi_scale_);

    // List selector button (left side) - Chinese: "Inbox"
    list_selector_button_ = CreateWindowExW(
        0, L"BUTTON", L"\x6536\x96C6\x7BB1",
        WS_CHILD | WS_VISIBLE | BS_OWNERDRAW,
        smallMargin, footerY, listBtnW, listBtnH,
        window_handle_, reinterpret_cast<HMENU>(static_cast<INT_PTR>(ID_LIST_SELECTOR)),
        GetModuleHandle(nullptr), nullptr);

    // Confirm button (amber, right side) - Chinese: "OK"
    confirm_button_ = CreateWindowExW(
        0, L"BUTTON", L"\x786E\x5B9A",
        WS_CHILD | WS_VISIBLE | BS_OWNERDRAW,
        windowWidth - margin - footerBtnW, footerY, footerBtnW, footerBtnH,
        window_handle_, reinterpret_cast<HMENU>(static_cast<INT_PTR>(ID_CONFIRM_BUTTON)),
        GetModuleHandle(nullptr), nullptr);

    // Cancel button - Chinese: "Cancel"
    cancel_button_ = CreateWindowExW(
        0, L"BUTTON", L"\x53D6\x6D88",
        WS_CHILD | WS_VISIBLE | BS_OWNERDRAW,
        windowWidth - margin - footerBtnW - btnSpacing - footerBtnW, footerY, footerBtnW, footerBtnH,
        window_handle_, reinterpret_cast<HMENU>(static_cast<INT_PTR>(ID_CANCEL_BUTTON)),
        GetModuleHandle(nullptr), nullptr);

    // Initial layout with dynamic widths
    RelayoutToolbarButtons();
}

void QuickAddWindow::DestroyExpandedControls() {
    if (title_label_) { DestroyWindow(title_label_); title_label_ = nullptr; }
    if (content_edit_) { DestroyWindow(content_edit_); content_edit_ = nullptr; }
    if (list_button_) { DestroyWindow(list_button_); list_button_ = nullptr; }
    if (tag_button_) { DestroyWindow(tag_button_); tag_button_ = nullptr; }
    if (date_button_) { DestroyWindow(date_button_); date_button_ = nullptr; }
    if (priority_button_) { DestroyWindow(priority_button_); priority_button_ = nullptr; }
    if (list_selector_button_) { DestroyWindow(list_selector_button_); list_selector_button_ = nullptr; }
    if (cancel_button_) { DestroyWindow(cancel_button_); cancel_button_ = nullptr; }
    if (confirm_button_) { DestroyWindow(confirm_button_); confirm_button_ = nullptr; }

    // Reset state
    is_note_mode_ = false;
    selected_priority_ = 0;
    selected_tags_.clear();
    has_selected_date_ = false;
    selected_list_id_.clear();
    selected_list_name_ = L"Inbox";
}

void QuickAddWindow::ResizeWindow(int newHeight, bool animate) {
    if (!window_handle_) return;

    RECT rect;
    GetWindowRect(window_handle_, &rect);

    // Scale dimensions by DPI
    int scaledWidth = static_cast<int>(kWindowWidth * dpi_scale_);
    int scaledHeight = static_cast<int>(newHeight * dpi_scale_);

    // Keep top-left corner fixed, adjust height
    SetWindowPos(window_handle_, nullptr,
                 rect.left, rect.top, scaledWidth, scaledHeight,
                 SWP_NOZORDER | SWP_NOACTIVATE);

    std::cout << "[QuickAddWindow] Resized to: " << scaledWidth << "x" << scaledHeight << std::endl;
}

// ============================================================================
// Actions
// ============================================================================

void QuickAddWindow::SubmitTask() {
    // Get text from appropriate edit control
    HWND editToUse = is_expanded_ ? content_edit_ : edit_control_;
    int len = GetWindowTextLengthW(editToUse);
    if (len == 0) return;

    std::wstring text(len + 1, L'\0');
    GetWindowTextW(editToUse, &text[0], len + 1);
    text.resize(len);

    // Trim whitespace
    size_t start = text.find_first_not_of(L" \t\r\n");
    size_t end = text.find_last_not_of(L" \t\r\n");
    if (start == std::wstring::npos) return;
    text = text.substr(start, end - start + 1);

    if (text.empty()) return;

    // Build arguments
    flutter::EncodableMap args;
    args[flutter::EncodableValue("title")] = flutter::EncodableValue(NativeWindowManager::WStringToUtf8(text));
    args[flutter::EncodableValue("windowType")] = flutter::EncodableValue("quick_add");
    args[flutter::EncodableValue("windowId")] = flutter::EncodableValue(NativeWindowManager::WStringToUtf8(window_id_));

    if (is_expanded_) {
        // Include expanded mode data
        if (has_selected_date_) {
            args[flutter::EncodableValue("dueDate")] = flutter::EncodableValue(selected_date_ms_);
        }
        args[flutter::EncodableValue("hasDate")] = flutter::EncodableValue(has_selected_date_);
        args[flutter::EncodableValue("isNote")] = flutter::EncodableValue(is_note_mode_);
        args[flutter::EncodableValue("priority")] = flutter::EncodableValue(selected_priority_);

        // Tags
        flutter::EncodableList tagsList;
        for (const auto& tag : selected_tags_) {
            tagsList.push_back(flutter::EncodableValue(NativeWindowManager::WStringToUtf8(tag)));
        }
        args[flutter::EncodableValue("tags")] = flutter::EncodableValue(tagsList);

        // List ID
        if (!selected_list_id_.empty()) {
            args[flutter::EncodableValue("listId")] = flutter::EncodableValue(NativeWindowManager::WStringToUtf8(selected_list_id_));
        }
    } else {
        // Compact mode defaults
        args[flutter::EncodableValue("hasDate")] = flutter::EncodableValue(false);
        args[flutter::EncodableValue("isNote")] = flutter::EncodableValue(false);
        args[flutter::EncodableValue("priority")] = flutter::EncodableValue(0);
        args[flutter::EncodableValue("tags")] = flutter::EncodableValue(flutter::EncodableList());
    }

    // Notify Flutter
    std::string method = is_note_mode_ ? "onQuickAddNoteCreated" : "onQuickAddTaskCreated";
    NativeWindowManager::GetInstance().NotifyFlutter(method, args);

    // Hide window
    Hide();
}

void QuickAddWindow::CancelInput() {
    Hide();
    NativeWindowManager::GetInstance().NotifyFlutter("onQuickAddCancelled", {
        {flutter::EncodableValue("windowType"), flutter::EncodableValue("quick_add")},
        {flutter::EncodableValue("windowId"), flutter::EncodableValue(NativeWindowManager::WStringToUtf8(window_id_))}
    });
}

// ============================================================================
// Menu Handling
// ============================================================================

void QuickAddWindow::ShowDateMenu() {
    HMENU menu = CreatePopupMenu();

    // Chinese menu items: Today, Tomorrow, Next week, Clear date
    AppendMenuW(menu, MF_STRING, ID_MENU_TODAY, L"\x4ECA\x5929");
    AppendMenuW(menu, MF_STRING, ID_MENU_TOMORROW, L"\x660E\x5929");
    AppendMenuW(menu, MF_STRING, ID_MENU_NEXT_WEEK, L"\x4E0B\x5468");
    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(menu, MF_STRING, ID_MENU_CLEAR_DATE, L"\x6E05\x9664\x65E5\x671F");

    RECT rect;
    GetWindowRect(date_button_, &rect);
    TrackPopupMenu(menu, TPM_LEFTALIGN | TPM_TOPALIGN, rect.left, rect.bottom, 0, window_handle_, nullptr);
    DestroyMenu(menu);
}

void QuickAddWindow::ShowPriorityMenu() {
    HMENU menu = CreatePopupMenu();

    // Chinese menu items: None, Low, Medium, High
    AppendMenuW(menu, MF_STRING | (selected_priority_ == 0 ? MF_CHECKED : 0), ID_MENU_PRIORITY_NONE, L"\x65E0");
    AppendMenuW(menu, MF_STRING | (selected_priority_ == 1 ? MF_CHECKED : 0), ID_MENU_PRIORITY_LOW, L"\x4F4E");
    AppendMenuW(menu, MF_STRING | (selected_priority_ == 2 ? MF_CHECKED : 0), ID_MENU_PRIORITY_MEDIUM, L"\x4E2D");
    AppendMenuW(menu, MF_STRING | (selected_priority_ == 3 ? MF_CHECKED : 0), ID_MENU_PRIORITY_HIGH, L"\x9AD8");

    RECT rect;
    GetWindowRect(priority_button_, &rect);
    TrackPopupMenu(menu, TPM_LEFTALIGN | TPM_TOPALIGN, rect.left, rect.bottom, 0, window_handle_, nullptr);
    DestroyMenu(menu);
}

void QuickAddWindow::ShowTagMenu() {
    HMENU menu = CreatePopupMenu();

    std::vector<std::wstring> tagsToShow = available_tags_;
    if (tagsToShow.empty()) {
        // Default tags: Work, Study, Life, Important
        tagsToShow = {L"\x5DE5\x4F5C", L"\x5B66\x4E60", L"\x751F\x6D3B", L"\x91CD\x8981"};
    }

    for (size_t i = 0; i < tagsToShow.size(); ++i) {
        bool checked = std::find(selected_tags_.begin(), selected_tags_.end(), tagsToShow[i]) != selected_tags_.end();
        AppendMenuW(menu, MF_STRING | (checked ? MF_CHECKED : 0),
                    ID_MENU_TAG_BASE + static_cast<int>(i), tagsToShow[i].c_str());
    }

    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    // Chinese: Clear tags
    AppendMenuW(menu, MF_STRING, ID_MENU_TAG_CLEAR, L"\x6E05\x9664\x6807\x7B7E");

    RECT rect;
    GetWindowRect(tag_button_, &rect);
    TrackPopupMenu(menu, TPM_LEFTALIGN | TPM_TOPALIGN, rect.left, rect.bottom, 0, window_handle_, nullptr);
    DestroyMenu(menu);
}

void QuickAddWindow::ShowListSelectorMenu() {
    // List selector menu: Inbox and task lists (shown when clicking bottom "Inbox" button)
    HMENU menu = CreatePopupMenu();

    // Chinese: Inbox
    bool inboxSelected = selected_list_id_.empty();
    AppendMenuW(menu, MF_STRING | (inboxSelected ? MF_CHECKED : 0), ID_MENU_LIST_INBOX, L"\x6536\x96C6\x7BB1");

    // Task lists
    for (size_t i = 0; i < available_task_lists_.size(); ++i) {
        bool selected = selected_list_id_ == available_task_lists_[i].first;
        AppendMenuW(menu, MF_STRING | (selected ? MF_CHECKED : 0),
                    ID_MENU_LIST_BASE + static_cast<int>(i), available_task_lists_[i].second.c_str());
    }

    RECT rect;
    GetWindowRect(list_selector_button_, &rect);
    TrackPopupMenu(menu, TPM_LEFTALIGN | TPM_TOPALIGN, rect.left, rect.bottom, 0, window_handle_, nullptr);
    DestroyMenu(menu);
}

void QuickAddWindow::OnMenuCommand(int id) {
    switch (id) {
        case ID_MENU_TODAY:
            selected_date_ms_ = static_cast<double>(std::time(nullptr)) * 1000.0;
            has_selected_date_ = true;
            UpdateDateButtonText();
            break;
        case ID_MENU_TOMORROW:
            selected_date_ms_ = static_cast<double>(std::time(nullptr) + 86400) * 1000.0;
            has_selected_date_ = true;
            UpdateDateButtonText();
            break;
        case ID_MENU_NEXT_WEEK:
            selected_date_ms_ = static_cast<double>(std::time(nullptr) + 86400 * 7) * 1000.0;
            has_selected_date_ = true;
            UpdateDateButtonText();
            break;
        case ID_MENU_CLEAR_DATE:
            has_selected_date_ = false;
            UpdateDateButtonText();
            break;
        case ID_MENU_PRIORITY_NONE: selected_priority_ = 0; UpdatePriorityButtonText(); break;
        case ID_MENU_PRIORITY_LOW: selected_priority_ = 1; UpdatePriorityButtonText(); break;
        case ID_MENU_PRIORITY_MEDIUM: selected_priority_ = 2; UpdatePriorityButtonText(); break;
        case ID_MENU_PRIORITY_HIGH: selected_priority_ = 3; UpdatePriorityButtonText(); break;
        case ID_MENU_MODE_TASK:
            is_note_mode_ = false;
            UpdateListSelectorText();
            break;
        case ID_MENU_MODE_NOTE:
            is_note_mode_ = true;
            UpdateListSelectorText();
            break;
        case ID_MENU_TAG_CLEAR:
            selected_tags_.clear();
            UpdateTagButtonText();
            break;
        case ID_MENU_LIST_INBOX:
            selected_list_id_.clear();
            selected_list_name_ = L"Inbox";
            is_note_mode_ = false;
            UpdateListSelectorText();
            break;
        default:
            if (id >= ID_MENU_TAG_BASE && id < ID_MENU_TAG_CLEAR) {
                int idx = id - ID_MENU_TAG_BASE;
                std::vector<std::wstring> tagsToShow = available_tags_;
                if (tagsToShow.empty()) {
                    tagsToShow = {L"\x5DE5\x4F5C", L"\x5B66\x4E60", L"\x751F\x6D3B", L"\x91CD\x8981"};
                }
                if (idx < static_cast<int>(tagsToShow.size())) {
                    const std::wstring& tag = tagsToShow[idx];
                    auto it = std::find(selected_tags_.begin(), selected_tags_.end(), tag);
                    if (it != selected_tags_.end()) {
                        selected_tags_.erase(it);
                    } else {
                        selected_tags_.push_back(tag);
                    }
                    UpdateTagButtonText();
                }
            } else if (id >= ID_MENU_LIST_BASE && id < ID_MENU_LIST_BASE + 100) {
                int idx = id - ID_MENU_LIST_BASE;
                if (idx < static_cast<int>(available_task_lists_.size())) {
                    selected_list_id_ = available_task_lists_[idx].first;
                    selected_list_name_ = available_task_lists_[idx].second;
                    is_note_mode_ = false;
                    UpdateListSelectorText();
                }
            }
            break;
    }
}

// ============================================================================
// Update Button Text
// ============================================================================

void QuickAddWindow::UpdateListButtonText() {
    if (!list_button_) return;
    // Chinese: "Note" or "List"
    if (is_note_mode_) {
        SetWindowTextW(list_button_, L"\x7B14\x8BB0");
    } else {
        SetWindowTextW(list_button_, L"\x5217\x8868");
    }
    InvalidateRect(list_button_, nullptr, TRUE);
    RelayoutToolbarButtons();  // Re-layout to accommodate new width
}

void QuickAddWindow::UpdateDateButtonText() {
    if (!date_button_) return;
    if (has_selected_date_) {
        SetWindowTextW(date_button_, FormatDateShort(selected_date_ms_).c_str());
    } else {
        // Chinese: "Date"
        SetWindowTextW(date_button_, L"\x65E5\x671F");
    }
    InvalidateRect(date_button_, nullptr, TRUE);
    RelayoutToolbarButtons();  // Re-layout to accommodate new width
}

void QuickAddWindow::UpdatePriorityButtonText() {
    if (!priority_button_) return;
    const wchar_t* text;
    switch (selected_priority_) {
        // Chinese: Low, Medium, High, Priority
        case 1: text = L"\x4F4E"; break;
        case 2: text = L"\x4E2D"; break;
        case 3: text = L"\x9AD8"; break;
        default: text = L"\x4F18\x5148\x7EA7"; break;
    }
    SetWindowTextW(priority_button_, text);
    InvalidateRect(priority_button_, nullptr, TRUE);
    RelayoutToolbarButtons();  // Re-layout to accommodate new width
}

void QuickAddWindow::UpdateTagButtonText() {
    if (!tag_button_) return;
    if (selected_tags_.empty()) {
        // Chinese: "Tag"
        SetWindowTextW(tag_button_, L"\x6807\x7B7E");
    } else {
        // Show all selected tags separated by comma (like macOS)
        std::wstring text;
        for (size_t i = 0; i < selected_tags_.size(); ++i) {
            if (i > 0) text += L", ";
            text += selected_tags_[i];
        }
        SetWindowTextW(tag_button_, text.c_str());
    }
    InvalidateRect(tag_button_, nullptr, TRUE);
    RelayoutToolbarButtons();  // Re-layout to accommodate new width
}

void QuickAddWindow::UpdateListSelectorText() {
    if (!list_selector_button_) return;
    if (is_note_mode_) {
        // Chinese: "Note"
        SetWindowTextW(list_selector_button_, L"\x7B14\x8BB0");
    } else if (selected_list_id_.empty()) {
        // Chinese: "Inbox"
        SetWindowTextW(list_selector_button_, L"\x6536\x96C6\x7BB1");
    } else {
        SetWindowTextW(list_selector_button_, selected_list_name_.c_str());
    }
    InvalidateRect(list_selector_button_, nullptr, TRUE);
}

std::wstring QuickAddWindow::FormatDateShort(double timestamp) {
    time_t t = static_cast<time_t>(timestamp / 1000);
    struct tm tm_info;
    if (localtime_s(&tm_info, &t) != 0) return L"\x65E5\x671F";

    std::wstringstream ss;
    // Chinese: XMonth XDay
    ss << (tm_info.tm_mon + 1) << L"\x6708" << tm_info.tm_mday << L"\x65E5";
    return ss.str();
}

void QuickAddWindow::UpdatePlaceholderText() {
    // Not needed - using EM_SETCUEBANNER
}

int QuickAddWindow::CalculateButtonWidth(HWND button) {
    if (!button) return static_cast<int>(50 * dpi_scale_);

    // Get button text
    int len = GetWindowTextLengthW(button);
    std::wstring text(len + 1, L'\0');
    GetWindowTextW(button, &text[0], len + 1);
    text.resize(len);

    // Calculate text width
    HDC hdc = GetDC(button);
    HFONT oldFont = static_cast<HFONT>(SelectObject(hdc, button_font_));
    SIZE textSize;
    GetTextExtentPoint32W(hdc, text.c_str(), static_cast<int>(text.length()), &textSize);
    SelectObject(hdc, oldFont);
    ReleaseDC(button, hdc);

    // Add padding for icon + left/right margins
    // Icon size is approx. btnHeight * 0.5, plus padding on both sides
    int iconWidth = static_cast<int>(12 * dpi_scale_);  // Icon width
    int padding = static_cast<int>(16 * dpi_scale_);    // Left + right padding
    int minWidth = static_cast<int>(50 * dpi_scale_);   // Minimum width

    int totalWidth = textSize.cx + iconWidth + padding;
    return (totalWidth > minWidth) ? totalWidth : minWidth;
}

void QuickAddWindow::RelayoutToolbarButtons() {
    // Only re-layout if expanded mode controls exist
    if (!is_expanded_ || !list_button_ || !tag_button_ || !date_button_ || !priority_button_) {
        return;
    }

    int margin = static_cast<int>(20 * dpi_scale_);
    int windowWidth = static_cast<int>(kWindowWidth * dpi_scale_);
    int btnY = static_cast<int>(160 * dpi_scale_);
    int btnHeight = static_cast<int>(24 * dpi_scale_);
    int btnSpacing = static_cast<int>(8 * dpi_scale_);

    // Calculate dynamic widths for each button
    int priorityW = CalculateButtonWidth(priority_button_);
    int dateW = CalculateButtonWidth(date_button_);
    int tagW = CalculateButtonWidth(tag_button_);
    int listW = CalculateButtonWidth(list_button_);

    // Position buttons from right to left
    int x = windowWidth - margin;

    // Priority button (rightmost)
    x -= priorityW;
    SetWindowPos(priority_button_, nullptr, x, btnY, priorityW, btnHeight, SWP_NOZORDER);

    // Date button
    x -= btnSpacing + dateW;
    SetWindowPos(date_button_, nullptr, x, btnY, dateW, btnHeight, SWP_NOZORDER);

    // Tag button
    x -= btnSpacing + tagW;
    SetWindowPos(tag_button_, nullptr, x, btnY, tagW, btnHeight, SWP_NOZORDER);

    // List button (leftmost)
    x -= btnSpacing + listW;
    SetWindowPos(list_button_, nullptr, x, btnY, listW, btnHeight, SWP_NOZORDER);

    // Invalidate the toolbar area to redraw
    RECT toolbarRect = {0, btnY - 5, windowWidth, btnY + btnHeight + 5};
    InvalidateRect(window_handle_, &toolbarRect, TRUE);
}

// ============================================================================
// Show / Hide / Destroy
// ============================================================================

void QuickAddWindow::Show(const flutter::EncodableMap* arguments) {
    // Update arguments if provided
    if (arguments) {
        auto dateIt = arguments->find(flutter::EncodableValue("selectedDate"));
        if (dateIt != arguments->end()) {
            if (auto* val = std::get_if<double>(&dateIt->second)) {
                selected_date_ms_ = *val;
            }
        }

        auto tagsIt = arguments->find(flutter::EncodableValue("tags"));
        if (tagsIt != arguments->end()) {
            available_tags_.clear();
            const auto* tagsList = std::get_if<flutter::EncodableList>(&tagsIt->second);
            if (tagsList) {
                for (const auto& tag : *tagsList) {
                    if (auto* str = std::get_if<std::string>(&tag)) {
                        available_tags_.push_back(NativeWindowManager::Utf8ToWString(*str));
                    }
                }
            }
        }

        auto listsIt = arguments->find(flutter::EncodableValue("taskLists"));
        if (listsIt != arguments->end()) {
            available_task_lists_.clear();
            const auto* listsList = std::get_if<flutter::EncodableList>(&listsIt->second);
            if (listsList) {
                for (const auto& listItem : *listsList) {
                    if (const auto* map = std::get_if<flutter::EncodableMap>(&listItem)) {
                        std::wstring id, name;
                        auto idIt = map->find(flutter::EncodableValue("id"));
                        auto nameIt = map->find(flutter::EncodableValue("name"));
                        if (idIt != map->end()) {
                            if (auto* str = std::get_if<std::string>(&idIt->second)) {
                                id = NativeWindowManager::Utf8ToWString(*str);
                            }
                        }
                        if (nameIt != map->end()) {
                            if (auto* str = std::get_if<std::string>(&nameIt->second)) {
                                name = NativeWindowManager::Utf8ToWString(*str);
                            }
                        }
                        if (!id.empty() && !name.empty()) {
                            available_task_lists_.push_back({id, name});
                        }
                    }
                }
            }
        }
    }

    // Create window if needed
    if (!window_handle_) {
        if (!InitWindow()) {
            std::cerr << "[QuickAddWindow] Failed to initialize window" << std::endl;
            return;
        }
    }

    // Reset to compact mode if expanded
    if (is_expanded_) {
        CollapseToCompactMode();
    }

    // Clear input
    SetWindowTextW(edit_control_, L"");

    // Scale dimensions by DPI
    int scaledWidth = static_cast<int>(kWindowWidth * dpi_scale_);
    int scaledHeight = static_cast<int>(kCompactHeight * dpi_scale_);

    // Recenter window
    int screenWidth = GetSystemMetrics(SM_CXSCREEN);
    int screenHeight = GetSystemMetrics(SM_CYSCREEN);
    int x = (screenWidth - scaledWidth) / 2;
    int y = screenHeight / 4;
    SetWindowPos(window_handle_, HWND_TOPMOST, x, y, scaledWidth, scaledHeight,
                 SWP_SHOWWINDOW);

    // Focus edit control
    SetForegroundWindow(window_handle_);
    SetFocus(edit_control_);

    std::cout << "[QuickAddWindow] Window shown at " << x << "," << y
              << " size " << scaledWidth << "x" << scaledHeight << std::endl;
}

void QuickAddWindow::Hide() {
    if (window_handle_) {
        ShowWindow(window_handle_, SW_HIDE);

        // Reset to compact mode
        if (is_expanded_) {
            CollapseToCompactMode();
        }
    }
    std::cout << "[QuickAddWindow] Window hidden" << std::endl;
}

void QuickAddWindow::Destroy() {
    if (edit_control_) {
        RemoveWindowSubclass(edit_control_, EditSubclassProc, 0);
    }
    if (content_edit_) {
        RemoveWindowSubclass(content_edit_, EditSubclassProc, 1);
    }

    if (window_handle_) {
        DestroyWindow(window_handle_);
        window_handle_ = nullptr;
    }

    edit_control_ = nullptr;
    submit_button_ = nullptr;
    DestroyExpandedControls();

    NativeWindowManager::GetInstance().WindowDidClose("quick_add", window_id_);
    std::cout << "[QuickAddWindow] Window destroyed" << std::endl;
}

void QuickAddWindow::HandleFlutterMessage(
    const std::string& method,
    const flutter::EncodableValue* arguments,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

    if (method == "focus") {
        if (window_handle_) {
            SetForegroundWindow(window_handle_);
            SetFocus(is_expanded_ ? content_edit_ : edit_control_);
        }
        result->Success(flutter::EncodableValue(flutter::EncodableMap{
            {flutter::EncodableValue("success"), flutter::EncodableValue(true)}
        }));
    } else {
        result->NotImplemented();
    }
}
