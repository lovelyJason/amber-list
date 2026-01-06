#ifndef RUNNER_QUICK_ADD_WINDOW_H_
#define RUNNER_QUICK_ADD_WINDOW_H_

#include <windows.h>
#include <gdiplus.h>
#include <string>
#include <vector>
#include <functional>
#include <memory>

#include "native_window_manager.h"
#include "date_picker_popup.h"

#pragma comment(lib, "gdiplus.lib")
#pragma comment(lib, "msimg32.lib")

/// Quick Add Window (Windows) - Win32 Native Controls Version
///
/// A modern, Spotlight-like quick task input window using Win32 native controls
/// with GDI+ for logo rendering and owner-draw for control styling.
///
/// Architecture:
/// - Main window: WS_POPUP borderless window with DWM rounded corners
/// - Logo: GDI+ loads PNG from embedded resource, draws with alpha blending
/// - Input: Win32 EDIT control with owner-draw background (full IME support)
/// - Button: Owner-draw button with rounded corners and amber color
///
/// Features:
/// - White background matching macOS design
/// - Amber logo loaded from embedded PNG resource
/// - Chinese placeholder text with medium font weight
/// - Tab key to expand to detailed mode
/// - Enter to submit, ESC to cancel
///
/// Design matches macOS QuickAddWindow.swift implementation.
class QuickAddWindow : public NativeWindowBase {
public:
    QuickAddWindow(const std::wstring& windowId, const flutter::EncodableMap* arguments);
    virtual ~QuickAddWindow();

    // NativeWindowBase interface
    std::string GetWindowType() const override { return "quick_add"; }
    std::wstring GetWindowId() const override { return window_id_; }

    void Show(const flutter::EncodableMap* arguments) override;
    void Hide() override;
    void Destroy() override;

    void HandleFlutterMessage(
        const std::string& method,
        const flutter::EncodableValue* arguments,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) override;

private:
    // Window procedure
    static LRESULT CALLBACK WindowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);
    LRESULT HandleMessage(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);
    static bool RegisterWindowClass();

    // Edit control subclass (for Enter/ESC/Tab handling)
    static LRESULT CALLBACK EditSubclassProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam,
                                              UINT_PTR subclassId, DWORD_PTR refData);

    // Window creation
    bool InitWindow();
    void CreateCompactControls();
    void CreateExpandedControls();
    void DestroyExpandedControls();

    // GDI+ logo loading
    bool LoadLogoFromResource();
    void DrawLogo(HDC hdc, int x, int y, int size);

    // Owner-draw painting
    void OnPaint();
    void PaintBackground(HDC hdc);
    void PaintLogo(HDC hdc);
    LRESULT OnCtlColorEdit(HDC hdc, HWND hwndEdit);
    void OnDrawItem(DRAWITEMSTRUCT* dis);
    void DrawRoundedButton(HDC hdc, RECT rect, const std::wstring& text, bool isAmber, bool isHovered, int iconType = 0, int highlightColor = 0);

    // Mode switching
    void ExpandToDetailMode();
    void CollapseToCompactMode();
    void ResizeWindow(int newHeight, bool animate = true);

    // Actions
    void SubmitTask();
    void CancelInput();

    // Menu handling (expanded mode)
    void ShowDateMenu();
    void ShowDatePicker();         // Show custom date picker popup
    void ShowPriorityMenu();
    void ShowTagMenu();
    void ShowListSelectorMenu();   // Inbox and task lists (bottom selector button)
    void OnMenuCommand(int id);

    // Helpers
    std::wstring FormatDateShort(double timestamp);
    void UpdatePlaceholderText();
    void UpdateListSelectorText();
    void UpdateListButtonText();   // Update toolbar list/note button
    void UpdateDateButtonText();
    void UpdatePriorityButtonText();
    void UpdateTagButtonText();
    int CalculateButtonWidth(HWND button);  // Calculate button width based on text + icon
    void RelayoutToolbarButtons();          // Re-layout toolbar buttons with dynamic widths

    // Member variables
    std::wstring window_id_;
    HWND window_handle_ = nullptr;
    float dpi_scale_ = 1.0f;  // DPI scaling factor

    // GDI+ resources
    ULONG_PTR gdiplus_token_ = 0;
    std::unique_ptr<Gdiplus::Bitmap> logo_bitmap_;

    // Compact mode controls
    HWND edit_control_ = nullptr;
    HWND submit_button_ = nullptr;
    std::wstring placeholder_text_;  // Placeholder text for compact mode input

    // Expanded mode controls
    HWND title_label_ = nullptr;
    HWND content_edit_ = nullptr;
    HWND list_button_ = nullptr;
    HWND tag_button_ = nullptr;
    HWND date_button_ = nullptr;
    HWND priority_button_ = nullptr;
    HWND list_selector_button_ = nullptr;
    HWND cancel_button_ = nullptr;
    HWND confirm_button_ = nullptr;

    // Fonts
    HFONT main_font_ = nullptr;
    HFONT title_font_ = nullptr;
    HFONT button_font_ = nullptr;
    HFONT placeholder_font_ = nullptr;

    // Brushes for owner-draw
    HBRUSH white_brush_ = nullptr;
    HBRUSH amber_brush_ = nullptr;
    HBRUSH gray_brush_ = nullptr;

    // Mode and data
    bool is_expanded_ = false;
    bool is_note_mode_ = false;
    double selected_date_ms_ = 0;
    bool has_selected_date_ = false;
    int selected_priority_ = 0;
    std::vector<std::wstring> selected_tags_;
    std::vector<std::wstring> available_tags_;
    std::vector<std::pair<std::wstring, std::wstring>> available_task_lists_;
    std::wstring selected_list_id_;
    std::wstring selected_list_name_ = L"Inbox";

    // Button hover state
    HWND hovered_button_ = nullptr;

    // Date picker popup state (ignore WM_ACTIVATE when open to prevent window close)
    bool is_showing_date_picker_ = false;

    // Custom date picker popup
    std::unique_ptr<DatePickerPopup> date_picker_popup_;

    // Static members
    static const wchar_t* kWindowClassName;
    static bool class_registered_;

    // Dimensions (matching macOS)
    static const int kWindowWidth = 600;
    static const int kCompactHeight = 60;
    static const int kExpandedHeight = 280;
    static const int kCornerRadius = 12;
    static const int kLogoSize = 32;
    static const int kPadding = 16;

    // Control IDs
    static const int ID_EDIT = 1001;
    static const int ID_SUBMIT_BUTTON = 1002;
    static const int ID_CONTENT_EDIT = 1003;
    static const int ID_LIST_BUTTON = 1004;
    static const int ID_TAG_BUTTON = 1005;
    static const int ID_DATE_BUTTON = 1006;
    static const int ID_PRIORITY_BUTTON = 1007;
    static const int ID_LIST_SELECTOR = 1008;
    static const int ID_CANCEL_BUTTON = 1009;
    static const int ID_CONFIRM_BUTTON = 1010;

    // Menu IDs
    static const int ID_MENU_TODAY = 2001;
    static const int ID_MENU_TOMORROW = 2002;
    static const int ID_MENU_DAY_AFTER = 2003;    // Day after tomorrow
    static const int ID_MENU_NEXT_WEEK = 2004;
    static const int ID_MENU_SELECT_DATE = 2005;  // Select date...
    static const int ID_MENU_CLEAR_DATE = 2006;
    static const int ID_MENU_PRIORITY_NONE = 2010;
    static const int ID_MENU_PRIORITY_LOW = 2011;
    static const int ID_MENU_PRIORITY_MEDIUM = 2012;
    static const int ID_MENU_PRIORITY_HIGH = 2013;
    static const int ID_MENU_MODE_TASK = 2020;
    static const int ID_MENU_MODE_NOTE = 2021;
    static const int ID_MENU_TAG_BASE = 2100;
    static const int ID_MENU_TAG_CLEAR = 2199;
    static const int ID_MENU_LIST_INBOX = 2200;
    static const int ID_MENU_LIST_BASE = 2201;

    // Colors (RGB)
    static const COLORREF kAmberColor = RGB(245, 166, 35);   // #F5A623
    static const COLORREF kWhiteColor = RGB(255, 255, 255);
    static const COLORREF kBlackColor = RGB(0, 0, 0);
    static const COLORREF kGrayColor = RGB(128, 128, 128);
    static const COLORREF kLightGrayColor = RGB(230, 230, 230);
    static const COLORREF kPlaceholderColor = RGB(160, 160, 160);
    static const COLORREF kGreenColor = RGB(76, 175, 80);
    static const COLORREF kOrangeColor = RGB(255, 152, 0);
    static const COLORREF kRedColor = RGB(244, 67, 54);
};

#endif  // RUNNER_QUICK_ADD_WINDOW_H_
