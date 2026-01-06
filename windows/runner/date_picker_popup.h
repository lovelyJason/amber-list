#ifndef RUNNER_DATE_PICKER_POPUP_H_
#define RUNNER_DATE_PICKER_POPUP_H_

#include <windows.h>
#include <dwmapi.h>
#include <gdiplus.h>
#include <functional>
#include <ctime>

#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "gdiplus.lib")

/// Custom date picker popup
///
/// A modern calendar control rendered with GDI+, matching macOS design language.
/// Features:
/// - Amber theme for selected date highlighting
/// - Rounded buttons and date cells
/// - Cancel/Confirm buttons at bottom
/// - Month navigation with prev/next buttons
/// - Today's date marked with circle
///
/// Layout:
/// +-----------------------------------+
/// |  <    January 2026    >           |  <- Month navigation bar
/// +-----------------------------------+
/// |  Mon Tue Wed Thu Fri Sat Sun      |  <- Weekday headers
/// +-----------------------------------+
/// |  29  30  31   1   2   3   4       |
/// |   5   6   7   8   9  10  11       |  <- Date grid
/// |  ...                              |
/// +-----------------------------------+
/// |    [Cancel]        [Confirm]      |  <- Action buttons
/// +-----------------------------------+
class DatePickerPopup {
public:
    /// Callback when a date is selected
    using DateSelectedCallback = std::function<void(int year, int month, int day)>;

    /// Constructor
    /// @param parentWindow Parent window handle
    /// @param dpiScale DPI scale factor
    DatePickerPopup(HWND parentWindow, float dpiScale);
    ~DatePickerPopup();

    /// Show the date picker popup
    /// @param anchorX Anchor X coordinate (screen coordinates)
    /// @param anchorY Anchor Y coordinate (screen coordinates)
    /// @param selectedYear Currently selected year
    /// @param selectedMonth Currently selected month (1-12)
    /// @param selectedDay Currently selected day (1-31)
    /// @param onSelected Callback when date is selected
    void Show(int anchorX, int anchorY,
              int selectedYear, int selectedMonth, int selectedDay,
              DateSelectedCallback onSelected);

    /// Hide and destroy the popup
    void Hide();

    /// Check if popup is currently showing
    bool IsShowing() const { return popup_window_ != nullptr; }

private:
    // Window procedure
    static LRESULT CALLBACK WindowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);
    LRESULT HandleMessage(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);

    // Drawing methods
    void OnPaint();
    void DrawHeader(Gdiplus::Graphics& g);
    void DrawWeekdays(Gdiplus::Graphics& g);
    void DrawDays(Gdiplus::Graphics& g);
    void DrawNavigationButton(Gdiplus::Graphics& g, bool isLeft, bool isHovered);
    void DrawFooterButtons(Gdiplus::Graphics& g);

    // Mouse handling
    void OnMouseMove(int x, int y);
    void OnMouseClick(int x, int y);
    int HitTestDay(int x, int y);  // Returns day (1-31) or 0 (no hit)
    bool HitTestPrevButton(int x, int y);
    bool HitTestNextButton(int x, int y);
    bool HitTestCancelButton(int x, int y);
    bool HitTestConfirmButton(int x, int y);

    // Date calculations
    void NavigateToPrevMonth();
    void NavigateToNextMonth();
    int GetDaysInMonth(int year, int month);
    int GetFirstDayOfWeek(int year, int month);  // 0=Sunday, 1=Monday, ...

    // Register window class
    static bool RegisterWindowClass();

    // Member variables
    HWND parent_window_;
    HWND popup_window_ = nullptr;
    float dpi_scale_;

    // Currently displayed month
    int display_year_;
    int display_month_;

    // Selected date
    int selected_year_;
    int selected_month_;
    int selected_day_;

    // Today's date
    int today_year_;
    int today_month_;
    int today_day_;

    // Mouse hover state
    int hovered_day_ = 0;
    bool prev_button_hovered_ = false;
    bool next_button_hovered_ = false;
    bool cancel_button_hovered_ = false;
    bool confirm_button_hovered_ = false;

    // Callback
    DateSelectedCallback on_selected_;

    // Static members
    static const wchar_t* kWindowClassName;
    static bool class_registered_;

    // Size constants (will be scaled by DPI)
    static const int kPopupWidth = 280;
    static const int kPopupHeight = 348;  // Increased for footer buttons
    static const int kHeaderHeight = 44;
    static const int kWeekdayHeight = 28;
    static const int kDayCellSize = 36;
    static const int kPadding = 12;
    static const int kNavButtonSize = 28;
    static const int kFooterHeight = 48;  // Height for cancel/confirm buttons
    static const int kFooterButtonWidth = 80;
    static const int kFooterButtonHeight = 32;

    // Colors
    static const COLORREF kAmberColor = RGB(245, 166, 35);
    static const COLORREF kWhiteColor = RGB(255, 255, 255);
    static const COLORREF kBlackColor = RGB(0, 0, 0);
    static const COLORREF kGrayColor = RGB(128, 128, 128);
    static const COLORREF kLightGrayColor = RGB(240, 240, 240);
    static const COLORREF kTodayBorderColor = RGB(200, 200, 200);
};

#endif  // RUNNER_DATE_PICKER_POPUP_H_
