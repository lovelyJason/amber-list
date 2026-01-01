import Cocoa
import FlutterMacOS

/// 便签窗口管理器
/// 负责管理所有原生便签窗口的生命周期
/// 处理 Platform Channel 的消息分发
class StickyNoteManager: NSObject {

    // MARK: - Singleton

    static let shared = StickyNoteManager()

    // MARK: - Properties

    /// 存储所有活跃的便签窗口控制器
    /// Key: noteId, Value: StickyNoteWindowController
    private var windowControllers: [String: StickyNoteWindowController] = [:]

    /// Platform Channel，用于与 Flutter 通信
    private var methodChannel: FlutterMethodChannel?

    /// 窗口创建计数器，用于计算新窗口的偏移位置
    /// 每创建一个窗口就递增，让新窗口位置错开
    private var windowCreationCount: Int = 0

    /// 每个新窗口相对于前一个窗口的偏移量（像素）
    private let windowOffsetStep: CGFloat = 30

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Setup

    /// 在 AppDelegate 或 MainFlutterWindow 中调用此方法进行初始化
    /// - Parameter binaryMessenger: FlutterViewController 的 binaryMessenger
    func setup(with binaryMessenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: "com.amberlist.sticky_note",
            binaryMessenger: binaryMessenger
        )

        methodChannel?.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }

        print("[StickyNoteManager] Platform Channel 已注册")
    }

    // MARK: - Method Channel Handler

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "createStickyNote":
            handleCreateStickyNote(call.arguments, result: result)

        case "closeStickyNote":
            handleCloseStickyNote(call.arguments, result: result)

        case "updateStickyNote":
            handleUpdateStickyNote(call.arguments, result: result)

        case "focusStickyNote":
            handleFocusStickyNote(call.arguments, result: result)

        case "isWindowOpen":
            handleIsWindowOpen(call.arguments, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Create Sticky Note

    private func handleCreateStickyNote(_ arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let noteId = args["id"] as? String,
              let title = args["title"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
            return
        }

        // 如果已存在，聚焦
        if let existingController = windowControllers[noteId] {
            existingController.focusWindow()
            result(["success": true, "windowId": noteId])
            return
        }

        let themeColor = args["themeColor"] as? String ?? "0xFFFFF7D1"
        let activeTasks = args["active"] as? [[String: Any]] ?? []
        let completedTasks = args["completed"] as? [[String: Any]] ?? []

        // 创建窗口控制器
        let controller = StickyNoteWindowController(
            noteId: noteId,
            title: title,
            themeColor: themeColor,
            activeTasks: activeTasks,
            completedTasks: completedTasks
        )

        // 设置回调
        controller.onTaskToggled = { [weak self] taskId, isCompleted in
            self?.notifyFlutterTaskToggled(taskId: taskId, isCompleted: isCompleted)
        }

        controller.onWindowClosed = { [weak self] closedNoteId in
            self?.windowControllers.removeValue(forKey: closedNoteId)
            self?.notifyFlutterWindowClosed(noteId: closedNoteId)
        }

        // 存储并显示
        windowControllers[noteId] = controller
        controller.showWindow()

        // 设置窗口位置偏移，避免新窗口完全重叠
        // 使用级联效果：每个新窗口往右下偏移一点
        if let window = controller.window {
            let offset = CGFloat(windowCreationCount % 5) * windowOffsetStep

            // 强制设置初始大小（防止 macOS 窗口状态恢复导致大小不一致）
            let initialWidth: CGFloat = 320
            let initialHeight: CGFloat = 400

            // 获取屏幕可用区域
            if let screen = window.screen ?? NSScreen.main {
                let visibleFrame = screen.visibleFrame

                // 计算新位置（从屏幕中心开始，往右下偏移）
                let centerX = visibleFrame.midX - initialWidth / 2
                let centerY = visibleFrame.midY - initialHeight / 2

                let newFrame = NSRect(
                    x: centerX + offset,
                    y: centerY - offset,  // Y 轴向下偏移（macOS 坐标系 Y 向上）
                    width: initialWidth,
                    height: initialHeight
                )

                // 确保窗口不超出屏幕边界
                var adjustedFrame = newFrame
                adjustedFrame.origin.x = min(adjustedFrame.origin.x, visibleFrame.maxX - adjustedFrame.width - 20)
                adjustedFrame.origin.y = max(adjustedFrame.origin.y, visibleFrame.minY + 20)

                // 强制设置窗口大小（不使用动画）
                window.setFrame(adjustedFrame, display: true, animate: false)
            }

            windowCreationCount += 1
        }
        result(["success": true, "windowId": noteId])
    }

    // MARK: - Close Sticky Note

    private func handleCloseStickyNote(_ arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let noteId = args["id"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing note id", details: nil))
            return
        }

        if let controller = windowControllers[noteId] {
            controller.window?.close()
            // windowControllers 会在 onWindowClosed 回调中移除
            result(["success": true])
        } else {
            result(["success": false, "error": "Window not found"])
        }
    }

    // MARK: - Update Sticky Note

    private func handleUpdateStickyNote(_ arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let noteId = args["id"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing note id", details: nil))
            return
        }

        guard let controller = windowControllers[noteId] else {
            result(["success": false, "error": "Window not found"])
            return
        }

        let activeTasks = args["active"] as? [[String: Any]] ?? []
        let completedTasks = args["completed"] as? [[String: Any]] ?? []

        controller.updateTasks(active: activeTasks, completed: completedTasks)
        result(["success": true])
    }

    // MARK: - Focus Sticky Note

    private func handleFocusStickyNote(_ arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let noteId = args["id"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing note id", details: nil))
            return
        }

        if let controller = windowControllers[noteId] {
            controller.focusWindow()
            result(["success": true])
        } else {
            result(["success": false, "error": "Window not found"])
        }
    }

    // MARK: - Is Window Open

    private func handleIsWindowOpen(_ arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let noteId = args["id"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing note id", details: nil))
            return
        }

        let isOpen = windowControllers[noteId] != nil
        result(["isOpen": isOpen])
    }

    // MARK: - Notify Flutter

    private func notifyFlutterTaskToggled(taskId: String, isCompleted: Bool) {
        methodChannel?.invokeMethod("onTaskToggled", arguments: [
            "taskId": taskId,
            "isCompleted": isCompleted
        ])
        print("[StickyNoteManager] 通知 Flutter 任务状态变化: \(taskId) -> \(isCompleted)")
    }

    private func notifyFlutterWindowClosed(noteId: String) {
        methodChannel?.invokeMethod("onStickyNoteClosed", arguments: [
            "id": noteId
        ])
        print("[StickyNoteManager] 通知 Flutter 窗口关闭: \(noteId)")
    }

    // MARK: - Cleanup

    /// 关闭所有便签窗口
    func closeAllWindows() {
        for (_, controller) in windowControllers {
            controller.window?.close()
        }
        windowControllers.removeAll()
    }
}
