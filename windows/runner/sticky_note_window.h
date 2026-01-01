#ifndef RUNNER_STICKY_NOTE_WINDOW_H_
#define RUNNER_STICKY_NOTE_WINDOW_H_

#include <windows.h>
#include <commctrl.h>
#include <string>
#include <vector>
#include <map>
#include <functional>

/// 任务项数据结构
struct TaskItem {
    std::wstring id;
    std::wstring title;
    bool isCompleted;
};

/// 原生便签窗口类
/// 使用 Win32 API 实现，绕过 Flutter 多窗口的各种 bug
class StickyNoteWindow {
public:
    /// 构造函数
    /// @param noteId 便签唯一标识
    /// @param title 便签标题
    /// @param themeColor 主题色（COLORREF 格式）
    StickyNoteWindow(const std::wstring& noteId, const std::wstring& title, COLORREF themeColor);

    virtual ~StickyNoteWindow();

    /// 创建并显示窗口
    bool Create();

    /// 显示窗口
    void Show();

    /// 关闭窗口
    void Close();

    /// 聚焦窗口
    void Focus();

    /// 更新任务列表
    void UpdateTasks(const std::vector<TaskItem>& active, const std::vector<TaskItem>& completed);

    /// 获取窗口句柄
    HWND GetHandle() const { return window_handle_; }

    /// 获取便签 ID
    const std::wstring& GetNoteId() const { return note_id_; }

    /// 是否置顶
    bool IsPinned() const { return is_pinned_; }

    /// 设置置顶状态
    void SetPinned(bool pinned);

    /// 切换主题色
    void SetThemeColor(COLORREF color);

    // ===== 回调函数 =====

    /// 任务状态变化回调 (taskId, isCompleted)
    std::function<void(const std::wstring&, bool)> onTaskToggled;

    /// 窗口关闭回调 (noteId)
    std::function<void(const std::wstring&)> onWindowClosed;

protected:
    /// 窗口消息处理
    LRESULT HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);

private:
    /// 窗口过程（静态）
    static LRESULT CALLBACK WindowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);

    /// 注册窗口类
    static bool RegisterWindowClass();

    /// 创建控件
    void CreateControls();

    /// 重绘任务列表
    void RebuildTaskList();

    /// 绘制背景
    void OnPaint();

    /// 处理 checkbox 点击
    void OnCheckboxClicked(int checkboxId);

    /// 处理按钮点击
    void OnButtonClicked(int buttonId);

    /// 切换置顶状态
    void TogglePin();

    /// 显示颜色选择器
    void ShowColorPicker();

    /// 隐藏颜色选择器
    void HideColorPicker();

    // ===== 成员变量 =====

    /// 便签 ID
    std::wstring note_id_;

    /// 便签标题
    std::wstring note_title_;

    /// 主题色
    COLORREF theme_color_;

    /// 是否置顶
    bool is_pinned_ = true;

    /// 窗口句柄
    HWND window_handle_ = nullptr;

    /// 头部背景画刷
    HBRUSH header_brush_ = nullptr;

    /// 背景画刷
    HBRUSH bg_brush_ = nullptr;

    /// 任务列表
    std::vector<TaskItem> active_tasks_;
    std::vector<TaskItem> completed_tasks_;

    /// Checkbox ID 到 TaskId 的映射
    std::map<int, std::wstring> checkbox_task_map_;

    /// 控件 ID 计数器
    int next_control_id_ = 100;

    /// 颜色选择器是否显示
    bool color_picker_visible_ = false;

    /// 控件句柄
    HWND title_label_ = nullptr;
    HWND scroll_container_ = nullptr;
    HWND pin_button_ = nullptr;
    HWND color_button_ = nullptr;
    HWND close_button_ = nullptr;

    /// 按钮 ID
    static const int ID_BTN_PIN = 1001;
    static const int ID_BTN_COLOR = 1002;
    static const int ID_BTN_CLOSE = 1003;
    static const int ID_BTN_COLOR_1 = 1011;
    static const int ID_BTN_COLOR_2 = 1012;
    static const int ID_BTN_COLOR_3 = 1013;
    static const int ID_BTN_COLOR_4 = 1014;

    /// 窗口类名
    static const wchar_t* kWindowClassName;
    static bool class_registered_;
};

#endif  // RUNNER_STICKY_NOTE_WINDOW_H_
