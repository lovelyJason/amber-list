import Cocoa

/// 原生便签窗口控制器
/// 使用 AppKit 实现，绕过 Flutter 多窗口的各种 bug
class StickyNoteWindowController: NSWindowController {

    // MARK: - Properties

    /// 便签唯一标识（对应 Flutter 侧的 listId 或 taskId）
    let noteId: String

    /// 便签标题
    var noteTitle: String

    /// 当前主题色（十六进制字符串，如 "0xFFFFF7D1"）
    var themeColorHex: String

    /// 活跃任务列表
    var activeTasks: [[String: Any]]

    /// 已完成任务列表
    var completedTasks: [[String: Any]]

    /// 是否置顶
    var isPinned: Bool = true {
        didSet {
            window?.level = isPinned ? .floating : .normal
        }
    }

    /// 回调：任务状态变化时通知 Flutter
    var onTaskToggled: ((String, Bool) -> Void)?

    /// 回调：窗口关闭时通知 Flutter
    var onWindowClosed: ((String) -> Void)?

    // MARK: - UI Components

    private var contentView: StickyNoteContentView!

    // MARK: - 预定义颜色

    private static let themeColors: [String: NSColor] = [
        "0xFFFFF7D1": NSColor(red: 1.0, green: 0.969, blue: 0.820, alpha: 1.0),    // Yellow
        "0xFFE1F5FE": NSColor(red: 0.882, green: 0.961, blue: 0.996, alpha: 1.0),  // Blue
        "0xFFFFEBEE": NSColor(red: 1.0, green: 0.922, blue: 0.933, alpha: 1.0),    // Pink
        "0xFFE8F5E9": NSColor(red: 0.910, green: 0.961, blue: 0.914, alpha: 1.0),  // Green
    ]

    // MARK: - Initialization

    init(noteId: String, title: String, themeColor: String, activeTasks: [[String: Any]], completedTasks: [[String: Any]]) {
        self.noteId = noteId
        self.noteTitle = title
        self.themeColorHex = themeColor
        self.activeTasks = activeTasks
        self.completedTasks = completedTasks

        // 创建窗口
        // 使用 .fullSizeContentView 让内容延伸到标题栏区域
        // 不使用 .titled 可以完全隐藏标题栏，但会失去拖拽功能
        // 所以保留 .titled 但隐藏红绿灯按钮
        // 注意：移除 .resizable，让窗口大小固定
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        setupWindow()
        setupContentView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupWindow() {
        guard let window = window else { return }

        // 窗口基本设置
        // 标题格式：琥珀便签 - 任务清单名称（用于 Dock 窗口列表显示）
        window.title = "琥珀便签 - \(noteTitle)"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true

        // 固定窗口大小为 320x400，防止内容撑开/收缩窗口
        let fixedSize = NSSize(width: 320, height: 400)
        window.minSize = fixedSize
        window.maxSize = fixedSize
        window.setContentSize(fixedSize)

        // 禁用窗口状态恢复，防止 macOS 记住上次的窗口大小
        window.isRestorable = false

        // 隐藏红绿灯按钮（关闭/最小化/最大化）
        // 因为我们有自定义的关闭按钮
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        // 默认置顶
        window.level = .floating

        // 居中显示
        window.center()

        // 设置代理
        window.delegate = self

        // 设置背景色
        updateBackgroundColor()
    }

    private func setupContentView() {
        guard let window = window else { return }

        contentView = StickyNoteContentView(
            title: noteTitle,
            activeTasks: activeTasks,
            completedTasks: completedTasks,
            themeColor: currentThemeColor
        )

        // 设置回调
        contentView.onTaskToggled = { [weak self] taskId, isCompleted in
            self?.handleTaskToggle(taskId: taskId, isCompleted: isCompleted)
        }

        contentView.onPinToggled = { [weak self] in
            self?.togglePin()
        }

        contentView.onColorChanged = { [weak self] colorHex in
            self?.changeThemeColor(to: colorHex)
        }

        contentView.onCloseRequested = { [weak self] in
            self?.close()
        }

        contentView.isPinned = isPinned

        window.contentView = contentView
    }

    private var currentThemeColor: NSColor {
        return Self.themeColors[themeColorHex] ?? Self.themeColors["0xFFFFF7D1"]!
    }

    private func updateBackgroundColor() {
        window?.backgroundColor = currentThemeColor
        contentView?.updateThemeColor(currentThemeColor)
    }

    // MARK: - Actions

    private func handleTaskToggle(taskId: String, isCompleted: Bool) {
        // 本地更新 UI
        if isCompleted {
            // 从 active 移到 completed
            if let index = activeTasks.firstIndex(where: { $0["id"] as? String == taskId }) {
                var task = activeTasks.remove(at: index)
                task["isCompleted"] = true
                completedTasks.append(task)
            }
        } else {
            // 从 completed 移到 active
            if let index = completedTasks.firstIndex(where: { $0["id"] as? String == taskId }) {
                var task = completedTasks.remove(at: index)
                task["isCompleted"] = false
                activeTasks.append(task)
            }
        }

        // 刷新 UI
        contentView.updateTasks(active: activeTasks, completed: completedTasks)

        // 通知 Flutter
        onTaskToggled?(taskId, isCompleted)
    }

    private func togglePin() {
        isPinned.toggle()
        contentView.isPinned = isPinned
    }

    private func changeThemeColor(to colorHex: String) {
        themeColorHex = colorHex
        updateBackgroundColor()
    }

    // MARK: - Public Methods

    /// 从 Flutter 更新任务列表
    func updateTasks(active: [[String: Any]], completed: [[String: Any]]) {
        self.activeTasks = active
        self.completedTasks = completed
        contentView?.updateTasks(active: active, completed: completed)
    }

    /// 显示窗口
    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 聚焦窗口
    func focusWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - NSWindowDelegate

extension StickyNoteWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        onWindowClosed?(noteId)
    }
}
