#ifndef RUNNER_STICKY_NOTE_WINDOW_H_
#define RUNNER_STICKY_NOTE_WINDOW_H_

#include <windows.h>
#include <gdiplus.h>
#include <commctrl.h>
#include <string>
#include <vector>
#include <map>
#include <functional>
#include <memory>

#pragma comment(lib, "gdiplus.lib")

// Task item data structure
struct TaskItem {
    std::wstring id;
    std::wstring title;
    bool isCompleted;
};

/// Native sticky note window class
/// Redesigned to match macOS implementation:
/// - Borderless window with rounded corners and shadow
/// - Custom header with icon buttons (color picker, pin, close)
/// - Task list with checkboxes and strikethrough for completed items
/// - Scrollable content area
class StickyNoteWindow {
public:
    // Constructor
    // @param noteId Unique note identifier
    // @param title Note title
    // @param themeColor Theme color (COLORREF format)
    StickyNoteWindow(const std::wstring& noteId, const std::wstring& title, COLORREF themeColor);

    virtual ~StickyNoteWindow();

    // Create and show window
    bool Create();

    // Show window
    void Show();

    // Close window
    void Close();

    // Focus window
    void Focus();

    // Update task list
    void UpdateTasks(const std::vector<TaskItem>& active, const std::vector<TaskItem>& completed);

    // Get window handle
    HWND GetHandle() const { return window_handle_; }

    // Get note ID
    const std::wstring& GetNoteId() const { return note_id_; }

    // Is pinned (always on top)
    bool IsPinned() const { return is_pinned_; }

    // Set pinned state
    void SetPinned(bool pinned);

    // Set theme color
    void SetThemeColor(COLORREF color);

    // ===== Callbacks =====

    // Task status changed callback (taskId, isCompleted)
    std::function<void(const std::wstring&, bool)> onTaskToggled;

    // Window closed callback (noteId)
    std::function<void(const std::wstring&)> onWindowClosed;

protected:
    // Window message handler
    LRESULT HandleMessage(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);

private:
    // Window procedure (static)
    static LRESULT CALLBACK WindowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);

    // Register window class
    static bool RegisterWindowClass();

    // Initialize GDI+
    static void InitGdiPlus();

    // Drawing methods
    void OnPaint();
    void DrawHeader(Gdiplus::Graphics& g, const Gdiplus::RectF& rect);
    void DrawContent(Gdiplus::Graphics& g, const Gdiplus::RectF& rect);
    void DrawTaskItem(Gdiplus::Graphics& g, const TaskItem& task, float y, bool isCompleted);
    void DrawIconButton(Gdiplus::Graphics& g, int buttonId, float x, float y, float size);
    void DrawColorPicker(Gdiplus::Graphics& g, float y);

    // Hit testing for custom buttons
    int HitTestButton(int x, int y);
    int HitTestTask(int y);
    int HitTestColorPicker(int x, int y);

    // Event handlers
    void OnMouseDown(int x, int y);
    void OnMouseUp(int x, int y);
    void OnMouseMove(int x, int y);
    void OnMouseLeave();

    // Actions
    void TogglePin();
    void ToggleColorPicker();
    void SelectColor(int colorIndex);
    void ToggleTask(int taskIndex);

    // Scroll handling
    void OnMouseWheel(int delta);
    void UpdateScrollBounds();

    // ===== Member variables =====

    // Note data
    std::wstring note_id_;
    std::wstring note_title_;
    COLORREF theme_color_;
    bool is_pinned_ = true;

    // Window handle
    HWND window_handle_ = nullptr;

    // Task lists
    std::vector<TaskItem> active_tasks_;
    std::vector<TaskItem> completed_tasks_;

    // UI state
    bool color_picker_visible_ = false;
    int hovered_button_ = -1;        // -1: none, 0: color, 1: pin, 2: close
    int pressed_button_ = -1;
    int hovered_task_ = -1;
    int hovered_color_ = -1;

    // Scroll state
    float scroll_offset_ = 0.0f;
    float max_scroll_ = 0.0f;
    bool is_scrolling_ = false;
    int scroll_start_y_ = 0;
    float scroll_start_offset_ = 0.0f;

    // Layout constants
    static const int kWindowWidth = 320;
    static const int kWindowHeight = 400;
    static const int kCornerRadius = 12;
    static const int kHeaderHeight = 32;
    static const int kTitleHeight = 40;
    static const int kPadding = 16;
    static const int kTaskItemHeight = 32;
    static const int kCheckboxSize = 18;
    static const int kButtonSize = 24;
    static const int kColorDotSize = 16;

    // Button IDs for hit testing
    static const int kButtonColor = 0;
    static const int kButtonPin = 1;
    static const int kButtonClose = 2;

    // Predefined theme colors (ARGB for GDI+)
    static const DWORD kThemeColors[];
    static const int kThemeColorCount = 4;

    // Window class
    static const wchar_t* kWindowClassName;
    static bool class_registered_;

    // GDI+ token
    static ULONG_PTR gdiplus_token_;
    static bool gdiplus_initialized_;

    // Cached fonts
    std::unique_ptr<Gdiplus::Font> header_font_;
    std::unique_ptr<Gdiplus::Font> title_font_;
    std::unique_ptr<Gdiplus::Font> task_font_;
};

#endif  // RUNNER_STICKY_NOTE_WINDOW_H_
