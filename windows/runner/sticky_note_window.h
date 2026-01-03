#ifndef RUNNER_STICKY_NOTE_WINDOW_H_
#define RUNNER_STICKY_NOTE_WINDOW_H_

#include <windows.h>
#include <commctrl.h>
#include <string>
#include <vector>
#include <map>
#include <functional>

// Task item data structure
struct TaskItem {
    std::wstring id;
    std::wstring title;
    bool isCompleted;
};

// Native sticky note window class
// Uses Win32 API to bypass Flutter multi-window bugs
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
    LRESULT HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);

private:
    // Window procedure (static)
    static LRESULT CALLBACK WindowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);

    // Register window class
    static bool RegisterWindowClass();

    // Create controls
    void CreateControls();

    // Rebuild task list
    void RebuildTaskList();

    // Paint background
    void OnPaint();

    // Handle checkbox click
    void OnCheckboxClicked(int checkboxId);

    // Handle button click
    void OnButtonClicked(int buttonId);

    // Toggle pin state
    void TogglePin();

    // Show color picker
    void ShowColorPicker();

    // Hide color picker
    void HideColorPicker();

    // ===== Member variables =====

    // Note ID
    std::wstring note_id_;

    // Note title
    std::wstring note_title_;

    // Theme color
    COLORREF theme_color_;

    // Is pinned (always on top)
    bool is_pinned_ = true;

    // Window handle
    HWND window_handle_ = nullptr;

    // Header background brush
    HBRUSH header_brush_ = nullptr;

    // Background brush
    HBRUSH bg_brush_ = nullptr;

    // Task lists
    std::vector<TaskItem> active_tasks_;
    std::vector<TaskItem> completed_tasks_;

    // Checkbox ID to TaskId mapping
    std::map<int, std::wstring> checkbox_task_map_;

    // Control ID counter
    int next_control_id_ = 100;

    // Is color picker visible
    bool color_picker_visible_ = false;

    // Control handles
    HWND title_label_ = nullptr;
    HWND scroll_container_ = nullptr;
    HWND pin_button_ = nullptr;
    HWND color_button_ = nullptr;
    HWND close_button_ = nullptr;

    // Button IDs
    static const int ID_BTN_PIN = 1001;
    static const int ID_BTN_COLOR = 1002;
    static const int ID_BTN_CLOSE = 1003;
    static const int ID_BTN_COLOR_1 = 1011;
    static const int ID_BTN_COLOR_2 = 1012;
    static const int ID_BTN_COLOR_3 = 1013;
    static const int ID_BTN_COLOR_4 = 1014;

    // Window class name
    static const wchar_t* kWindowClassName;
    static bool class_registered_;
};

#endif  // RUNNER_STICKY_NOTE_WINDOW_H_