import Cocoa
import FlutterMacOS

/// 原生窗口协议
///
/// 所有原生窗口（QuickAdd、StickyNote 等）必须实现此协议。
/// 提供统一的窗口生命周期管理接口。
protocol NativeWindowProtocol: AnyObject {
    /// 窗口类型标识（唯一）
    /// 用于 Platform Channel 消息路由
    var windowType: String { get }

    /// 窗口实例 ID（可选，支持同类型多窗口）
    /// 如果窗口类型只能有一个实例，返回 nil
    var windowId: String? { get }

    /// NSWindow 实例
    var window: NSWindow? { get }

    /// 显示窗口
    /// - Parameter arguments: 创建/显示参数
    func show(arguments: [String: Any]?)

    /// 隐藏窗口（不销毁）
    func hide()

    /// 销毁窗口
    func destroy()

    /// 处理来自 Flutter 的消息
    /// - Parameters:
    ///   - method: 消息方法名
    ///   - arguments: 消息参数
    ///   - result: Flutter 结果回调
    func handleFlutterMessage(method: String, arguments: Any?, result: @escaping FlutterResult)
}

// MARK: - 默认实现

extension NativeWindowProtocol {
    /// 窗口唯一标识符
    /// 格式：{windowType} 或 {windowType}_{windowId}
    var identifier: String {
        if let id = windowId {
            return "\(windowType)_\(id)"
        }
        return windowType
    }

    /// 默认隐藏实现
    func hide() {
        window?.orderOut(nil)
    }

    /// 默认销毁实现
    func destroy() {
        window?.close()
    }
}
