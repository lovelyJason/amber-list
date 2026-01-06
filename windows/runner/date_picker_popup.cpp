#include "date_picker_popup.h"
#include <windowsx.h>
#include <cmath>

#pragma comment(lib, "gdiplus.lib")

// Static member initialization
const wchar_t* DatePickerPopup::kWindowClassName = L"AmberDatePickerPopup";
bool DatePickerPopup::class_registered_ = false;

DatePickerPopup::DatePickerPopup(HWND parentWindow, float dpiScale)
    : parent_window_(parentWindow), dpi_scale_(dpiScale) {
    // Get today's date
    time_t now = std::time(nullptr);
    struct tm tm_info;
    localtime_s(&tm_info, &now);
    today_year_ = tm_info.tm_year + 1900;
    today_month_ = tm_info.tm_mon + 1;
    today_day_ = tm_info.tm_mday;
}

DatePickerPopup::~DatePickerPopup() {
    Hide();
}

bool DatePickerPopup::RegisterWindowClass() {
    if (class_registered_) return true;

    WNDCLASSEXW wcex = {};
    wcex.cbSize = sizeof(WNDCLASSEXW);
    wcex.style = CS_HREDRAW | CS_VREDRAW | CS_DROPSHADOW;
    wcex.lpfnWndProc = WindowProc;
    wcex.cbClsExtra = 0;
    wcex.cbWndExtra = 0;
    wcex.hInstance = GetModuleHandle(nullptr);
    wcex.hIcon = nullptr;
    wcex.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wcex.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    wcex.lpszMenuName = nullptr;
    wcex.lpszClassName = kWindowClassName;
    wcex.hIconSm = nullptr;

    if (!RegisterClassExW(&wcex)) {
        return false;
    }

    class_registered_ = true;
    return true;
}

void DatePickerPopup::Show(int anchorX, int anchorY,
                           int selectedYear, int selectedMonth, int selectedDay,
                           DateSelectedCallback onSelected) {
    // Save parameters
    selected_year_ = selectedYear;
    selected_month_ = selectedMonth;
    selected_day_ = selectedDay;
    display_year_ = selectedYear;
    display_month_ = selectedMonth;
    on_selected_ = onSelected;

    // Reset hover state
    hovered_day_ = 0;
    prev_button_hovered_ = false;
    next_button_hovered_ = false;

    // Register window class
    if (!RegisterWindowClass()) {
        return;
    }

    // Calculate popup size (considering DPI scale)
    int width = static_cast<int>(kPopupWidth * dpi_scale_);
    int height = static_cast<int>(kPopupHeight * dpi_scale_);

    // Calculate popup position (show below anchor point)
    int x = anchorX;
    int y = anchorY;

    // Ensure popup stays on screen
    HMONITOR hMonitor = MonitorFromPoint({anchorX, anchorY}, MONITOR_DEFAULTTONEAREST);
    MONITORINFO mi = {sizeof(mi)};
    if (GetMonitorInfo(hMonitor, &mi)) {
        if (x + width > mi.rcWork.right) {
            x = mi.rcWork.right - width;
        }
        if (y + height > mi.rcWork.bottom) {
            y = anchorY - height - 10;  // Show above anchor
        }
    }

    // Create popup window
    popup_window_ = CreateWindowExW(
        WS_EX_TOOLWINDOW | WS_EX_TOPMOST,
        kWindowClassName,
        L"",
        WS_POPUP,
        x, y, width, height,
        parent_window_,
        nullptr,
        GetModuleHandle(nullptr),
        this);

    if (popup_window_) {
        // Enable rounded corners (Windows 11)
        DWM_WINDOW_CORNER_PREFERENCE corner = DWMWCP_ROUND;
        DwmSetWindowAttribute(popup_window_, DWMWA_WINDOW_CORNER_PREFERENCE,
                              &corner, sizeof(corner));

        ShowWindow(popup_window_, SW_SHOWNA);
        UpdateWindow(popup_window_);
    }
}

void DatePickerPopup::Hide() {
    if (popup_window_) {
        DestroyWindow(popup_window_);
        popup_window_ = nullptr;
    }
    on_selected_ = nullptr;
}

LRESULT CALLBACK DatePickerPopup::WindowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
    DatePickerPopup* self = nullptr;

    if (message == WM_NCCREATE) {
        CREATESTRUCTW* cs = reinterpret_cast<CREATESTRUCTW*>(lparam);
        self = static_cast<DatePickerPopup*>(cs->lpCreateParams);
        SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
    } else {
        self = reinterpret_cast<DatePickerPopup*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
    }

    if (self) {
        return self->HandleMessage(hwnd, message, wparam, lparam);
    }

    return DefWindowProc(hwnd, message, wparam, lparam);
}

LRESULT DatePickerPopup::HandleMessage(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
    switch (message) {
        case WM_PAINT:
            OnPaint();
            return 0;

        case WM_MOUSEMOVE:
            OnMouseMove(GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam));
            return 0;

        case WM_LBUTTONDOWN:
            OnMouseClick(GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam));
            return 0;

        case WM_ACTIVATE:
            if (LOWORD(wparam) == WA_INACTIVE) {
                Hide();
            }
            return 0;

        case WM_KEYDOWN:
            if (wparam == VK_ESCAPE) {
                Hide();
            }
            return 0;

        case WM_ERASEBKGND:
            return 1;  // Prevent flicker

        default:
            return DefWindowProc(hwnd, message, wparam, lparam);
    }
}

void DatePickerPopup::OnPaint() {
    PAINTSTRUCT ps;
    HDC hdc = BeginPaint(popup_window_, &ps);

    RECT clientRect;
    GetClientRect(popup_window_, &clientRect);

    // Create double buffer
    HDC memDC = CreateCompatibleDC(hdc);
    HBITMAP memBitmap = CreateCompatibleBitmap(hdc,
        clientRect.right - clientRect.left,
        clientRect.bottom - clientRect.top);
    HBITMAP oldBitmap = (HBITMAP)SelectObject(memDC, memBitmap);

    // Draw with GDI+
    Gdiplus::Graphics g(memDC);
    g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    g.SetTextRenderingHint(Gdiplus::TextRenderingHintClearTypeGridFit);

    // Draw white background
    Gdiplus::SolidBrush whiteBrush(Gdiplus::Color(255, 255, 255, 255));
    g.FillRectangle(&whiteBrush, 0, 0, clientRect.right, clientRect.bottom);

    // Draw each section
    DrawHeader(g);
    DrawWeekdays(g);
    DrawDays(g);
    DrawFooterButtons(g);

    // Copy to screen
    BitBlt(hdc, 0, 0,
           clientRect.right - clientRect.left,
           clientRect.bottom - clientRect.top,
           memDC, 0, 0, SRCCOPY);

    // Cleanup
    SelectObject(memDC, oldBitmap);
    DeleteObject(memBitmap);
    DeleteDC(memDC);

    EndPaint(popup_window_, &ps);
}

void DatePickerPopup::DrawHeader(Gdiplus::Graphics& g) {
    int padding = static_cast<int>(kPadding * dpi_scale_);
    int headerHeight = static_cast<int>(kHeaderHeight * dpi_scale_);
    int navButtonSize = static_cast<int>(kNavButtonSize * dpi_scale_);
    int popupWidth = static_cast<int>(kPopupWidth * dpi_scale_);

    // Draw month title
    wchar_t titleText[64];
    swprintf_s(titleText, 64, L"%d\x5E74%d\x6708", display_year_, display_month_);

    Gdiplus::FontFamily fontFamily(L"Microsoft YaHei UI");
    Gdiplus::Font titleFont(&fontFamily, 14.0f * dpi_scale_, Gdiplus::FontStyleBold, Gdiplus::UnitPixel);
    Gdiplus::SolidBrush blackBrush(Gdiplus::Color(255, 0, 0, 0));

    Gdiplus::StringFormat sf;
    sf.SetAlignment(Gdiplus::StringAlignmentCenter);
    sf.SetLineAlignment(Gdiplus::StringAlignmentCenter);

    Gdiplus::RectF titleRect(
        static_cast<float>(padding + navButtonSize),
        0,
        static_cast<float>(popupWidth - 2 * padding - 2 * navButtonSize),
        static_cast<float>(headerHeight)
    );
    g.DrawString(titleText, -1, &titleFont, titleRect, &sf, &blackBrush);

    // Draw navigation buttons
    DrawNavigationButton(g, true, prev_button_hovered_);   // Left arrow
    DrawNavigationButton(g, false, next_button_hovered_);  // Right arrow
}

void DatePickerPopup::DrawNavigationButton(Gdiplus::Graphics& g, bool isLeft, bool isHovered) {
    int padding = static_cast<int>(kPadding * dpi_scale_);
    int headerHeight = static_cast<int>(kHeaderHeight * dpi_scale_);
    int navButtonSize = static_cast<int>(kNavButtonSize * dpi_scale_);
    int popupWidth = static_cast<int>(kPopupWidth * dpi_scale_);

    int x = isLeft ? padding : (popupWidth - padding - navButtonSize);
    int y = (headerHeight - navButtonSize) / 2;

    // Hover background
    if (isHovered) {
        Gdiplus::SolidBrush hoverBrush(Gdiplus::Color(255, 240, 240, 240));
        Gdiplus::Rect bgRect(x, y, navButtonSize, navButtonSize);
        int radius = static_cast<int>(6 * dpi_scale_);

        Gdiplus::GraphicsPath path;
        path.AddArc(x, y, radius * 2, radius * 2, 180, 90);
        path.AddArc(x + navButtonSize - radius * 2, y, radius * 2, radius * 2, 270, 90);
        path.AddArc(x + navButtonSize - radius * 2, y + navButtonSize - radius * 2, radius * 2, radius * 2, 0, 90);
        path.AddArc(x, y + navButtonSize - radius * 2, radius * 2, radius * 2, 90, 90);
        path.CloseFigure();
        g.FillPath(&hoverBrush, &path);
    }

    // Draw arrow
    Gdiplus::Pen arrowPen(Gdiplus::Color(255, 100, 100, 100), 2.0f * dpi_scale_);
    arrowPen.SetLineCap(Gdiplus::LineCapRound, Gdiplus::LineCapRound, Gdiplus::DashCapRound);

    int arrowSize = static_cast<int>(6 * dpi_scale_);
    int centerX = x + navButtonSize / 2;
    int centerY = y + navButtonSize / 2;

    if (isLeft) {
        // Left arrow <
        g.DrawLine(&arrowPen,
            centerX + arrowSize / 2, centerY - arrowSize,
            centerX - arrowSize / 2, centerY);
        g.DrawLine(&arrowPen,
            centerX - arrowSize / 2, centerY,
            centerX + arrowSize / 2, centerY + arrowSize);
    } else {
        // Right arrow >
        g.DrawLine(&arrowPen,
            centerX - arrowSize / 2, centerY - arrowSize,
            centerX + arrowSize / 2, centerY);
        g.DrawLine(&arrowPen,
            centerX + arrowSize / 2, centerY,
            centerX - arrowSize / 2, centerY + arrowSize);
    }
}

void DatePickerPopup::DrawWeekdays(Gdiplus::Graphics& g) {
    int padding = static_cast<int>(kPadding * dpi_scale_);
    int headerHeight = static_cast<int>(kHeaderHeight * dpi_scale_);
    int weekdayHeight = static_cast<int>(kWeekdayHeight * dpi_scale_);
    int popupWidth = static_cast<int>(kPopupWidth * dpi_scale_);

    // Weekday names (Mon-Sun in Chinese)
    const wchar_t* weekdays[] = {L"\x4E00", L"\x4E8C", L"\x4E09", L"\x56DB", L"\x4E94", L"\x516D", L"\x65E5"};

    Gdiplus::FontFamily fontFamily(L"Microsoft YaHei UI");
    Gdiplus::Font weekdayFont(&fontFamily, 12.0f * dpi_scale_, Gdiplus::FontStyleRegular, Gdiplus::UnitPixel);
    Gdiplus::SolidBrush grayBrush(Gdiplus::Color(255, 128, 128, 128));

    Gdiplus::StringFormat sf;
    sf.SetAlignment(Gdiplus::StringAlignmentCenter);
    sf.SetLineAlignment(Gdiplus::StringAlignmentCenter);

    int gridWidth = popupWidth - 2 * padding;
    int cellWidth = gridWidth / 7;
    int startX = padding + (gridWidth - cellWidth * 7) / 2;

    for (int i = 0; i < 7; i++) {
        Gdiplus::RectF rect(
            static_cast<float>(startX + i * cellWidth),
            static_cast<float>(headerHeight),
            static_cast<float>(cellWidth),
            static_cast<float>(weekdayHeight)
        );
        g.DrawString(weekdays[i], -1, &weekdayFont, rect, &sf, &grayBrush);
    }
}

void DatePickerPopup::DrawDays(Gdiplus::Graphics& g) {
    int padding = static_cast<int>(kPadding * dpi_scale_);
    int headerHeight = static_cast<int>(kHeaderHeight * dpi_scale_);
    int weekdayHeight = static_cast<int>(kWeekdayHeight * dpi_scale_);
    int cellSize = static_cast<int>(kDayCellSize * dpi_scale_);
    int popupWidth = static_cast<int>(kPopupWidth * dpi_scale_);

    int daysInMonth = GetDaysInMonth(display_year_, display_month_);
    int firstDayOfWeek = GetFirstDayOfWeek(display_year_, display_month_);

    // Adjust: make Monday the first day (0)
    // GetFirstDayOfWeek returns 0=Sunday, 1=Monday, ... 6=Saturday
    // We need to convert to 0=Monday, 1=Tuesday, ... 6=Sunday
    int startOffset = (firstDayOfWeek + 6) % 7;

    Gdiplus::FontFamily fontFamily(L"Microsoft YaHei UI");
    Gdiplus::Font dayFont(&fontFamily, 13.0f * dpi_scale_, Gdiplus::FontStyleRegular, Gdiplus::UnitPixel);

    Gdiplus::StringFormat sf;
    sf.SetAlignment(Gdiplus::StringAlignmentCenter);
    sf.SetLineAlignment(Gdiplus::StringAlignmentCenter);

    int gridWidth = popupWidth - 2 * padding;
    int cellWidth = gridWidth / 7;
    int startX = padding + (gridWidth - cellWidth * 7) / 2;
    int startY = headerHeight + weekdayHeight;

    for (int day = 1; day <= daysInMonth; day++) {
        int index = startOffset + day - 1;
        int row = index / 7;
        int col = index % 7;

        int x = startX + col * cellWidth;
        int y = startY + row * cellSize;

        // Check state
        bool isSelected = (display_year_ == selected_year_ &&
                          display_month_ == selected_month_ &&
                          day == selected_day_);
        bool isToday = (display_year_ == today_year_ &&
                       display_month_ == today_month_ &&
                       day == today_day_);
        bool isHovered = (day == hovered_day_);

        // Calculate center and radius
        int centerX = x + cellWidth / 2;
        int centerY = y + cellSize / 2;
        int radius = static_cast<int>(16 * dpi_scale_);

        // Draw background
        if (isSelected) {
            // Selected date: amber circle background
            Gdiplus::SolidBrush amberBrush(Gdiplus::Color(255, 245, 166, 35));
            g.FillEllipse(&amberBrush,
                centerX - radius, centerY - radius,
                radius * 2, radius * 2);
        } else if (isHovered) {
            // Hovered date: light gray circle background
            Gdiplus::SolidBrush hoverBrush(Gdiplus::Color(255, 240, 240, 240));
            g.FillEllipse(&hoverBrush,
                centerX - radius, centerY - radius,
                radius * 2, radius * 2);
        }

        // Today's date: draw circle border
        if (isToday && !isSelected) {
            Gdiplus::Pen todayPen(Gdiplus::Color(255, 200, 200, 200), 1.5f * dpi_scale_);
            g.DrawEllipse(&todayPen,
                centerX - radius, centerY - radius,
                radius * 2, radius * 2);
        }

        // Draw day number
        wchar_t dayText[4];
        swprintf_s(dayText, 4, L"%d", day);

        Gdiplus::Color textColor;
        if (isSelected) {
            textColor = Gdiplus::Color(255, 255, 255, 255);  // White when selected
        } else {
            textColor = Gdiplus::Color(255, 0, 0, 0);  // Normal black
        }
        Gdiplus::SolidBrush textBrush(textColor);

        Gdiplus::RectF rect(
            static_cast<float>(x),
            static_cast<float>(y),
            static_cast<float>(cellWidth),
            static_cast<float>(cellSize)
        );
        g.DrawString(dayText, -1, &dayFont, rect, &sf, &textBrush);
    }
}

void DatePickerPopup::OnMouseMove(int x, int y) {
    bool needsRepaint = false;

    // Detect navigation button hover
    bool prevHovered = HitTestPrevButton(x, y);
    bool nextHovered = HitTestNextButton(x, y);

    if (prevHovered != prev_button_hovered_) {
        prev_button_hovered_ = prevHovered;
        needsRepaint = true;
    }
    if (nextHovered != next_button_hovered_) {
        next_button_hovered_ = nextHovered;
        needsRepaint = true;
    }

    // Detect footer button hover
    bool cancelHovered = HitTestCancelButton(x, y);
    bool confirmHovered = HitTestConfirmButton(x, y);

    if (cancelHovered != cancel_button_hovered_) {
        cancel_button_hovered_ = cancelHovered;
        needsRepaint = true;
    }
    if (confirmHovered != confirm_button_hovered_) {
        confirm_button_hovered_ = confirmHovered;
        needsRepaint = true;
    }

    // Detect day hover
    int hoveredDay = HitTestDay(x, y);
    if (hoveredDay != hovered_day_) {
        hovered_day_ = hoveredDay;
        needsRepaint = true;
    }

    if (needsRepaint) {
        InvalidateRect(popup_window_, nullptr, FALSE);
    }

    // Enable mouse tracking (to detect mouse leave)
    TRACKMOUSEEVENT tme = {};
    tme.cbSize = sizeof(tme);
    tme.dwFlags = TME_LEAVE;
    tme.hwndTrack = popup_window_;
    TrackMouseEvent(&tme);
}

void DatePickerPopup::OnMouseClick(int x, int y) {
    // Detect navigation button click
    if (HitTestPrevButton(x, y)) {
        NavigateToPrevMonth();
        return;
    }
    if (HitTestNextButton(x, y)) {
        NavigateToNextMonth();
        return;
    }

    // Detect cancel button click
    if (HitTestCancelButton(x, y)) {
        Hide();
        return;
    }

    // Detect confirm button click
    if (HitTestConfirmButton(x, y)) {
        // Call callback with selected date
        if (on_selected_) {
            on_selected_(selected_year_, selected_month_, selected_day_);
        }
        Hide();
        return;
    }

    // Detect day click - just select, don't close
    int clickedDay = HitTestDay(x, y);
    if (clickedDay > 0) {
        // Update selected date
        selected_year_ = display_year_;
        selected_month_ = display_month_;
        selected_day_ = clickedDay;
        // Repaint to show selection
        InvalidateRect(popup_window_, nullptr, FALSE);
    }
}

int DatePickerPopup::HitTestDay(int x, int y) {
    int padding = static_cast<int>(kPadding * dpi_scale_);
    int headerHeight = static_cast<int>(kHeaderHeight * dpi_scale_);
    int weekdayHeight = static_cast<int>(kWeekdayHeight * dpi_scale_);
    int cellSize = static_cast<int>(kDayCellSize * dpi_scale_);
    int popupWidth = static_cast<int>(kPopupWidth * dpi_scale_);

    int gridWidth = popupWidth - 2 * padding;
    int cellWidth = gridWidth / 7;
    int startX = padding + (gridWidth - cellWidth * 7) / 2;
    int startY = headerHeight + weekdayHeight;

    // Check if within date grid area
    if (x < startX || y < startY) return 0;

    int col = (x - startX) / cellWidth;
    int row = (y - startY) / cellSize;

    if (col < 0 || col >= 7 || row < 0 || row >= 6) return 0;

    int daysInMonth = GetDaysInMonth(display_year_, display_month_);
    int firstDayOfWeek = GetFirstDayOfWeek(display_year_, display_month_);
    int startOffset = (firstDayOfWeek + 6) % 7;

    int index = row * 7 + col;
    int day = index - startOffset + 1;

    if (day < 1 || day > daysInMonth) return 0;

    return day;
}

bool DatePickerPopup::HitTestPrevButton(int x, int y) {
    int padding = static_cast<int>(kPadding * dpi_scale_);
    int headerHeight = static_cast<int>(kHeaderHeight * dpi_scale_);
    int navButtonSize = static_cast<int>(kNavButtonSize * dpi_scale_);

    int btnX = padding;
    int btnY = (headerHeight - navButtonSize) / 2;

    return (x >= btnX && x <= btnX + navButtonSize &&
            y >= btnY && y <= btnY + navButtonSize);
}

bool DatePickerPopup::HitTestNextButton(int x, int y) {
    int padding = static_cast<int>(kPadding * dpi_scale_);
    int headerHeight = static_cast<int>(kHeaderHeight * dpi_scale_);
    int navButtonSize = static_cast<int>(kNavButtonSize * dpi_scale_);
    int popupWidth = static_cast<int>(kPopupWidth * dpi_scale_);

    int btnX = popupWidth - padding - navButtonSize;
    int btnY = (headerHeight - navButtonSize) / 2;

    return (x >= btnX && x <= btnX + navButtonSize &&
            y >= btnY && y <= btnY + navButtonSize);
}

void DatePickerPopup::NavigateToPrevMonth() {
    display_month_--;
    if (display_month_ < 1) {
        display_month_ = 12;
        display_year_--;
    }
    hovered_day_ = 0;
    InvalidateRect(popup_window_, nullptr, FALSE);
}

void DatePickerPopup::NavigateToNextMonth() {
    display_month_++;
    if (display_month_ > 12) {
        display_month_ = 1;
        display_year_++;
    }
    hovered_day_ = 0;
    InvalidateRect(popup_window_, nullptr, FALSE);
}

int DatePickerPopup::GetDaysInMonth(int year, int month) {
    static const int daysPerMonth[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};

    if (month < 1 || month > 12) return 30;

    int days = daysPerMonth[month - 1];

    // Leap year February
    if (month == 2) {
        bool isLeapYear = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
        if (isLeapYear) days = 29;
    }

    return days;
}

int DatePickerPopup::GetFirstDayOfWeek(int year, int month) {
    // Use Zeller's formula to calculate which day of week the 1st falls on
    // Returns 0=Sunday, 1=Monday, ..., 6=Saturday
    if (month < 3) {
        month += 12;
        year--;
    }

    int q = 1;  // First day of month
    int m = month;
    int k = year % 100;
    int j = year / 100;

    int h = (q + (13 * (m + 1)) / 5 + k + k / 4 + j / 4 - 2 * j) % 7;
    // h: 0=Saturday, 1=Sunday, 2=Monday, ..., 6=Friday
    // Convert to 0=Sunday, 1=Monday, ..., 6=Saturday
    int dayOfWeek = ((h + 6) % 7);

    return dayOfWeek;
}

void DatePickerPopup::DrawFooterButtons(Gdiplus::Graphics& g) {
    int padding = static_cast<int>(kPadding * dpi_scale_);
    int footerHeight = static_cast<int>(kFooterHeight * dpi_scale_);
    int buttonWidth = static_cast<int>(kFooterButtonWidth * dpi_scale_);
    int buttonHeight = static_cast<int>(kFooterButtonHeight * dpi_scale_);
    int popupWidth = static_cast<int>(kPopupWidth * dpi_scale_);
    int popupHeight = static_cast<int>(kPopupHeight * dpi_scale_);

    // Footer starts after day grid
    int footerY = popupHeight - footerHeight;

    // Draw separator line
    Gdiplus::Pen separatorPen(Gdiplus::Color(255, 230, 230, 230), 1.0f);
    g.DrawLine(&separatorPen, padding, footerY, popupWidth - padding, footerY);

    // Button Y position (centered in footer)
    int btnY = footerY + (footerHeight - buttonHeight) / 2;

    // Cancel button (left side)
    int cancelX = padding + 10;
    bool cancelHovered = cancel_button_hovered_;

    // Confirm button (right side)
    int confirmX = popupWidth - padding - buttonWidth - 10;
    bool confirmHovered = confirm_button_hovered_;

    Gdiplus::FontFamily fontFamily(L"Microsoft YaHei UI");
    Gdiplus::Font buttonFont(&fontFamily, 13.0f * dpi_scale_, Gdiplus::FontStyleRegular, Gdiplus::UnitPixel);
    Gdiplus::StringFormat sf;
    sf.SetAlignment(Gdiplus::StringAlignmentCenter);
    sf.SetLineAlignment(Gdiplus::StringAlignmentCenter);

    int cornerRadius = static_cast<int>(6 * dpi_scale_);

    // Draw Cancel button
    {
        Gdiplus::GraphicsPath cancelPath;
        cancelPath.AddArc(cancelX, btnY, cornerRadius * 2, cornerRadius * 2, 180, 90);
        cancelPath.AddArc(cancelX + buttonWidth - cornerRadius * 2, btnY, cornerRadius * 2, cornerRadius * 2, 270, 90);
        cancelPath.AddArc(cancelX + buttonWidth - cornerRadius * 2, btnY + buttonHeight - cornerRadius * 2, cornerRadius * 2, cornerRadius * 2, 0, 90);
        cancelPath.AddArc(cancelX, btnY + buttonHeight - cornerRadius * 2, cornerRadius * 2, cornerRadius * 2, 90, 90);
        cancelPath.CloseFigure();

        if (cancelHovered) {
            Gdiplus::SolidBrush hoverBrush(Gdiplus::Color(255, 245, 245, 245));
            g.FillPath(&hoverBrush, &cancelPath);
        }

        Gdiplus::Pen borderPen(Gdiplus::Color(255, 200, 200, 200), 1.0f);
        g.DrawPath(&borderPen, &cancelPath);

        Gdiplus::SolidBrush textBrush(Gdiplus::Color(255, 100, 100, 100));
        Gdiplus::RectF cancelRect(static_cast<float>(cancelX), static_cast<float>(btnY),
                                   static_cast<float>(buttonWidth), static_cast<float>(buttonHeight));
        g.DrawString(L"\x53D6\x6D88", -1, &buttonFont, cancelRect, &sf, &textBrush);  // Cancel in Chinese
    }

    // Draw Confirm button (amber)
    {
        Gdiplus::GraphicsPath confirmPath;
        confirmPath.AddArc(confirmX, btnY, cornerRadius * 2, cornerRadius * 2, 180, 90);
        confirmPath.AddArc(confirmX + buttonWidth - cornerRadius * 2, btnY, cornerRadius * 2, cornerRadius * 2, 270, 90);
        confirmPath.AddArc(confirmX + buttonWidth - cornerRadius * 2, btnY + buttonHeight - cornerRadius * 2, cornerRadius * 2, cornerRadius * 2, 0, 90);
        confirmPath.AddArc(confirmX, btnY + buttonHeight - cornerRadius * 2, cornerRadius * 2, cornerRadius * 2, 90, 90);
        confirmPath.CloseFigure();

        // Amber background (darker when hovered)
        Gdiplus::Color amberColor = confirmHovered ?
            Gdiplus::Color(255, 213, 145, 30) :   // Darker amber on hover
            Gdiplus::Color(255, 245, 166, 35);    // Normal amber
        Gdiplus::SolidBrush amberBrush(amberColor);
        g.FillPath(&amberBrush, &confirmPath);

        Gdiplus::SolidBrush whiteBrush(Gdiplus::Color(255, 255, 255, 255));
        Gdiplus::RectF confirmRect(static_cast<float>(confirmX), static_cast<float>(btnY),
                                    static_cast<float>(buttonWidth), static_cast<float>(buttonHeight));
        g.DrawString(L"\x786E\x5B9A", -1, &buttonFont, confirmRect, &sf, &whiteBrush);  // Confirm in Chinese
    }
}

bool DatePickerPopup::HitTestCancelButton(int x, int y) {
    int padding = static_cast<int>(kPadding * dpi_scale_);
    int footerHeight = static_cast<int>(kFooterHeight * dpi_scale_);
    int buttonWidth = static_cast<int>(kFooterButtonWidth * dpi_scale_);
    int buttonHeight = static_cast<int>(kFooterButtonHeight * dpi_scale_);
    int popupHeight = static_cast<int>(kPopupHeight * dpi_scale_);

    int footerY = popupHeight - footerHeight;
    int btnY = footerY + (footerHeight - buttonHeight) / 2;
    int cancelX = padding + 10;

    return (x >= cancelX && x <= cancelX + buttonWidth &&
            y >= btnY && y <= btnY + buttonHeight);
}

bool DatePickerPopup::HitTestConfirmButton(int x, int y) {
    int padding = static_cast<int>(kPadding * dpi_scale_);
    int footerHeight = static_cast<int>(kFooterHeight * dpi_scale_);
    int buttonWidth = static_cast<int>(kFooterButtonWidth * dpi_scale_);
    int buttonHeight = static_cast<int>(kFooterButtonHeight * dpi_scale_);
    int popupWidth = static_cast<int>(kPopupWidth * dpi_scale_);
    int popupHeight = static_cast<int>(kPopupHeight * dpi_scale_);

    int footerY = popupHeight - footerHeight;
    int btnY = footerY + (footerHeight - buttonHeight) / 2;
    int confirmX = popupWidth - padding - buttonWidth - 10;

    return (x >= confirmX && x <= confirmX + buttonWidth &&
            y >= btnY && y <= btnY + buttonHeight);
}
