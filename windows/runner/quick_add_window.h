#ifndef RUNNER_QUICK_ADD_WINDOW_H_
#define RUNNER_QUICK_ADD_WINDOW_H_

#include <windows.h>
#include <string>
#include <functional>

#include "native_window_manager.h"

/// 闪念胶囊窗口 (Windows)
///
/// 全局快捷键唤起的快速任务输入窗口，类似 macOS Spotlight。
/// 窗口特性：
/// - 无边框、圆角、阴影
/// - 居中显示在屏幕上方
/// - 输入完成后自动消失
/// - ESC 键取消
///
/// 设计理念：
/// - 轻量级：仅包含输入框、日期选择、确认按钮
/// - 快速：全局热键唤起，输入完成即消失
/// - 专注：不打断用户当前工作流
class QuickAddWindow : public NativeWindowBase {
public:
    /// 构造函数
    /// @param windowId 窗口实例 ID（可选）
    /// @param arguments 初始参数
    QuickAddWindow(const std::wstring& windowId, const flutter::EncodableMap* arguments);

    virtual ~QuickAddWindow();

    // ===== NativeWindowBase 接口实现 =====

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
    // ===== 窗口过程 =====

    /// 静态窗口过程
    static LRESULT CALLBACK WindowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);

    /// 实例窗口消息处理
    LRESULT HandleMessage(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);

    /// 注册窗口类
    static bool RegisterWindowClass();

    // ===== 创建和布局 =====

    /// 创建窗口
    bool CreateWindow();

    /// 创建控件
    void CreateControls();

    /// 布局控件
    void LayoutControls();

    // ===== 事件处理 =====

    /// 处理绘制
    void OnPaint();

    /// 处理命令
    void OnCommand(WORD id, WORD code);

    /// 处理键盘
    void OnKeyDown(WPARAM key);

    /// 输入框子类化过程（拦截 Enter/ESC）
    static LRESULT CALLBACK EditSubclassProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam);

    /// 提交任务
    void SubmitTask();

    /// 取消输入
    void CancelInput();

    /// 请求日期选择
    void RequestDatePicker();

    // ===== 辅助函数 =====

    /// 格式化日期
    std::wstring FormatDate(double timestamp);

    /// 获取输入框文本
    std::wstring GetInputText();

    /// 清空输入框
    void ClearInput();

    /// 聚焦输入框
    void FocusInput();

    /// 更新占位符文本
    void UpdatePlaceholder();

    // ===== 成员变量 =====

    /// 窗口 ID
    std::wstring window_id_;

    /// 当前选中的日期（毫秒时间戳）
    double selected_date_ms_ = 0;

    /// 窗口句柄
    HWND window_handle_ = nullptr;

    /// 输入框句柄
    HWND edit_handle_ = nullptr;

    /// 日期按钮句柄
    HWND date_button_ = nullptr;

    /// 提交按钮句柄
    HWND submit_button_ = nullptr;

    /// Logo 图片句柄
    HBITMAP logo_bitmap_ = nullptr;

    /// 背景画刷
    HBRUSH bg_brush_ = nullptr;

    /// 自定义字体
    HFONT edit_font_ = nullptr;

    /// 输入框原始窗口过程（子类化前保存）
    WNDPROC original_edit_proc_ = nullptr;

    /// 窗口类名
    static const wchar_t* kWindowClassName;
    static bool class_registered_;

    /// 控件 ID
    static const int ID_EDIT = 1001;
    static const int ID_DATE_BTN = 1002;
    static const int ID_SUBMIT_BTN = 1003;

    /// 窗口尺寸
    static const int kWindowWidth = 600;
    static const int kWindowHeight = 60;
    static const int kCornerRadius = 12;
};

#endif  // RUNNER_QUICK_ADD_WINDOW_H_
