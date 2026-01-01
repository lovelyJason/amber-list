#ifndef RUNNER_STICKY_NOTE_MANAGER_H_
#define RUNNER_STICKY_NOTE_MANAGER_H_

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/flutter_engine.h>

#include <map>
#include <memory>
#include <string>

#include "sticky_note_window.h"

/// 便签窗口管理器（单例）
/// 负责管理所有原生便签窗口的生命周期
/// 处理 Platform Channel 的消息分发
class StickyNoteManager {
public:
    /// 获取单例实例
    static StickyNoteManager& GetInstance();

    /// 禁止拷贝和移动
    StickyNoteManager(const StickyNoteManager&) = delete;
    StickyNoteManager& operator=(const StickyNoteManager&) = delete;

    /// 初始化 Platform Channel
    /// @param engine Flutter 引擎
    void Setup(flutter::FlutterEngine* engine);

    /// 关闭所有便签窗口
    void CloseAllWindows();

private:
    StickyNoteManager() = default;
    ~StickyNoteManager();

    // ===== Method Channel 处理 =====

    /// 处理来自 Flutter 的方法调用
    void HandleMethodCall(
        const flutter::MethodCall<flutter::EncodableValue>& call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    /// 创建便签窗口
    void HandleCreateStickyNote(
        const flutter::EncodableMap& args,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    /// 关闭便签窗口
    void HandleCloseStickyNote(
        const flutter::EncodableMap& args,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    /// 更新便签内容
    void HandleUpdateStickyNote(
        const flutter::EncodableMap& args,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    /// 聚焦便签窗口
    void HandleFocusStickyNote(
        const flutter::EncodableMap& args,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    /// 检查窗口是否打开
    void HandleIsWindowOpen(
        const flutter::EncodableMap& args,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    // ===== 通知 Flutter =====

    /// 通知 Flutter 任务状态变化
    void NotifyTaskToggled(const std::wstring& taskId, bool isCompleted);

    /// 通知 Flutter 窗口关闭
    void NotifyWindowClosed(const std::wstring& noteId);

    // ===== 辅助函数 =====

    /// 宽字符串转 UTF-8
    static std::string WStringToUtf8(const std::wstring& wstr);

    /// UTF-8 转宽字符串
    static std::wstring Utf8ToWString(const std::string& str);

    /// 解析十六进制颜色字符串为 COLORREF
    static COLORREF ParseColorHex(const std::string& hex);

    /// 解析任务列表
    static std::vector<TaskItem> ParseTaskList(const flutter::EncodableList& list);

    // ===== 成员变量 =====

    /// Platform Channel
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> method_channel_;

    /// 存储所有活跃的便签窗口
    /// Key: noteId (wstring), Value: StickyNoteWindow
    std::map<std::wstring, std::unique_ptr<StickyNoteWindow>> window_controllers_;
};

#endif  // RUNNER_STICKY_NOTE_MANAGER_H_
