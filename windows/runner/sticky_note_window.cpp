#include "sticky_note_window.h"
#include <windowsx.h>
#include <dwmapi.h>
#include <algorithm>
#include <iostream>

#pragma comment(lib, "dwmapi.lib")

// Static member initialization
const wchar_t* StickyNoteWindow::kWindowClassName = L"AMBER_STICKY_NOTE_WINDOW_V2";
bool StickyNoteWindow::class_registered_ = false;
ULONG_PTR StickyNoteWindow::gdiplus_token_ = 0;
bool StickyNoteWindow::gdiplus_initialized_ = false;

// Theme colors in ARGB format for GDI+
const DWORD StickyNoteWindow::kThemeColors[] = {
    0xFFFFF7D1,  // Yellow
    0xFFE1F5FE,  // Blue
    0xFFFFEBEE,  // Pink
    0xFFE8F5E9,  // Green
};

// Font size presets: small, medium, large, extra large
const float StickyNoteWindow::kTitleFontSizes[] = { 16.0f, 20.0f, 24.0f, 28.0f };
const float StickyNoteWindow::kTaskFontSizes[] = { 12.0f, 15.0f, 18.0f, 22.0f };
const wchar_t* StickyNoteWindow::kFontSizeLabels[] = {
    L"\x5C0F",      // Small
    L"\x4E2D",      // Medium
    L"\x5927",      // Large
    L"\x7279\x5927" // Extra Large
};

// Helper: Convert COLORREF (BGR) to GDI+ ARGB
static Gdiplus::Color ColorRefToGdiPlus(COLORREF cr, BYTE alpha = 255) {
    return Gdiplus::Color(alpha, GetRValue(cr), GetGValue(cr), GetBValue(cr));
}

// Helper: Convert ARGB DWORD to COLORREF
static COLORREF ArgbToColorRef(DWORD argb) {
    return RGB((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);
}

// Helper: Create rounded rectangle path
static void AddRoundedRect(Gdiplus::GraphicsPath& path, const Gdiplus::RectF& rect, float radius) {
    float diameter = radius * 2;
    Gdiplus::RectF arc(rect.X, rect.Y, diameter, diameter);

    // Top-left
    path.AddArc(arc, 180, 90);

    // Top-right
    arc.X = rect.GetRight() - diameter;
    path.AddArc(arc, 270, 90);

    // Bottom-right
    arc.Y = rect.GetBottom() - diameter;
    path.AddArc(arc, 0, 90);

    // Bottom-left
    arc.X = rect.X;
    path.AddArc(arc, 90, 90);

    path.CloseFigure();
}

StickyNoteWindow::StickyNoteWindow(const std::wstring& noteId,
                                   const std::wstring& title,
                                   COLORREF themeColor)
    : note_id_(noteId),
      note_title_(title),
      theme_color_(themeColor) {
    InitGdiPlus();
}

StickyNoteWindow::~StickyNoteWindow() {
    if (window_handle_) {
        DestroyWindow(window_handle_);
        window_handle_ = nullptr;
    }
}

void StickyNoteWindow::InitGdiPlus() {
    if (!gdiplus_initialized_) {
        Gdiplus::GdiplusStartupInput gdiplusStartupInput;
        Gdiplus::GdiplusStartup(&gdiplus_token_, &gdiplusStartupInput, nullptr);
        gdiplus_initialized_ = true;
    }
}

bool StickyNoteWindow::RegisterWindowClass() {
    if (class_registered_) return true;

    WNDCLASSEXW wcex = {};
    wcex.cbSize = sizeof(WNDCLASSEXW);
    wcex.style = CS_HREDRAW | CS_VREDRAW | CS_DROPSHADOW;
    wcex.lpfnWndProc = WindowProc;
    wcex.hInstance = GetModuleHandle(nullptr);
    wcex.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wcex.hbrBackground = nullptr;
    wcex.lpszClassName = kWindowClassName;

    if (!RegisterClassExW(&wcex)) {
        DWORD error = GetLastError();
        if (error == ERROR_CLASS_ALREADY_EXISTS) {
            class_registered_ = true;
            return true;
        }
        std::cout << "[StickyNoteWindow] RegisterClassExW failed: " << error << std::endl;
        return false;
    }

    class_registered_ = true;
    return true;
}

bool StickyNoteWindow::Create() {
    if (!RegisterWindowClass()) {
        return false;
    }

    // Center on screen
    int screenWidth = GetSystemMetrics(SM_CXSCREEN);
    int screenHeight = GetSystemMetrics(SM_CYSCREEN);
    int x = (screenWidth - kWindowWidth) / 2;
    int y = (screenHeight - kWindowHeight) / 2;

    // Create popup window (no border, no title bar)
    // Use WS_EX_TOOLWINDOW to hide from taskbar
    window_handle_ = CreateWindowExW(
        WS_EX_TOOLWINDOW | (is_pinned_ ? WS_EX_TOPMOST : 0),
        kWindowClassName,
        L"",
        WS_POPUP,
        x, y, kWindowWidth, kWindowHeight,
        nullptr, nullptr,
        GetModuleHandle(nullptr),
        this
    );

    if (!window_handle_) {
        std::cout << "[StickyNoteWindow] CreateWindowExW failed: " << GetLastError() << std::endl;
        return false;
    }

    // Set rounded corners using window region (clip corners)
    HRGN hRgn = CreateRoundRectRgn(0, 0, kWindowWidth + 1, kWindowHeight + 1,
                                    kCornerRadius * 2, kCornerRadius * 2);
    SetWindowRgn(window_handle_, hRgn, TRUE);

    // Create fonts (larger sizes for better readability)
    Gdiplus::FontFamily fontFamily(L"Microsoft YaHei");
    header_font_ = std::make_unique<Gdiplus::Font>(&fontFamily, 13.0f, Gdiplus::FontStyleRegular, Gdiplus::UnitPixel);
    title_font_ = std::make_unique<Gdiplus::Font>(&fontFamily, 20.0f, Gdiplus::FontStyleBold, Gdiplus::UnitPixel);
    task_font_ = std::make_unique<Gdiplus::Font>(&fontFamily, 15.0f, Gdiplus::FontStyleRegular, Gdiplus::UnitPixel);

    // Enable mouse tracking
    TRACKMOUSEEVENT tme = { sizeof(tme), TME_LEAVE, window_handle_, 0 };
    TrackMouseEvent(&tme);

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
        // Copy callback and noteId before destroying anything
        // because the callback may delete 'this'
        auto callback = std::move(onWindowClosed);
        std::wstring noteId = note_id_;

        // Clear callback to prevent double-call
        onWindowClosed = nullptr;

        // Destroy the window
        HWND hwnd = window_handle_;
        window_handle_ = nullptr;  // Prevent destructor from double-destroying
        DestroyWindow(hwnd);

        // Finally notify (this may delete 'this', so do it last and use local copies)
        if (callback) {
            callback(noteId);
        }
    }
}

void StickyNoteWindow::Focus() {
    if (window_handle_) {
        if (IsIconic(window_handle_)) {
            ShowWindow(window_handle_, SW_RESTORE);
        }
        SetForegroundWindow(window_handle_);
    }
}

void StickyNoteWindow::UpdateTasks(const std::vector<TaskItem>& active,
                                    const std::vector<TaskItem>& completed) {
    active_tasks_ = active;
    completed_tasks_ = completed;
    scroll_offset_ = 0;  // Reset scroll on update
    UpdateScrollBounds();
    if (window_handle_) {
        InvalidateRect(window_handle_, nullptr, FALSE);
    }
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
        InvalidateRect(window_handle_, nullptr, FALSE);
    }
}

void StickyNoteWindow::SetThemeColor(COLORREF color) {
    theme_color_ = color;
    if (window_handle_) {
        InvalidateRect(window_handle_, nullptr, FALSE);
    }
}

LRESULT CALLBACK StickyNoteWindow::WindowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
    StickyNoteWindow* self = nullptr;

    if (message == WM_NCCREATE) {
        auto createStruct = reinterpret_cast<CREATESTRUCT*>(lparam);
        self = static_cast<StickyNoteWindow*>(createStruct->lpCreateParams);
        if (self) {
            self->window_handle_ = hwnd;
            SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
        }
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
        case WM_PAINT:
            OnPaint();
            return 0;

        case WM_ERASEBKGND:
            return 1;

        case WM_LBUTTONDOWN:
            OnMouseDown(GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam));
            return 0;

        case WM_LBUTTONUP:
            OnMouseUp(GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam));
            return 0;

        case WM_MOUSEMOVE:
            OnMouseMove(GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam));
            return 0;

        case WM_MOUSELEAVE:
            OnMouseLeave();
            return 0;

        case WM_MOUSEWHEEL:
            OnMouseWheel(GET_WHEEL_DELTA_WPARAM(wparam));
            return 0;

        case WM_NCHITTEST: {
            POINT pt = { GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam) };
            ScreenToClient(hwnd, &pt);

            // Header area is draggable (except buttons)
            if (pt.y < kHeaderHeight) {
                // 4 buttons: color, fontsize, pin, close
                int buttonArea = kWindowWidth - kPadding - kButtonSize * 4 - 12;
                if (pt.x < buttonArea) {
                    return HTCAPTION;
                }
            }
            return HTCLIENT;
        }

        case WM_DESTROY:
            return 0;

        case WM_USER + 100:
            // Async close request from button click
            Close();
            return 0;
    }

    return DefWindowProcW(hwnd, message, wparam, lparam);
}

void StickyNoteWindow::OnPaint() {
    PAINTSTRUCT ps;
    HDC hdc = BeginPaint(window_handle_, &ps);

    // Get client rect
    RECT clientRect;
    GetClientRect(window_handle_, &clientRect);
    int width = clientRect.right;
    int height = clientRect.bottom;

    // Create double buffer
    HDC memDC = CreateCompatibleDC(hdc);
    HBITMAP memBitmap = CreateCompatibleBitmap(hdc, width, height);
    HBITMAP oldBitmap = (HBITMAP)SelectObject(memDC, memBitmap);

    // Create GDI+ graphics
    Gdiplus::Graphics g(memDC);
    g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    g.SetTextRenderingHint(Gdiplus::TextRenderingHintClearTypeGridFit);

    // Fill background with theme color (window region handles rounded corners)
    g.Clear(ColorRefToGdiPlus(theme_color_));

    // Draw header
    Gdiplus::RectF headerRect(0, 0, (float)width, (float)kHeaderHeight);
    DrawHeader(g, headerRect);

    // Draw content
    Gdiplus::RectF contentRect(0, (float)kHeaderHeight, (float)width, (float)(height - kHeaderHeight));
    DrawContent(g, contentRect);

    // Draw font menu on top of everything if visible
    if (font_menu_visible_) {
        DrawFontMenu(g);
    }

    // Copy to screen
    BitBlt(hdc, 0, 0, width, height, memDC, 0, 0, SRCCOPY);

    // Cleanup
    SelectObject(memDC, oldBitmap);
    DeleteObject(memBitmap);
    DeleteDC(memDC);

    EndPaint(window_handle_, &ps);
}

void StickyNoteWindow::DrawHeader(Gdiplus::Graphics& g, const Gdiplus::RectF& rect) {
    // Header background (slightly darker)
    int r = GetRValue(theme_color_);
    int gr = GetGValue(theme_color_);
    int b = GetBValue(theme_color_);
    Gdiplus::Color headerColor(255,
        (BYTE)std::max(0, r - 5),
        (BYTE)std::max(0, gr - 5),
        (BYTE)std::max(0, b - 5));
    Gdiplus::SolidBrush headerBrush(headerColor);
    g.FillRectangle(&headerBrush, rect);

    // Draw emoji icon using Segoe UI Emoji font
    Gdiplus::FontFamily emojiFamily(L"Segoe UI Emoji");
    Gdiplus::Font emojiFont(&emojiFamily, 14.0f, Gdiplus::FontStyleRegular, Gdiplus::UnitPixel);
    Gdiplus::SolidBrush emojiBrush(Gdiplus::Color(255, 80, 80, 80));
    Gdiplus::PointF emojiPos(10.0f, 8.0f);
    g.DrawString(L"\U0001F4DD", -1, &emojiFont, emojiPos, &emojiBrush);

    // Draw header title text
    Gdiplus::SolidBrush labelBrush(Gdiplus::Color(180, 80, 80, 80));
    Gdiplus::PointF titlePos(30.0f, 9.0f);
    g.DrawString(L"\x7425\x73C0\x4FBF\x7B7E", -1, header_font_.get(), titlePos, &labelBrush);

    // Draw buttons (right side): Close, Pin, FontSize, Color
    float buttonY = (kHeaderHeight - kButtonSize) / 2.0f;
    float buttonX = (float)(kWindowWidth - kPadding - kButtonSize);

    if (color_picker_visible_) {
        // Draw color picker (replaces all buttons)
        DrawColorPicker(g, buttonY);
    } else {
        // Always draw buttons (even when font menu is visible)
        // Close button (rightmost)
        DrawIconButton(g, kButtonClose, buttonX, buttonY, (float)kButtonSize);

        // Pin button
        buttonX -= kButtonSize + 4;
        DrawIconButton(g, kButtonPin, buttonX, buttonY, (float)kButtonSize);

        // Font size button
        buttonX -= kButtonSize + 4;
        DrawIconButton(g, kButtonFontSize, buttonX, buttonY, (float)kButtonSize);

        // Color button (leftmost)
        buttonX -= kButtonSize + 4;
        DrawIconButton(g, kButtonColor, buttonX, buttonY, (float)kButtonSize);
    }
    // Note: Font menu is drawn in OnPaint after content, so it appears on top
}

void StickyNoteWindow::DrawIconButton(Gdiplus::Graphics& g, int buttonId, float x, float y, float size) {
    bool isHovered = (hovered_button_ == buttonId);
    bool isPressed = (pressed_button_ == buttonId);

    // Button background on hover
    if (isHovered || isPressed) {
        Gdiplus::SolidBrush hoverBrush(Gdiplus::Color(30, 0, 0, 0));
        Gdiplus::RectF btnRect(x, y, size, size);
        g.FillRectangle(&hoverBrush, btnRect);
    }

    // Button icon color
    Gdiplus::Color iconColor;
    if (buttonId == kButtonPin && is_pinned_) {
        iconColor = Gdiplus::Color(255, 245, 166, 35);  // Orange when pinned
    } else if (buttonId == kButtonClose) {
        iconColor = Gdiplus::Color(255, 100, 100, 100);
    } else {
        iconColor = Gdiplus::Color(180, 100, 100, 100);
    }

    Gdiplus::SolidBrush iconBrush(iconColor);
    Gdiplus::Pen iconPen(iconColor, 1.5f);

    float cx = x + size / 2.0f;
    float cy = y + size / 2.0f;

    switch (buttonId) {
        case kButtonColor: {
            // Paintpalette icon (like SF Symbol paintpalette) - ENLARGED
            // Draw palette base shape (bean shape)
            Gdiplus::GraphicsPath palettePath;
            palettePath.AddEllipse(cx - 9.0f, cy - 6.0f, 18.0f, 12.0f);
            Gdiplus::Pen thickPen(iconColor, 1.8f);
            g.DrawPath(&thickPen, &palettePath);

            // Draw 3 color dots inside - larger dots
            Gdiplus::SolidBrush redDot(Gdiplus::Color(255, 220, 80, 80));
            Gdiplus::SolidBrush greenDot(Gdiplus::Color(255, 80, 180, 80));
            Gdiplus::SolidBrush blueDot(Gdiplus::Color(255, 80, 120, 200));

            Gdiplus::RectF dot1(cx - 6.5f, cy - 2.5f, 5.0f, 5.0f);
            Gdiplus::RectF dot2(cx - 1.0f, cy - 2.5f, 5.0f, 5.0f);
            Gdiplus::RectF dot3(cx + 3.5f, cy - 2.5f, 5.0f, 5.0f);
            g.FillEllipse(&redDot, dot1);
            g.FillEllipse(&greenDot, dot2);
            g.FillEllipse(&blueDot, dot3);
            break;
        }
        case kButtonFontSize: {
            // Font size icon - "Aa" text style (like macOS text size control) - ENLARGED
            Gdiplus::FontFamily fontFamily(L"Segoe UI");

            // Small "A" (representing smaller font)
            Gdiplus::Font smallFont(&fontFamily, 11.0f, Gdiplus::FontStyleBold, Gdiplus::UnitPixel);
            Gdiplus::PointF smallPos(cx - 9.0f, cy - 5.0f);
            g.DrawString(L"A", -1, &smallFont, smallPos, &iconBrush);

            // Large "a" (representing larger font)
            Gdiplus::Font largeFont(&fontFamily, 15.0f, Gdiplus::FontStyleBold, Gdiplus::UnitPixel);
            Gdiplus::PointF largePos(cx - 1.0f, cy - 8.0f);
            g.DrawString(L"a", -1, &largeFont, largePos, &iconBrush);

            // Draw small down arrow indicator (shows it's a dropdown)
            Gdiplus::PointF arrowPoints[3] = {
                Gdiplus::PointF(cx + 6.0f, cy + 3.0f),
                Gdiplus::PointF(cx + 10.0f, cy + 3.0f),
                Gdiplus::PointF(cx + 8.0f, cy + 6.0f)
            };
            g.FillPolygon(&iconBrush, arrowPoints, 3);
            break;
        }
        case kButtonPin: {
            // macOS style diagonal pin icon (tilted at 45 degrees) - ENLARGED
            // Pin consists of: oval head + shaft + needle tip

            // Save current transform
            Gdiplus::Matrix originalMatrix;
            g.GetTransform(&originalMatrix);

            // Rotate 45 degrees around center
            g.TranslateTransform(cx, cy);
            g.RotateTransform(-45.0f);
            g.TranslateTransform(-cx, -cy);

            // Draw pin head (rounded rectangle / oval) - larger
            Gdiplus::RectF pinHead(cx - 4.5f, cy - 9.0f, 9.0f, 7.0f);
            g.FillEllipse(&iconBrush, pinHead);

            // Draw pin shaft (rectangle) - larger
            Gdiplus::RectF pinShaft(cx - 2.0f, cy - 3.0f, 4.0f, 6.0f);
            g.FillRectangle(&iconBrush, pinShaft);

            // Draw pin needle (triangle pointing down) - larger
            Gdiplus::PointF needlePoints[3] = {
                Gdiplus::PointF(cx - 2.0f, cy + 3.0f),
                Gdiplus::PointF(cx + 2.0f, cy + 3.0f),
                Gdiplus::PointF(cx, cy + 10.0f)
            };
            g.FillPolygon(&iconBrush, needlePoints, 3);

            // Restore transform
            g.SetTransform(&originalMatrix);
            break;
        }
        case kButtonClose: {
            // X icon (like SF Symbol xmark) - ENLARGED
            Gdiplus::Pen closePen(iconColor, 2.2f);
            closePen.SetLineCap(Gdiplus::LineCapRound, Gdiplus::LineCapRound, Gdiplus::DashCapRound);
            g.DrawLine(&closePen, cx - 5.0f, cy - 5.0f, cx + 5.0f, cy + 5.0f);
            g.DrawLine(&closePen, cx + 5.0f, cy - 5.0f, cx - 5.0f, cy + 5.0f);
            break;
        }
    }
}

void StickyNoteWindow::DrawColorPicker(Gdiplus::Graphics& g, float y) {
    float x = (float)(kWindowWidth - kPadding - kColorDotSize * 4 - 12 - kButtonSize);

    // Draw color dots
    for (int i = 0; i < kThemeColorCount; i++) {
        float dotX = x + i * (kColorDotSize + 4);
        bool isHovered = (hovered_color_ == i);

        // Color dot
        Gdiplus::Color dotColor(
            (kThemeColors[i] >> 24) & 0xFF,
            (kThemeColors[i] >> 16) & 0xFF,
            (kThemeColors[i] >> 8) & 0xFF,
            kThemeColors[i] & 0xFF
        );
        Gdiplus::SolidBrush dotBrush(dotColor);

        Gdiplus::RectF dotRect(dotX, y + (kButtonSize - kColorDotSize) / 2,
                               (float)kColorDotSize, (float)kColorDotSize);

        // Hover effect
        if (isHovered) {
            Gdiplus::Pen hoverPen(Gdiplus::Color(100, 0, 0, 0), 2);
            g.DrawEllipse(&hoverPen, dotRect);
        }

        g.FillEllipse(&dotBrush, dotRect);

        // Border
        Gdiplus::Pen borderPen(Gdiplus::Color(40, 0, 0, 0), 1);
        g.DrawEllipse(&borderPen, dotRect);
    }

    // Cancel button (X)
    float cancelX = x + kThemeColorCount * (kColorDotSize + 4) + 4;
    bool isHovered = (hovered_button_ == kButtonClose);

    if (isHovered) {
        Gdiplus::SolidBrush hoverBrush(Gdiplus::Color(30, 0, 0, 0));
        g.FillRectangle(&hoverBrush, cancelX, y, (float)kButtonSize, (float)kButtonSize);
    }

    Gdiplus::Pen cancelPen(Gdiplus::Color(180, 100, 100, 100), 1.5f);
    float ccx = cancelX + kButtonSize / 2;
    float ccy = y + kButtonSize / 2;
    g.DrawLine(&cancelPen, ccx - 4, ccy - 4, ccx + 4, ccy + 4);
    g.DrawLine(&cancelPen, ccx + 4, ccy - 4, ccx - 4, ccy + 4);
}

void StickyNoteWindow::DrawContent(Gdiplus::Graphics& g, const Gdiplus::RectF& rect) {
    // Get actual title font height for dynamic spacing
    float titleFontHeight = title_font_->GetHeight(&g);

    // Title - with dynamic top padding
    Gdiplus::SolidBrush titleBrush(Gdiplus::Color(220, 50, 50, 50));
    Gdiplus::PointF titlePos((float)kPadding, rect.Y + 10);
    g.DrawString(note_title_.c_str(), -1, title_font_.get(), titlePos, &titleBrush);

    // Calculate dynamic title area height based on font size
    // Base padding (10) + font height + bottom margin (12)
    float dynamicTitleHeight = 10 + titleFontHeight + 12;

    // Task list area - uses dynamic title height
    float taskAreaTop = rect.Y + dynamicTitleHeight;
    float taskAreaHeight = rect.Height - dynamicTitleHeight - kPadding;

    // Create clipping region for scroll
    Gdiplus::RectF clipRect((float)kPadding, taskAreaTop,
                            (float)(kWindowWidth - kPadding * 2), taskAreaHeight);
    g.SetClip(clipRect);

    float y = taskAreaTop - scroll_offset_;

    // Active tasks
    for (size_t i = 0; i < active_tasks_.size(); i++) {
        if (y + kTaskItemHeight > taskAreaTop && y < taskAreaTop + taskAreaHeight) {
            DrawTaskItem(g, active_tasks_[i], y, false);
        }
        y += kTaskItemHeight;
    }

    // Separator
    if (!active_tasks_.empty() && !completed_tasks_.empty()) {
        if (y > taskAreaTop && y < taskAreaTop + taskAreaHeight) {
            Gdiplus::Pen sepPen(Gdiplus::Color(50, 0, 0, 0), 1);
            g.DrawLine(&sepPen, (float)kPadding, y + 8,
                      (float)(kWindowWidth - kPadding), y + 8);
        }
        y += 16;
    }

    // Completed tasks
    for (size_t i = 0; i < completed_tasks_.size(); i++) {
        if (y + kTaskItemHeight > taskAreaTop && y < taskAreaTop + taskAreaHeight) {
            DrawTaskItem(g, completed_tasks_[i], y, true);
        }
        y += kTaskItemHeight;
    }

    // No tasks hint
    if (active_tasks_.empty() && completed_tasks_.empty()) {
        Gdiplus::SolidBrush hintBrush(Gdiplus::Color(150, 100, 100, 100));
        Gdiplus::PointF hintPos((float)kPadding, taskAreaTop + 8);
        g.DrawString(L"\x6682\x65E0\x4EFB\x52A1", -1, task_font_.get(), hintPos, &hintBrush);
    }

    g.ResetClip();
}

void StickyNoteWindow::DrawTaskItem(Gdiplus::Graphics& g, const TaskItem& task, float y, bool isCompleted) {
    float x = (float)kPadding;

    // Get actual font height for proper vertical centering
    float fontHeight = task_font_->GetHeight(&g);
    float itemCenterY = y + kTaskItemHeight / 2.0f;

    // Checkbox - vertically centered
    Gdiplus::RectF checkRect(x, itemCenterY - kCheckboxSize / 2.0f,
                            (float)kCheckboxSize, (float)kCheckboxSize);

    // Checkbox border
    Gdiplus::Pen checkPen(Gdiplus::Color(100, 100, 100, 100), 1.5f);
    Gdiplus::GraphicsPath checkPath;
    AddRoundedRect(checkPath, checkRect, 4);
    g.DrawPath(&checkPen, &checkPath);

    if (isCompleted) {
        // Filled checkbox
        Gdiplus::SolidBrush checkFill(Gdiplus::Color(255, 66, 133, 244));  // Blue
        g.FillPath(&checkFill, &checkPath);

        // Checkmark
        Gdiplus::Pen checkmarkPen(Gdiplus::Color(255, 255, 255, 255), 2);
        float cx = checkRect.X + checkRect.Width / 2;
        float cy = checkRect.Y + checkRect.Height / 2;
        g.DrawLine(&checkmarkPen, cx - 4, cy, cx - 1, cy + 3);
        g.DrawLine(&checkmarkPen, cx - 1, cy + 3, cx + 4, cy - 3);
    }

    // Task title - vertically centered with font height
    float textX = x + kCheckboxSize + 10;
    float textY = itemCenterY - fontHeight / 2.0f;
    Gdiplus::PointF textPos(textX, textY);

    if (isCompleted) {
        // Strikethrough text
        Gdiplus::SolidBrush textBrush(Gdiplus::Color(150, 120, 120, 120));
        g.DrawString(task.title.c_str(), -1, task_font_.get(), textPos, &textBrush);

        // Draw strikethrough line at text center
        Gdiplus::RectF textBounds;
        g.MeasureString(task.title.c_str(), -1, task_font_.get(), textPos, &textBounds);
        float lineY = itemCenterY;
        Gdiplus::Pen strikePen(Gdiplus::Color(150, 120, 120, 120), 1);
        g.DrawLine(&strikePen, textX, lineY, textX + textBounds.Width, lineY);
    } else {
        Gdiplus::SolidBrush textBrush(Gdiplus::Color(220, 50, 50, 50));
        g.DrawString(task.title.c_str(), -1, task_font_.get(), textPos, &textBrush);
    }
}

int StickyNoteWindow::HitTestButton(int x, int y) {
    if (y < 0 || y > kHeaderHeight) return -1;

    float buttonY = (kHeaderHeight - kButtonSize) / 2.0f;
    if (y < buttonY || y > buttonY + kButtonSize) return -1;

    // Button layout from right to left: Close, Pin, FontSize, Color
    float closeX = (float)(kWindowWidth - kPadding - kButtonSize);
    float pinX = closeX - kButtonSize - 4;
    float fontSizeX = pinX - kButtonSize - 4;
    float colorX = fontSizeX - kButtonSize - 4;

    if (x >= closeX && x < closeX + kButtonSize) return kButtonClose;
    if (x >= pinX && x < pinX + kButtonSize) return kButtonPin;
    if (x >= fontSizeX && x < fontSizeX + kButtonSize) return kButtonFontSize;
    if (x >= colorX && x < colorX + kButtonSize) return kButtonColor;

    return -1;
}

int StickyNoteWindow::HitTestTask(int y) {
    float taskAreaTop = kHeaderHeight + kTitleHeight;
    float taskAreaBottom = kWindowHeight - kPadding;

    if (y < taskAreaTop || y > taskAreaBottom) return -1;

    float adjustedY = y + scroll_offset_ - taskAreaTop;
    int index = (int)(adjustedY / kTaskItemHeight);

    int totalActive = (int)active_tasks_.size();
    if (index < totalActive) {
        return index;  // Active task
    }

    // Account for separator
    if (!active_tasks_.empty() && !completed_tasks_.empty()) {
        adjustedY -= 16;  // Separator height
        index = (int)(adjustedY / kTaskItemHeight);
    }

    if (index >= totalActive && index < totalActive + (int)completed_tasks_.size()) {
        return index;  // Completed task
    }

    return -1;
}

int StickyNoteWindow::HitTestColorPicker(int x, int y) {
    if (!color_picker_visible_) return -1;

    float buttonY = (kHeaderHeight - kButtonSize) / 2.0f;
    if (y < buttonY || y > buttonY + kButtonSize) return -1;

    float startX = (float)(kWindowWidth - kPadding - kColorDotSize * 4 - 12 - kButtonSize);

    for (int i = 0; i < kThemeColorCount; i++) {
        float dotX = startX + i * (kColorDotSize + 4);
        if (x >= dotX && x < dotX + kColorDotSize) {
            return i;
        }
    }

    // Cancel button
    float cancelX = startX + kThemeColorCount * (kColorDotSize + 4) + 4;
    if (x >= cancelX && x < cancelX + kButtonSize) {
        return -2;  // Cancel
    }

    return -1;
}

void StickyNoteWindow::OnMouseDown(int x, int y) {
    // Check font menu first (it's on top)
    if (font_menu_visible_) {
        int fontItem = HitTestFontMenu(x, y);
        if (fontItem >= 0) {
            SelectFontSize(fontItem);
            return;
        } else {
            // Click outside menu closes it
            font_menu_visible_ = false;
            InvalidateRect(window_handle_, nullptr, FALSE);
            return;
        }
    }

    // Check color picker
    if (color_picker_visible_) {
        int colorIndex = HitTestColorPicker(x, y);
        if (colorIndex >= 0) {
            SelectColor(colorIndex);
            return;
        } else if (colorIndex == -2) {
            ToggleColorPicker();
            return;
        }
    }

    // Check buttons
    int button = HitTestButton(x, y);
    if (button >= 0) {
        pressed_button_ = button;
        InvalidateRect(window_handle_, nullptr, FALSE);
        return;
    }

    // Check task click (for checkbox)
    int taskIndex = HitTestTask(y);
    if (taskIndex >= 0) {
        // Check if clicking on checkbox area
        if (x >= kPadding && x < kPadding + kCheckboxSize + 10) {
            ToggleTask(taskIndex);
        }
    }
}

void StickyNoteWindow::OnMouseUp(int x, int y) {
    if (pressed_button_ >= 0) {
        int button = HitTestButton(x, y);
        if (button == pressed_button_) {
            switch (button) {
                case kButtonColor:
                    ToggleColorPicker();
                    break;
                case kButtonFontSize:
                    ToggleFontMenu();
                    break;
                case kButtonPin:
                    TogglePin();
                    break;
                case kButtonClose:
                    // Use PostMessage to close asynchronously, avoiding issues
                    // with destroying the window while handling mouse events
                    PostMessage(window_handle_, WM_USER + 100, 0, 0);
                    return;
            }
        }
        pressed_button_ = -1;
        InvalidateRect(window_handle_, nullptr, FALSE);
    }
}

void StickyNoteWindow::OnMouseMove(int x, int y) {
    // Track mouse leave
    TRACKMOUSEEVENT tme = { sizeof(tme), TME_LEAVE, window_handle_, 0 };
    TrackMouseEvent(&tme);

    int oldHovered = hovered_button_;
    int oldColor = hovered_color_;
    int oldFontItem = hovered_font_item_;

    // Check font menu first
    if (font_menu_visible_) {
        hovered_font_item_ = HitTestFontMenu(x, y);
        hovered_button_ = -1;
        hovered_color_ = -1;
    } else if (color_picker_visible_) {
        hovered_color_ = HitTestColorPicker(x, y);
        hovered_font_item_ = -1;
        if (hovered_color_ == -2) {
            hovered_button_ = kButtonClose;
            hovered_color_ = -1;
        } else {
            hovered_button_ = -1;
        }
    } else {
        hovered_button_ = HitTestButton(x, y);
        hovered_color_ = -1;
        hovered_font_item_ = -1;
    }

    if (hovered_button_ != oldHovered || hovered_color_ != oldColor || hovered_font_item_ != oldFontItem) {
        InvalidateRect(window_handle_, nullptr, FALSE);
    }
}

void StickyNoteWindow::OnMouseLeave() {
    if (hovered_button_ >= 0 || hovered_color_ >= 0 || hovered_font_item_ >= 0) {
        hovered_button_ = -1;
        hovered_color_ = -1;
        hovered_font_item_ = -1;
        InvalidateRect(window_handle_, nullptr, FALSE);
    }
}

void StickyNoteWindow::OnMouseWheel(int delta) {
    float scrollAmount = delta / 120.0f * 30.0f;  // 30 pixels per notch
    scroll_offset_ = std::max(0.0f, std::min(max_scroll_, scroll_offset_ - scrollAmount));
    InvalidateRect(window_handle_, nullptr, FALSE);
}

void StickyNoteWindow::UpdateScrollBounds() {
    int totalTasks = (int)(active_tasks_.size() + completed_tasks_.size());
    float separator = (!active_tasks_.empty() && !completed_tasks_.empty()) ? 16.0f : 0.0f;
    float contentHeight = (float)(totalTasks * kTaskItemHeight) + separator;
    float viewHeight = (float)(kWindowHeight - kHeaderHeight - kTitleHeight - kPadding);

    max_scroll_ = std::max(0.0f, contentHeight - viewHeight);
}

void StickyNoteWindow::TogglePin() {
    SetPinned(!is_pinned_);
}

void StickyNoteWindow::ToggleColorPicker() {
    color_picker_visible_ = !color_picker_visible_;
    hovered_color_ = -1;
    InvalidateRect(window_handle_, nullptr, FALSE);
}

void StickyNoteWindow::ToggleFontMenu() {
    font_menu_visible_ = !font_menu_visible_;
    hovered_font_item_ = -1;
    InvalidateRect(window_handle_, nullptr, FALSE);
}

void StickyNoteWindow::SelectFontSize(int index) {
    if (index >= 0 && index < kFontSizeCount) {
        current_font_size_index_ = index;
        UpdateFonts();
        font_menu_visible_ = false;
        InvalidateRect(window_handle_, nullptr, FALSE);
    }
}

void StickyNoteWindow::DrawFontMenu(Gdiplus::Graphics& g) {
    // Calculate menu position (below the font size button)
    float buttonX = (float)(kWindowWidth - kPadding - kButtonSize * 3 - 8);
    float menuX = buttonX - 40;  // Offset to center menu
    float menuY = (float)kHeaderHeight + 4;
    float menuWidth = 100;
    float menuHeight = (float)(kFontSizeCount * kFontMenuItemHeight + 8);

    // Draw menu background with shadow
    Gdiplus::SolidBrush shadowBrush(Gdiplus::Color(40, 0, 0, 0));
    Gdiplus::RectF shadowRect(menuX + 2, menuY + 2, menuWidth, menuHeight);
    g.FillRectangle(&shadowBrush, shadowRect);

    // Menu background
    Gdiplus::SolidBrush bgBrush(Gdiplus::Color(255, 255, 255, 255));
    Gdiplus::RectF menuRect(menuX, menuY, menuWidth, menuHeight);
    g.FillRectangle(&bgBrush, menuRect);

    // Menu border
    Gdiplus::Pen borderPen(Gdiplus::Color(60, 0, 0, 0), 1);
    g.DrawRectangle(&borderPen, menuRect);

    // Draw menu items
    Gdiplus::FontFamily fontFamily(L"Microsoft YaHei");
    Gdiplus::Font menuFont(&fontFamily, 13.0f, Gdiplus::FontStyleRegular, Gdiplus::UnitPixel);
    Gdiplus::StringFormat sf;
    sf.SetAlignment(Gdiplus::StringAlignmentNear);
    sf.SetLineAlignment(Gdiplus::StringAlignmentCenter);

    for (int i = 0; i < kFontSizeCount; i++) {
        float itemY = menuY + 4 + i * kFontMenuItemHeight;
        Gdiplus::RectF itemRect(menuX + 4, itemY, menuWidth - 8, (float)kFontMenuItemHeight);

        // Hover highlight
        if (hovered_font_item_ == i) {
            Gdiplus::SolidBrush hoverBrush(Gdiplus::Color(30, 0, 0, 0));
            g.FillRectangle(&hoverBrush, itemRect);
        }

        // Checkmark for selected item
        if (i == current_font_size_index_) {
            Gdiplus::SolidBrush checkBrush(Gdiplus::Color(255, 245, 166, 35));
            Gdiplus::PointF checkPos(menuX + 8, itemY + kFontMenuItemHeight / 2 - 6);
            Gdiplus::Font checkFont(&fontFamily, 12.0f, Gdiplus::FontStyleBold, Gdiplus::UnitPixel);
            g.DrawString(L"\x2713", -1, &checkFont, checkPos, &checkBrush);
        }

        // Item text
        Gdiplus::SolidBrush textBrush(Gdiplus::Color(220, 50, 50, 50));
        Gdiplus::RectF textRect(menuX + 26, itemY, menuWidth - 30, (float)kFontMenuItemHeight);
        g.DrawString(kFontSizeLabels[i], -1, &menuFont, textRect, &sf, &textBrush);

        // Sample size indicator (shows actual font size)
        Gdiplus::SolidBrush sizeBrush(Gdiplus::Color(150, 100, 100, 100));
        wchar_t sizeText[16];
        swprintf(sizeText, 16, L"%.0f", kTaskFontSizes[i]);
        Gdiplus::RectF sizeRect(menuX + 60, itemY, 36, (float)kFontMenuItemHeight);
        sf.SetAlignment(Gdiplus::StringAlignmentFar);
        g.DrawString(sizeText, -1, &menuFont, sizeRect, &sf, &sizeBrush);
        sf.SetAlignment(Gdiplus::StringAlignmentNear);
    }
}

int StickyNoteWindow::HitTestFontMenu(int x, int y) {
    if (!font_menu_visible_) return -1;

    float buttonX = (float)(kWindowWidth - kPadding - kButtonSize * 3 - 8);
    float menuX = buttonX - 40;
    float menuY = (float)kHeaderHeight + 4;
    float menuWidth = 100;

    if (x < menuX || x > menuX + menuWidth) return -1;
    if (y < menuY + 4) return -1;

    int itemIndex = (int)((y - menuY - 4) / kFontMenuItemHeight);
    if (itemIndex >= 0 && itemIndex < kFontSizeCount) {
        return itemIndex;
    }
    return -1;
}

void StickyNoteWindow::UpdateFonts() {
    Gdiplus::FontFamily fontFamily(L"Microsoft YaHei");
    title_font_ = std::make_unique<Gdiplus::Font>(
        &fontFamily,
        kTitleFontSizes[current_font_size_index_],
        Gdiplus::FontStyleBold,
        Gdiplus::UnitPixel
    );
    task_font_ = std::make_unique<Gdiplus::Font>(
        &fontFamily,
        kTaskFontSizes[current_font_size_index_],
        Gdiplus::FontStyleRegular,
        Gdiplus::UnitPixel
    );
}

void StickyNoteWindow::SelectColor(int colorIndex) {
    if (colorIndex >= 0 && colorIndex < kThemeColorCount) {
        SetThemeColor(ArgbToColorRef(kThemeColors[colorIndex]));
        color_picker_visible_ = false;
        InvalidateRect(window_handle_, nullptr, FALSE);
    }
}

void StickyNoteWindow::ToggleTask(int taskIndex) {
    int totalActive = (int)active_tasks_.size();

    if (taskIndex < totalActive) {
        // Toggle active task -> completed
        TaskItem task = active_tasks_[taskIndex];
        task.isCompleted = true;
        active_tasks_.erase(active_tasks_.begin() + taskIndex);
        completed_tasks_.push_back(task);

        if (onTaskToggled) {
            onTaskToggled(task.id, true);
        }
    } else {
        // Toggle completed task -> active
        int completedIndex = taskIndex - totalActive;
        if (completedIndex >= 0 && completedIndex < (int)completed_tasks_.size()) {
            TaskItem task = completed_tasks_[completedIndex];
            task.isCompleted = false;
            completed_tasks_.erase(completed_tasks_.begin() + completedIndex);
            active_tasks_.push_back(task);

            if (onTaskToggled) {
                onTaskToggled(task.id, false);
            }
        }
    }

    UpdateScrollBounds();
    InvalidateRect(window_handle_, nullptr, FALSE);
}
