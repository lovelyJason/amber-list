import Cocoa
import FlutterMacOS

/// 原生窗口管理器
///
/// 统一管理所有原生窗口的生命周期和 Platform Channel 通信。
/// 支持多种窗口类型（QuickAdd、StickyNote 等），通过窗口类型进行消息路由。
///
/// 设计理念：
/// - 单一入口：所有原生窗口操作都通过此管理器
/// - 协议驱动：所有窗口实现 NativeWindowProtocol 协议
/// - 工厂模式：通过注册的工厂函数创建窗口
/// - 消息路由：根据 windowType 分发 Flutter 消息
class NativeWindowManager: NSObject {

    // MARK: - Singleton

    static let shared = NativeWindowManager()

    // MARK: - Properties

    /// 所有活跃窗口的注册表
    /// Key: 窗口标识符（windowType 或 windowType_windowId）
    /// Value: 实现 NativeWindowProtocol 的窗口对象
    private var windows: [String: NativeWindowProtocol] = [:]

    /// 窗口工厂注册表
    /// Key: 窗口类型（如 "quick_add"、"sticky_note"）
    /// Value: 创建窗口的工厂闭包
    private var factories: [String: (String?, [String: Any]?) -> NativeWindowProtocol] = [:]

    /// Platform Channel，用于与 Flutter 通信
    private var methodChannel: FlutterMethodChannel?

    /// Flutter 二进制消息器（用于创建窗口专属 Channel）
    private var binaryMessenger: FlutterBinaryMessenger?

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Setup

    /// 初始化原生窗口管理器
    ///
    /// 在 MainFlutterWindow.awakeFromNib() 中调用此方法完成初始化。
    ///
    /// - Parameter binaryMessenger: FlutterViewController 的 binaryMessenger
    func setup(with binaryMessenger: FlutterBinaryMessenger) {
        self.binaryMessenger = binaryMessenger

        // 注册统一的 Platform Channel
        methodChannel = FlutterMethodChannel(
            name: "com.amberlist.native_window",
            binaryMessenger: binaryMessenger
        )

        methodChannel?.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }

        // 注册内置窗口工厂
        registerBuiltInFactories()

        print("[NativeWindowManager] Platform Channel 已注册，通道: com.amberlist.native_window")
    }

    /// 注册内置窗口工厂
    private func registerBuiltInFactories() {
        // 注册 QuickAdd 窗口工厂
        registerFactory(for: "quick_add") { [weak self] windowId, arguments in
            return QuickAddWindow(
                windowId: windowId,
                manager: self,
                arguments: arguments
            )
        }

        print("[NativeWindowManager] 已注册内置窗口工厂: quick_add")
    }

    // MARK: - Factory Registration

    /// 注册窗口工厂
    ///
    /// - Parameters:
    ///   - windowType: 窗口类型标识
    ///   - factory: 创建窗口的工厂闭包，接收 windowId 和 arguments 参数
    func registerFactory(for windowType: String, factory: @escaping (String?, [String: Any]?) -> NativeWindowProtocol) {
        factories[windowType] = factory
    }

    // MARK: - Method Channel Handler

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let method = call.method
        let arguments = call.arguments as? [String: Any]

        switch method {
        case "createOrShow":
            handleCreateOrShow(arguments, result: result)

        case "hide":
            handleHide(arguments, result: result)

        case "destroy":
            handleDestroy(arguments, result: result)

        case "sendMessage":
            handleSendMessage(arguments, result: result)

        case "isWindowOpen":
            handleIsWindowOpen(arguments, result: result)

        case "getOpenWindows":
            handleGetOpenWindows(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Create or Show Window

    private func handleCreateOrShow(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let args = arguments,
              let windowType = args["windowType"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing windowType", details: nil))
            return
        }

        let windowId = args["windowId"] as? String
        let showArgs = args["arguments"] as? [String: Any]

        // 生成窗口标识符
        let identifier = makeIdentifier(windowType: windowType, windowId: windowId)

        // 如果窗口已存在，直接显示
        if let existingWindow = windows[identifier] {
            existingWindow.show(arguments: showArgs)
            result(["success": true, "identifier": identifier, "created": false])
            return
        }

        // 查找工厂创建新窗口
        guard let factory = factories[windowType] else {
            result(FlutterError(
                code: "UNKNOWN_TYPE",
                message: "No factory registered for window type: \(windowType)",
                details: nil
            ))
            return
        }

        // 创建窗口
        let window = factory(windowId, showArgs)
        windows[identifier] = window

        // 显示窗口
        window.show(arguments: showArgs)

        print("[NativeWindowManager] 创建窗口: \(identifier)")
        result(["success": true, "identifier": identifier, "created": true])
    }

    // MARK: - Hide Window

    private func handleHide(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let args = arguments,
              let windowType = args["windowType"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing windowType", details: nil))
            return
        }

        let windowId = args["windowId"] as? String
        let identifier = makeIdentifier(windowType: windowType, windowId: windowId)

        if let window = windows[identifier] {
            window.hide()
            result(["success": true])
        } else {
            result(["success": false, "error": "Window not found: \(identifier)"])
        }
    }

    // MARK: - Destroy Window

    private func handleDestroy(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let args = arguments,
              let windowType = args["windowType"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing windowType", details: nil))
            return
        }

        let windowId = args["windowId"] as? String
        let identifier = makeIdentifier(windowType: windowType, windowId: windowId)

        if let window = windows[identifier] {
            window.destroy()
            windows.removeValue(forKey: identifier)
            print("[NativeWindowManager] 销毁窗口: \(identifier)")
            result(["success": true])
        } else {
            result(["success": false, "error": "Window not found: \(identifier)"])
        }
    }

    // MARK: - Send Message to Window

    private func handleSendMessage(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let args = arguments,
              let windowType = args["windowType"] as? String,
              let method = args["method"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing windowType or method", details: nil))
            return
        }

        let windowId = args["windowId"] as? String
        let messageArgs = args["arguments"]
        let identifier = makeIdentifier(windowType: windowType, windowId: windowId)

        if let window = windows[identifier] {
            window.handleFlutterMessage(method: method, arguments: messageArgs, result: result)
        } else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found: \(identifier)", details: nil))
        }
    }

    // MARK: - Query Window State

    private func handleIsWindowOpen(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let args = arguments,
              let windowType = args["windowType"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing windowType", details: nil))
            return
        }

        let windowId = args["windowId"] as? String
        let identifier = makeIdentifier(windowType: windowType, windowId: windowId)
        let isOpen = windows[identifier] != nil

        result(["isOpen": isOpen, "identifier": identifier])
    }

    private func handleGetOpenWindows(result: @escaping FlutterResult) {
        let openWindows = windows.keys.map { $0 }
        result(["windows": openWindows])
    }

    // MARK: - Notify Flutter

    /// 向 Flutter 发送消息
    ///
    /// 由窗口实现调用，用于通知 Flutter 侧的事件（如任务创建、窗口关闭等）
    ///
    /// - Parameters:
    ///   - method: 方法名
    ///   - arguments: 参数字典
    func notifyFlutter(method: String, arguments: [String: Any]) {
        methodChannel?.invokeMethod(method, arguments: arguments)
        print("[NativeWindowManager] 通知 Flutter: \(method), 参数: \(arguments)")
    }

    // MARK: - Window Lifecycle Callbacks

    /// 窗口关闭回调
    ///
    /// 窗口关闭时调用此方法，从注册表中移除窗口并通知 Flutter
    ///
    /// - Parameters:
    ///   - windowType: 窗口类型
    ///   - windowId: 窗口实例 ID（可选）
    func windowDidClose(windowType: String, windowId: String?) {
        let identifier = makeIdentifier(windowType: windowType, windowId: windowId)
        windows.removeValue(forKey: identifier)

        notifyFlutter(method: "onWindowClosed", arguments: [
            "windowType": windowType,
            "windowId": windowId as Any,
            "identifier": identifier
        ])

        print("[NativeWindowManager] 窗口已关闭: \(identifier)")
    }

    // MARK: - Helpers

    /// 生成窗口标识符
    private func makeIdentifier(windowType: String, windowId: String?) -> String {
        if let id = windowId {
            return "\(windowType)_\(id)"
        }
        return windowType
    }

    // MARK: - Cleanup

    /// 关闭所有窗口
    func closeAllWindows() {
        for (_, window) in windows {
            window.destroy()
        }
        windows.removeAll()
        print("[NativeWindowManager] 所有窗口已关闭")
    }
}
