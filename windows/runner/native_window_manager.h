#ifndef RUNNER_NATIVE_WINDOW_MANAGER_H_
#define RUNNER_NATIVE_WINDOW_MANAGER_H_

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/flutter_engine.h>

#include <map>
#include <memory>
#include <string>
#include <functional>

// Forward declaration
class NativeWindowBase;

/// 原生窗口管理器 (Windows)
///
/// 统一管理所有原生窗口的生命周期和 Platform Channel 通信。
/// 支持多种窗口类型（QuickAdd、StickyNote 等），通过窗口类型进行消息路由。
///
/// 设计理念：
/// - 单一入口：所有原生窗口操作都通过此管理器
/// - 工厂模式：通过注册的工厂函数创建窗口
/// - 消息路由：根据 windowType 分发 Flutter 消息
class NativeWindowManager {
public:
    /// 窗口工厂函数类型
    /// 参数: windowId, arguments
    /// 返回: 窗口实例
    using WindowFactory = std::function<std::unique_ptr<NativeWindowBase>(
        const std::wstring& windowId,
        const flutter::EncodableMap* arguments)>;

    /// 获取单例实例
    static NativeWindowManager& GetInstance();

    // 禁用拷贝和移动
    NativeWindowManager(const NativeWindowManager&) = delete;
    NativeWindowManager& operator=(const NativeWindowManager&) = delete;

    /// 初始化 Platform Channel
    /// @param engine Flutter 引擎
    void Setup(flutter::FlutterEngine* engine);

    /// 注册窗口工厂
    /// @param windowType 窗口类型标识
    /// @param factory 创建窗口的工厂函数
    void RegisterFactory(const std::string& windowType, WindowFactory factory);

    /// 向 Flutter 发送消息
    /// @param method 方法名
    /// @param arguments 参数
    void NotifyFlutter(const std::string& method, const flutter::EncodableMap& arguments);

    /// 窗口关闭回调（由窗口调用）
    /// @param windowType 窗口类型
    /// @param windowId 窗口 ID（可选）
    void WindowDidClose(const std::string& windowType, const std::wstring& windowId);

    /// 关闭所有窗口
    void CloseAllWindows();

    /// 辅助函数：宽字符串转 UTF-8
    static std::string WStringToUtf8(const std::wstring& wstr);

    /// 辅助函数：UTF-8 转宽字符串
    static std::wstring Utf8ToWString(const std::string& str);

private:
    NativeWindowManager() = default;
    ~NativeWindowManager();

    // ===== Method Channel handlers =====

    /// 处理来自 Flutter 的方法调用
    void HandleMethodCall(
        const flutter::MethodCall<flutter::EncodableValue>& call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    /// 创建或显示窗口
    void HandleCreateOrShow(
        const flutter::EncodableMap& args,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    /// 隐藏窗口
    void HandleHide(
        const flutter::EncodableMap& args,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    /// 销毁窗口
    void HandleDestroy(
        const flutter::EncodableMap& args,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    /// 向窗口发送消息
    void HandleSendMessage(
        const flutter::EncodableMap& args,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    /// 检查窗口是否打开
    void HandleIsWindowOpen(
        const flutter::EncodableMap& args,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    /// 获取所有打开的窗口
    void HandleGetOpenWindows(
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    // ===== Helpers =====

    /// 生成窗口标识符
    std::string MakeIdentifier(const std::string& windowType, const std::wstring& windowId);

    /// 注册内置窗口工厂
    void RegisterBuiltInFactories();

    // ===== Member variables =====

    /// Platform Channel
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> method_channel_;

    /// 所有活跃窗口的注册表
    /// Key: 窗口标识符（windowType 或 windowType_windowId）
    std::map<std::string, std::unique_ptr<NativeWindowBase>> windows_;

    /// 窗口工厂注册表
    /// Key: 窗口类型
    std::map<std::string, WindowFactory> factories_;
};

/// 原生窗口基类
///
/// 所有原生窗口（QuickAdd、StickyNote 等）必须继承此类。
/// 提供统一的窗口生命周期管理接口。
class NativeWindowBase {
public:
    virtual ~NativeWindowBase() = default;

    /// 获取窗口类型标识
    virtual std::string GetWindowType() const = 0;

    /// 获取窗口实例 ID（可选）
    virtual std::wstring GetWindowId() const { return L""; }

    /// 显示窗口
    /// @param arguments 创建/显示参数
    virtual void Show(const flutter::EncodableMap* arguments) = 0;

    /// 隐藏窗口（不销毁）
    virtual void Hide() = 0;

    /// 销毁窗口
    virtual void Destroy() = 0;

    /// 处理来自 Flutter 的消息
    /// @param method 方法名
    /// @param arguments 参数
    /// @param result Flutter 结果回调
    virtual void HandleFlutterMessage(
        const std::string& method,
        const flutter::EncodableValue* arguments,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) = 0;
};

#endif  // RUNNER_NATIVE_WINDOW_MANAGER_H_
