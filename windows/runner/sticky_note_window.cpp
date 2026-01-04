#include "sticky_note_window.h"
#include <windowsx.h>
#include <uxtheme.h>
#include <algorithm>
#include <sstream>

// Debug logging helper
static void DebugLog(const char* message) {
    OutputDebugStringA(message);
    OutputDebugStringA("\n");
}

static void DebugLogError(const char* prefix, DWORD error) {
    char buffer[256];
    snprintf(buffer, sizeof(buffer), "%s error: %lu", prefix, error);
    OutputDebugStringA(buffer);
    OutputDebugStringA("\n");
}

#pragma comment(lib, "uxtheme.lib")
#pragma comment(lib, "comctl32.lib")

// Static member initialization
const wchar_t* StickyNoteWindow::kWindowClassName = L"AMBER_STICKY_NOTE_WINDOW";
bool StickyNoteWindow::class_registered_ = false;

// Predefined theme colors
static const COLORREF kThemeColors[] = {
    RGB(255, 247, 209),  // Yellow: 0xFFFFF7D1
    RGB(225, 245, 254),  // Blue: 0xFFE1F5FE
    RGB(255, 235, 238),  // Pink: 0xFFFFEBEE
    RGB(232, 245, 233),  // Green: 0xFFE8F5E9
};

// Window size constants
static const int kWindowWidth = 320;
static const int kWindowHeight = 400;
static const int kHeaderHeight = 32;
static const int kPadding = 16;
static const int kButtonSize = 24;

StickyNoteWindow::StickyNoteWindow(const std::wstring& noteId,
                                   const std::wstring& title,
                                   COLORREF themeColor)
    : note_id_(noteId),
      note_title_(title),
      theme_color_(themeColor) {
    bg_brush_ = CreateSolidBrush(theme_color_);

    // Header slightly darker
    int r = GetRValue(theme_color_);
    int g = GetGValue(theme_color_);
    int b = GetBValue(theme_color_);
    header_brush_ = CreateSolidBrush(RGB(
        std::max(0, r - 10),
        std::max(0, g - 10),
        std::max(0, b - 10)
    ));
}

StickyNoteWindow::~StickyNoteWindow() {
    if (bg_brush_) DeleteObject(bg_brush_);
    if (header_brush_) DeleteObject(header_brush_);
    if (window_handle_) DestroyWindow(window_handle_);
}

bool StickyNoteWindow::RegisterWindowClass() {
    if (class_registered_) return true;

    WNDCLASSEXW wcex = {};
    wcex.cbSize = sizeof(WNDCLASSEXW);
    wcex.style = CS_HREDRAW | CS_VREDRAW;
    wcex.lpfnWndProc = WindowProc;
    wcex.hInstance = GetModuleHandle(nullptr);
    wcex.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wcex.hbrBackground = nullptr;  // Custom paint
    wcex.lpszClassName = kWindowClassName;

    if (!RegisterClassExW(&wcex)) {
        DWORD error = GetLastError();
        // ERROR_CLASS_ALREADY_EXISTS (1410) is normal, means class already registered
        if (error == ERROR_CLASS_ALREADY_EXISTS) {
            DebugLog("[StickyNoteWindow] Window class already registered");
            class_registered_ = true;
            return true;
        }
        DebugLogError("[StickyNoteWindow] RegisterClassExW failed,", error);
        return false;
    }

    DebugLog("[StickyNoteWindow] Window class registered successfully");
    class_registered_ = true;
    return true;
}

bool StickyNoteWindow::Create() {
    DebugLog("[StickyNoteWindow] Create() called");

    if (!RegisterWindowClass()) {
        DebugLog("[StickyNoteWindow] Failed to register window class");
        return false;
    }

    // Calculate center position
    int screenWidth = GetSystemMetrics(SM_CXSCREEN);
    int screenHeight = GetSystemMetrics(SM_CYSCREEN);
    int x = (screenWidth - kWindowWidth) / 2;
    int y = (screenHeight - kWindowHeight) / 2;

    char posBuffer[128];
    snprintf(posBuffer, sizeof(posBuffer),
        "[StickyNoteWindow] Creating window at (%d, %d) size %dx%d, screen=%dx%d",
        x, y, kWindowWidth, kWindowHeight, screenWidth, screenHeight);
    DebugLog(posBuffer);

    HINSTANCE hInstance = GetModuleHandle(nullptr);
    char hInstBuffer[64];
    snprintf(hInstBuffer, sizeof(hInstBuffer), "[StickyNoteWindow] hInstance: %p", hInstance);
    DebugLog(hInstBuffer);

    // Create window
    window_handle_ = CreateWindowExW(
        WS_EX_TOOLWINDOW | (is_pinned_ ? WS_EX_TOPMOST : 0),
        kWindowClassName,
        L"Amber Sticky Note",
        WS_OVERLAPPEDWINDOW & ~WS_MAXIMIZEBOX,  // No maximize
        x, y, kWindowWidth, kWindowHeight,
        nullptr, nullptr,
        hInstance,
        this  // Pass this pointer
    );

    if (!window_handle_) {
        DWORD error = GetLastError();
        DebugLogError("[StickyNoteWindow] CreateWindowExW failed,", error);
        return false;
    }

    DebugLog("[StickyNoteWindow] Window created successfully");

    // Create controls
    CreateControls();

    return true;
}

void StickyNoteWindow::Show() {
    if (window_handle_) {
        ShowWindow(window_handle_, SW_SHOWNORMAL);
        UpdateWindow(window_handle_);
        SetForegroundWindow(window_handle_);
    }
}

void StickyNoteWindow::Close() {
    if (window_handle_) {
        DestroyWindow(window_handle_);
        window_handle_ = nullptr;
    }
}

void StickyNoteWindow::Focus() {
    if (window_handle_) {
        if (IsIconic(window_handle_)) {
            ShowWindow(window_handle_, SW_RESTORE);
        }
        SetForegroundWindow(window_handle_);
        SetFocus(window_handle_);
    }
}

void StickyNoteWindow::UpdateTasks(const std::vector<TaskItem>& active,
                                    const std::vector<TaskItem>& completed) {
    active_tasks_ = active;
    completed_tasks_ = completed;
    RebuildTaskList();
}

void StickyNoteWindow::SetPinned(bool pinned) {
    is_pinned_ = pinned;
    if (window_handle_) {
        SetWindowPos(
            window_handle_,
            is_pinned_ ? HWND_TOPMOST : HWND_NOTOPMOST,
            0, 0, 0, 0,
            SWP_NOMOVE | SWP_NOSIZE
        );
        // Update button text
        if (pin_button_) {
            SetWindowTextW(pin_button_, is_pinned_ ? L"P" : L"p");
        }
    }
}

void StickyNoteWindow::SetThemeColor(COLORREF color) {
    theme_color_ = color;

    // Rebuild brushes
    if (bg_brush_) DeleteObject(bg_brush_);
    if (header_brush_) DeleteObject(header_brush_);

    bg_brush_ = CreateSolidBrush(theme_color_);

    int r = GetRValue(theme_color_);
    int g = GetGValue(theme_color_);
    int b = GetBValue(theme_color_);
    header_brush_ = CreateSolidBrush(RGB(
        std::max(0, r - 10),
        std::max(0, g - 10),
        std::max(0, b - 10)
    ));

    // Force repaint
    if (window_handle_) {
        InvalidateRect(window_handle_, nullptr, TRUE);
    }
}

LRESULT CALLBACK StickyNoteWindow::WindowProc(HWND hwnd, UINT message,
                                               WPARAM wparam, LPARAM lparam) {
    StickyNoteWindow* self = nullptr;

    if (message == WM_NCCREATE) {
        auto createStruct = reinterpret_cast<CREATESTRUCT*>(lparam);
        self = static_cast<StickyNoteWindow*>(createStruct->lpCreateParams);
        if (self) {
            // Store hwnd early so HandleMessage can use it
            self->window_handle_ = hwnd;
            SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
        }
        // WM_NCCREATE must return TRUE to continue window creation
        return DefWindowProcW(hwnd, message, wparam, lparam);
    }

    self = reinterpret_cast<StickyNoteWindow*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));

    if (self) {
        return self->HandleMessage(hwnd, message, wparam, lparam);
    }

    return DefWindowProcW(hwnd, message, wparam, lparam);
}

LRESULT StickyNoteWindow::HandleMessage(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
    switch (message) {
        case WM_CREATE:
            return 0;

        case WM_PAINT:
            OnPaint();
            return 0;

        case WM_ERASEBKGND:
            return 1;  // Handle background painting ourselves

        case WM_CTLCOLORSTATIC:
        case WM_CTLCOLORBTN: {
            // Set control background transparent
            HDC hdc = reinterpret_cast<HDC>(wparam);
            SetBkMode(hdc, TRANSPARENT);
            return reinterpret_cast<LRESULT>(bg_brush_);
        }

        case WM_COMMAND: {
            int controlId = LOWORD(wparam);
            int notifyCode = HIWORD(wparam);

            // Checkbox click
            if (notifyCode == BN_CLICKED) {
                if (controlId >= 100 && controlId < 1000) {
                    OnCheckboxClicked(controlId);
                } else {
                    OnButtonClicked(controlId);
                }
            }
            return 0;
        }

        case WM_GETMINMAXINFO: {
            auto minmax = reinterpret_cast<MINMAXINFO*>(lparam);
            minmax->ptMinTrackSize.x = 200;
            minmax->ptMinTrackSize.y = 200;
            minmax->ptMaxTrackSize.x = 600;
            minmax->ptMaxTrackSize.y = 800;
            return 0;
        }

        case WM_CLOSE:
            // Notify Flutter window closed
            if (onWindowClosed) {
                onWindowClosed(note_id_);
            }
            DestroyWindow(window_handle_);
            window_handle_ = nullptr;
            return 0;

        case WM_DESTROY:
            return 0;

        case WM_SIZE:
            // Relayout on resize
            RebuildTaskList();
            return 0;

        case WM_NCHITTEST: {
            // Allow dragging window (header area)
            POINT pt = { GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam) };
            ScreenToClient(hwnd, &pt);
            if (pt.y < kHeaderHeight && pt.x < (kWindowWidth - kButtonSize * 3 - kPadding)) {
                return HTCAPTION;
            }
            break;
        }
    }

    return DefWindowProcW(hwnd, message, wparam, lparam);
}

void StickyNoteWindow::CreateControls() {
    if (!window_handle_) return;

    HFONT hTitleFont = CreateFontW(
        18, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Microsoft YaHei"
    );

    // Header buttons
    int buttonX = kWindowWidth - kPadding - kButtonSize * 3 - 8;
    int buttonY = (kHeaderHeight - kButtonSize) / 2;

    // Color button
    color_button_ = CreateWindowW(
        L"BUTTON", L"*",
        WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON | BS_FLAT,
        buttonX, buttonY, kButtonSize, kButtonSize,
        window_handle_, reinterpret_cast<HMENU>(static_cast<UINT_PTR>(ID_BTN_COLOR)),
        GetModuleHandle(nullptr), nullptr
    );

    // Pin button
    pin_button_ = CreateWindowW(
        L"BUTTON", is_pinned_ ? L"P" : L"p",
        WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON | BS_FLAT,
        buttonX + kButtonSize + 4, buttonY, kButtonSize, kButtonSize,
        window_handle_, reinterpret_cast<HMENU>(static_cast<UINT_PTR>(ID_BTN_PIN)),
        GetModuleHandle(nullptr), nullptr
    );

    // Close button
    close_button_ = CreateWindowW(
        L"BUTTON", L"X",
        WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON | BS_FLAT,
        buttonX + (kButtonSize + 4) * 2, buttonY, kButtonSize, kButtonSize,
        window_handle_, reinterpret_cast<HMENU>(static_cast<UINT_PTR>(ID_BTN_CLOSE)),
        GetModuleHandle(nullptr), nullptr
    );

    // Title label
    title_label_ = CreateWindowW(
        L"STATIC", note_title_.c_str(),
        WS_CHILD | WS_VISIBLE | SS_LEFT,
        kPadding, kHeaderHeight + 12, kWindowWidth - kPadding * 2, 24,
        window_handle_, nullptr,
        GetModuleHandle(nullptr), nullptr
    );
    SendMessage(title_label_, WM_SETFONT, reinterpret_cast<WPARAM>(hTitleFont), TRUE);

    // Initialize task list
    RebuildTaskList();
}

void StickyNoteWindow::RebuildTaskList() {
    if (!window_handle_) return;

    // Clear old checkboxes
    for (auto& pair : checkbox_task_map_) {
        HWND checkbox = GetDlgItem(window_handle_, pair.first);
        if (checkbox) DestroyWindow(checkbox);
    }
    checkbox_task_map_.clear();
    next_control_id_ = 100;

    HFONT hFont = CreateFontW(
        14, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Microsoft YaHei"
    );

    int y = kHeaderHeight + 48;  // Below title

    // Active tasks
    for (const auto& task : active_tasks_) {
        int id = next_control_id_++;
        checkbox_task_map_[id] = task.id;

        HWND checkbox = CreateWindowW(
            L"BUTTON", task.title.c_str(),
            WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX,
            kPadding, y, kWindowWidth - kPadding * 2, 24,
            window_handle_, reinterpret_cast<HMENU>(static_cast<INT_PTR>(id)),
            GetModuleHandle(nullptr), nullptr
        );
        SendMessage(checkbox, WM_SETFONT, reinterpret_cast<WPARAM>(hFont), TRUE);
        SendMessage(checkbox, BM_SETCHECK, task.isCompleted ? BST_CHECKED : BST_UNCHECKED, 0);

        y += 28;
    }

    // Separator (if both exist)
    if (!active_tasks_.empty() && !completed_tasks_.empty()) {
        y += 8;
        // Draw separator with static control
        CreateWindowW(
            L"STATIC", L"",
            WS_CHILD | WS_VISIBLE | SS_ETCHEDHORZ,
            kPadding, y, kWindowWidth - kPadding * 2, 2,
            window_handle_, nullptr,
            GetModuleHandle(nullptr), nullptr
        );
        y += 10;
    }

    // Completed tasks
    for (const auto& task : completed_tasks_) {
        int id = next_control_id_++;
        checkbox_task_map_[id] = task.id;

        HWND checkbox = CreateWindowW(
            L"BUTTON", task.title.c_str(),
            WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX,
            kPadding, y, kWindowWidth - kPadding * 2, 24,
            window_handle_, reinterpret_cast<HMENU>(static_cast<INT_PTR>(id)),
            GetModuleHandle(nullptr), nullptr
        );
        SendMessage(checkbox, WM_SETFONT, reinterpret_cast<WPARAM>(hFont), TRUE);
        SendMessage(checkbox, BM_SETCHECK, BST_CHECKED, 0);

        y += 28;
    }

    // No tasks hint
    if (active_tasks_.empty() && completed_tasks_.empty()) {
        CreateWindowW(
            L"STATIC", L"No tasks",
            WS_CHILD | WS_VISIBLE | SS_LEFT,
            kPadding, y, 200, 20,
            window_handle_, nullptr,
            GetModuleHandle(nullptr), nullptr
        );
    }

    InvalidateRect(window_handle_, nullptr, TRUE);
}

void StickyNoteWindow::OnPaint() {
    PAINTSTRUCT ps;
    HDC hdc = BeginPaint(window_handle_, &ps);

    RECT rect;
    GetClientRect(window_handle_, &rect);

    // Header background
    RECT headerRect = { 0, 0, rect.right, kHeaderHeight };
    FillRect(hdc, &headerRect, header_brush_);

    // Draw header text
    SetBkMode(hdc, TRANSPARENT);
    SetTextColor(hdc, RGB(100, 100, 100));

    HFONT hFont = CreateFontW(
        12, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Microsoft YaHei"
    );
    HFONT oldFont = static_cast<HFONT>(SelectObject(hdc, hFont));

    TextOutW(hdc, 12, 8, L"Amber Note", 10);

    SelectObject(hdc, oldFont);
    DeleteObject(hFont);

    // Content area background
    RECT contentRect = { 0, kHeaderHeight, rect.right, rect.bottom };
    FillRect(hdc, &contentRect, bg_brush_);

    EndPaint(window_handle_, &ps);
}

void StickyNoteWindow::OnCheckboxClicked(int checkboxId) {
    auto it = checkbox_task_map_.find(checkboxId);
    if (it == checkbox_task_map_.end()) return;

    const std::wstring& taskId = it->second;

    // Get new state
    HWND checkbox = GetDlgItem(window_handle_, checkboxId);
    bool isChecked = (SendMessage(checkbox, BM_GETCHECK, 0, 0) == BST_CHECKED);

    // Update local data
    // Move between active and completed
    if (isChecked) {
        // Move to completed
        for (auto taskIt = active_tasks_.begin(); taskIt != active_tasks_.end(); ++taskIt) {
            if (taskIt->id == taskId) {
                TaskItem task = *taskIt;
                task.isCompleted = true;
                active_tasks_.erase(taskIt);
                completed_tasks_.push_back(task);
                break;
            }
        }
    } else {
        // Move to active
        for (auto taskIt = completed_tasks_.begin(); taskIt != completed_tasks_.end(); ++taskIt) {
            if (taskIt->id == taskId) {
                TaskItem task = *taskIt;
                task.isCompleted = false;
                completed_tasks_.erase(taskIt);
                active_tasks_.push_back(task);
                break;
            }
        }
    }

    // Rebuild list (reorder)
    RebuildTaskList();

    // Notify Flutter
    if (onTaskToggled) {
        onTaskToggled(taskId, isChecked);
    }
}

void StickyNoteWindow::OnButtonClicked(int buttonId) {
    switch (buttonId) {
        case ID_BTN_PIN:
            TogglePin();
            break;
        case ID_BTN_COLOR:
            if (color_picker_visible_) {
                HideColorPicker();
            } else {
                ShowColorPicker();
            }
            break;
        case ID_BTN_CLOSE:
            Close();
            break;
        case ID_BTN_COLOR_1:
            SetThemeColor(kThemeColors[0]);
            HideColorPicker();
            break;
        case ID_BTN_COLOR_2:
            SetThemeColor(kThemeColors[1]);
            HideColorPicker();
            break;
        case ID_BTN_COLOR_3:
            SetThemeColor(kThemeColors[2]);
            HideColorPicker();
            break;
        case ID_BTN_COLOR_4:
            SetThemeColor(kThemeColors[3]);
            HideColorPicker();
            break;
    }
}

void StickyNoteWindow::TogglePin() {
    SetPinned(!is_pinned_);
}

void StickyNoteWindow::ShowColorPicker() {
    if (color_picker_visible_) return;
    color_picker_visible_ = true;

    // Hide original buttons
    ShowWindow(pin_button_, SW_HIDE);
    ShowWindow(color_button_, SW_HIDE);
    ShowWindow(close_button_, SW_HIDE);

    int buttonY = (kHeaderHeight - 16) / 2;
    int x = kWindowWidth - kPadding - (20 * 4 + 12);

    // Create color selection buttons
    for (int i = 0; i < 4; i++) {
        CreateWindowW(
            L"BUTTON", L"",
            WS_CHILD | WS_VISIBLE | BS_OWNERDRAW,
            x + i * 20, buttonY, 16, 16,
            window_handle_, reinterpret_cast<HMENU>(static_cast<INT_PTR>(ID_BTN_COLOR_1 + i)),
            GetModuleHandle(nullptr), nullptr
        );
    }
}

void StickyNoteWindow::HideColorPicker() {
    if (!color_picker_visible_) return;
    color_picker_visible_ = false;

    // Destroy color buttons
    for (int i = 0; i < 4; i++) {
        HWND btn = GetDlgItem(window_handle_, ID_BTN_COLOR_1 + i);
        if (btn) DestroyWindow(btn);
    }

    // Show original buttons
    ShowWindow(pin_button_, SW_SHOW);
    ShowWindow(color_button_, SW_SHOW);
    ShowWindow(close_button_, SW_SHOW);
}