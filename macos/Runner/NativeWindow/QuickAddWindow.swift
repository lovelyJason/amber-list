import Cocoa
import FlutterMacOS

/// 闪念胶囊窗口
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
class QuickAddWindow: NSObject, NativeWindowProtocol {

    // MARK: - NativeWindowProtocol

    var windowType: String { "quick_add" }
    var windowId: String?
    var window: NSWindow?

    // MARK: - Properties

    /// 窗口管理器引用（弱引用避免循环）
    private weak var manager: NativeWindowManager?

    /// 窗口控制器
    private var windowController: QuickAddWindowController?

    /// 当前选中的日期（默认今天）
    private var selectedDate: Date = Date()

    /// 从 Flutter 传来的标签列表
    private var tags: [String] = []

    /// 从 Flutter 传来的清单列表 [{id: String, name: String}]
    private var taskLists: [[String: String]] = []

    // MARK: - Initialization

    init(windowId: String?, manager: NativeWindowManager?, arguments: [String: Any]?) {
        self.windowId = windowId
        self.manager = manager
        super.init()

        // 解析初始参数
        if let args = arguments {
            if let dateTimestamp = args["selectedDate"] as? Double {
                selectedDate = Date(timeIntervalSince1970: dateTimestamp / 1000)
            }
            // 解析标签列表
            if let tagList = args["tags"] as? [String] {
                tags = tagList
            }
            // 解析清单列表
            if let lists = args["taskLists"] as? [[String: String]] {
                taskLists = lists
            }
        }
    }

    // MARK: - NativeWindowProtocol Implementation

    func show(arguments: [String: Any]?) {
        // 更新参数
        if let args = arguments {
            if let dateTimestamp = args["selectedDate"] as? Double {
                selectedDate = Date(timeIntervalSince1970: dateTimestamp / 1000)
            }
            // 更新标签列表
            if let tagList = args["tags"] as? [String] {
                tags = tagList
            }
            // 更新清单列表
            if let lists = args["taskLists"] as? [[String: String]] {
                taskLists = lists
            }
        }

        // 如果窗口已存在，更新数据后显示
        if windowController != nil {
            windowController?.updateData(tags: tags, taskLists: taskLists)
            windowController?.showWindow()
            return
        }

        // 创建新窗口
        windowController = QuickAddWindowController(selectedDate: selectedDate, tags: tags, taskLists: taskLists)
        window = windowController?.window

        // 设置回调
        windowController?.onTaskCreated = { [weak self] title, date, hasDate, isNote, priority, tags, listId in
            self?.handleTaskCreated(title: title, date: date, hasDate: hasDate, isNote: isNote, priority: priority, tags: tags, listId: listId)
        }

        windowController?.onCancelled = { [weak self] in
            self?.handleCancelled()
        }

        windowController?.showWindow()
        print("[QuickAddWindow] 窗口已显示")
    }

    func hide() {
        windowController?.hideWindow()
        print("[QuickAddWindow] 窗口已隐藏")
    }

    func destroy() {
        windowController?.closeWindow()
        windowController = nil
        window = nil

        // 通知管理器
        manager?.windowDidClose(windowType: windowType, windowId: windowId)
        print("[QuickAddWindow] 窗口已销毁")
    }

    func handleFlutterMessage(method: String, arguments: Any?, result: @escaping FlutterResult) {
        switch method {
        case "focus":
            windowController?.focusInput()
            result(["success": true])

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Event Handlers

    /// 处理任务/笔记创建
    private func handleTaskCreated(title: String, date: Date, hasDate: Bool, isNote: Bool, priority: Int, tags: [String], listId: String?) {
        // 转换日期为时间戳（毫秒）
        let dateTimestamp = date.timeIntervalSince1970 * 1000

        // 根据类型选择不同的回调方法
        let method = isNote ? "onQuickAddNoteCreated" : "onQuickAddTaskCreated"

        // 通知 Flutter 创建任务/笔记
        manager?.notifyFlutter(method: method, arguments: [
            "title": title,
            "dueDate": hasDate ? dateTimestamp : NSNull(),  // 如果没选日期，传 null
            "hasDate": hasDate,
            "isNote": isNote,
            "priority": priority,
            "tags": tags,
            "listId": listId as Any,  // 清单 ID（nil 表示收集箱）
            "windowType": windowType,
            "windowId": windowId as Any
        ])

        // 隐藏窗口
        hide()
    }

    /// 处理取消
    private func handleCancelled() {
        // 通知 Flutter
        manager?.notifyFlutter(method: "onQuickAddCancelled", arguments: [
            "windowType": windowType,
            "windowId": windowId as Any
        ])

        // 隐藏窗口
        hide()
    }
}

// MARK: - QuickAddPanel（自定义面板，支持键盘输入但不激活主应用）

/// 自定义 NSPanel 子类
///
/// 关键特性：
/// - 使用 nonactivatingPanel 样式，不激活主应用
/// - 重写 canBecomeKey 返回 true，允许接收键盘输入
/// - 类似 Spotlight 的行为
class QuickAddPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true  // 允许成为 key window，这样才能接收键盘输入
    }

    override var canBecomeMain: Bool {
        return false  // 不成为 main window，避免激活主应用
    }
}

// MARK: - QuickAddWindowController

/// 闪念胶囊窗口控制器
///
/// 管理窗口的创建、显示、隐藏和事件处理
class QuickAddWindowController: NSObject, NSWindowDelegate {

    // MARK: - Properties

    var window: NSWindow?
    private var contentView: QuickAddContentView?

    /// 当前选中的日期
    private var selectedDate: Date

    /// 从 Flutter 传来的标签列表
    private var tags: [String]

    /// 从 Flutter 传来的清单列表 [{id: String, name: String}]
    private var taskLists: [[String: String]]

    /// 全局鼠标事件监听器（用于检测点击窗口外部）
    private var globalMouseMonitor: Any?

    /// 本地鼠标事件监听器（用于处理窗口内点击）
    private var localMouseMonitor: Any?

    // MARK: - Callbacks

    /// 任务/笔记创建回调（标题, 日期, 是否选择了日期, 是否笔记, 优先级, 标签, 清单ID）
    var onTaskCreated: ((String, Date, Bool, Bool, Int, [String], String?) -> Void)?
    var onCancelled: (() -> Void)?

    // MARK: - Initialization

    init(selectedDate: Date, tags: [String] = [], taskLists: [[String: String]] = []) {
        self.selectedDate = selectedDate
        self.tags = tags
        self.taskLists = taskLists
        super.init()
        setupWindow()
    }

    /// 更新数据（热键再次触发时调用）
    func updateData(tags: [String], taskLists: [[String: String]]) {
        self.tags = tags
        self.taskLists = taskLists
        contentView?.updateData(tags: tags, taskLists: taskLists)
    }

    // MARK: - Setup

    private func setupWindow() {
        // 创建自定义 Panel（支持键盘输入但不激活主应用）
        // 使用 nonactivatingPanel 样式是关键！
        let panel = QuickAddPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 60),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Panel 特有属性
        panel.becomesKeyOnlyIfNeeded = false  // 允许成为 key window
        panel.hidesOnDeactivate = false       // 应用失焦时不隐藏
        panel.worksWhenModal = true           // 模态时也能工作
        panel.isFloatingPanel = true          // 浮动面板

        // 窗口属性
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating               // 浮动层级
        panel.isMovableByWindowBackground = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        // 禁用窗口状态恢复
        panel.isRestorable = false

        // 设置代理
        panel.delegate = self

        let window = panel

        // 创建内容视图（传递标签和清单数据）
        contentView = QuickAddContentView(selectedDate: selectedDate, tags: tags, taskLists: taskLists)
        contentView?.onSubmit = { [weak self] title, date, hasDate, isNote, priority, tags, listId in
            guard let self = self else { return }
            self.onTaskCreated?(title, date, hasDate, isNote, priority, tags, listId)
        }
        contentView?.onCancel = { [weak self] in
            self?.onCancelled?()
        }
        contentView?.onSizeChange = { [weak self] newHeight in
            self?.resizeWindow(to: newHeight)
        }

        window.contentView = contentView

        // 居中显示在屏幕上方（类似 Spotlight）
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame
            let x = screenFrame.midX - windowFrame.width / 2
            let y = screenFrame.maxY - 200 - windowFrame.height  // 距离顶部 200px
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        self.window = window
    }

    // MARK: - Window Actions

    func showWindow() {
        guard let window = window else { return }

        // 每次显示时重新计算位置（居中显示在屏幕上方）
        // 这样可以避免展开/收缩模式后位置偏移的问题
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame
            let x = screenFrame.midX - windowFrame.width / 2
            let y = screenFrame.maxY - 200 - windowFrame.height  // 距离顶部 200px
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // 显示窗口并成为 key window
        window.makeKeyAndOrderFront(nil)

        // 延迟聚焦输入框（确保窗口完全显示后再聚焦）
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else { return }
            // 确保窗口成为 key window
            window.makeKey()
            // 聚焦输入框
            self.contentView?.focusInput()
        }

        // 启动全局鼠标监听器（检测点击窗口外部）
        startMouseMonitors()
    }

    func hideWindow() {
        // 停止鼠标监听器
        stopMouseMonitors()

        window?.orderOut(nil)
        contentView?.clearInput()

        // 重置到基础模式（下次显示时从基础模式开始）
        contentView?.resetToCompactMode()

        // 重置窗口大小
        if let window = window {
            var frame = window.frame
            frame.size.height = 60  // compactHeight
            window.setFrame(frame, display: false)
        }
    }

    func closeWindow() {
        stopMouseMonitors()
        window?.close()
    }

    // MARK: - Mouse Monitors（全局点击监听，实现点击窗口外关闭）

    /// 启动全局和本地鼠标监听器
    private func startMouseMonitors() {
        // 停止已有的监听器
        stopMouseMonitors()

        // 全局监听器：监听应用外部的鼠标点击
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            print("[QuickAddWindowController] 全局监听器：检测到应用外部点击")
            self?.handleMouseClickOutside()
        }

        // 本地监听器：监听应用内部的鼠标点击（主窗口等）
        // 注意：这个监听器可以捕获到当前应用内所有窗口的点击事件
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let quickAddWindow = self.window else { return event }

            // 方法1：检查事件的目标窗口
            // 如果点击的窗口不是 QuickAdd 窗口，也不是 popover 窗口，就关闭
            let clickedWindow = event.window

            // 检查是否点击了 QuickAdd 窗口
            let isClickOnQuickAdd = clickedWindow === quickAddWindow

            // 检查是否点击了 popover 窗口（日期选择器等）
            var isClickOnPopover = false
            if let contentView = self.contentView,
               let popover = contentView.getActivePopover(),
               popover.isShown,
               let popoverWindow = popover.contentViewController?.view.window {
                isClickOnPopover = clickedWindow === popoverWindow
            }

            print("[QuickAddWindowController] 本地监听器：点击窗口=\(String(describing: clickedWindow)), QuickAdd=\(isClickOnQuickAdd), Popover=\(isClickOnPopover)")

            // 如果点击的不是 QuickAdd 窗口也不是 Popover 窗口，关闭
            if !isClickOnQuickAdd && !isClickOnPopover {
                // 额外验证：使用屏幕坐标确认（作为备选方案）
                let screenLocation = NSEvent.mouseLocation
                let isInsideQuickAddFrame = quickAddWindow.frame.contains(screenLocation)

                if !isInsideQuickAddFrame {
                    print("[QuickAddWindowController] 点击在 QuickAdd 窗口外部，关闭窗口")
                    self.handleMouseClickOutside()
                }
            }

            return event
        }

        print("[QuickAddWindowController] 鼠标监听器已启动")
    }

    /// 停止鼠标监听器
    private func stopMouseMonitors() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseMonitor = nil
        }
    }

    /// 处理点击窗口外部
    private func handleMouseClickOutside() {
        // 如果有 popover 打开（如日期选择器），不要关闭窗口
        if let contentView = contentView, contentView.hasActivePopover() {
            print("[QuickAddWindowController] 检测到 popover 打开，忽略外部点击")
            return
        }

        print("[QuickAddWindowController] 检测到点击窗口外部，关闭窗口")
        hideWindow()
        onCancelled?()
    }

    func focusInput() {
        contentView?.focusInput()
    }

    /// 调整窗口大小（保持顶部位置不变，向下扩展）
    func resizeWindow(to newHeight: CGFloat) {
        guard let window = window else { return }

        // 获取当前窗口 frame
        var frame = window.frame

        // 计算高度差
        let heightDelta = newHeight - frame.height

        // 调整 y 坐标（macOS 坐标系原点在左下角，所以向下扩展需要减小 y）
        frame.origin.y -= heightDelta
        frame.size.height = newHeight

        // 带动画调整窗口大小
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(frame, display: true)
        }

        print("[QuickAddWindowController] 窗口大小已调整: height = \(newHeight)")
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        // 如果有 popover 打开（如日期选择器），不要关闭窗口
        if let contentView = contentView, contentView.hasActivePopover() {
            print("[QuickAddWindowController] 检测到 popover 打开，暂不关闭窗口")
            return
        }

        // 窗口失去焦点时隐藏（类似 Spotlight 行为）
        hideWindow()
        onCancelled?()
    }
}

// MARK: - QuickAddContentView

/// 闪念胶囊内容视图
///
/// 支持两种模式：
/// 1. 基础模式（默认）：单行输入框，快速添加任务
/// 2. 展开模式（Tab触发）：详细输入面板，支持日期、列表、优先级等
///
/// 基础模式 UI：
/// ┌────────────────────────────────────────────────────────────────┐
/// │  🪲  │  添加任务...（Tab 展开详情）              │  ↵   │
/// └────────────────────────────────────────────────────────────────┘
///
/// 展开模式 UI：
/// ┌─────────────────────────────────────────────────────────────────────┐
/// │  准备做什么?                                                         │
/// ├─────────────────────────────────────────────────────────────────────┤
/// │  输入内容...                                                         │
/// │                                                                      │
/// │                                      ≡列表  🏷标签  📅日期  🚩优先级  │
/// ├─────────────────────────────────────────────────────────────────────┤
/// │  📥 收集箱                                    取消        确定        │
/// └─────────────────────────────────────────────────────────────────────┘
class QuickAddContentView: NSView {

    // MARK: - Associated Object Keys（用于 objc_setAssociatedObject）

    /// datePicker 关联键
    private static var datePickerKey: UInt8 = 0
    /// popover 关联键
    private static var popoverKey: UInt8 = 0

    // MARK: - Constants

    /// 琥珀金主色
    private let amberColor = NSColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 1.0)

    /// 基础模式高度
    private let compactHeight: CGFloat = 60

    /// 展开模式高度
    private let expandedHeight: CGFloat = 280

    // MARK: - Properties

    private var selectedDate: Date

    /// 从 Flutter 传来的标签列表（动态）
    private var availableTags: [String] = []

    /// 从 Flutter 传来的清单列表 [{id: String, name: String}]（动态）
    private var availableTaskLists: [[String: String]] = []

    /// 是否为展开模式
    private var isExpanded = false

    /// 选中的清单 ID（nil 表示收集箱）
    private var selectedListId: String? = nil

    /// 选中的清单名称
    private var selectedListName: String = "收集箱"

    /// 选中的优先级（0=无, 1=低, 2=中, 3=高）
    private var selectedPriority: Int = 0

    /// 是否为笔记模式（false=任务，true=笔记）
    private var isNoteMode = false

    /// 选中的标签列表
    private var selectedTags: [String] = []

    /// 是否已选择日期（区分"未选择"和"选择了今天"）
    private var hasSelectedDate = false

    /// 当前打开的 popover（用于阻止窗口关闭）
    private var activePopover: NSPopover?

    /// 底部栏图标
    private var listIcon: NSImageView!

    // MARK: - Callbacks

    /// 任务提交回调（标题, 日期, 是否选择了日期, 是否笔记, 优先级, 标签, 清单ID）
    var onSubmit: ((String, Date, Bool, Bool, Int, [String], String?) -> Void)?

    /// 取消回调
    var onCancel: (() -> Void)?

    /// 窗口大小变化回调
    var onSizeChange: ((CGFloat) -> Void)?

    // MARK: - UI Components（基础模式）

    private var containerView: NSView!
    private var logoImageView: NSImageView!
    private var textField: NSTextField!
    private var submitButton: NSButton!

    // MARK: - UI Components（展开模式）

    private var expandedContainerView: NSView!
    private var titleLabel: NSTextField!
    private var contentTextView: NSScrollView!
    private var contentTextField: NSTextView!
    private var toolbarView: NSView!
    private var listButton: NSButton!
    private var tagButton: NSButton!
    private var dateButton: NSButton!
    private var priorityButton: NSButton!
    private var footerView: NSView!
    private var listSelectorButton: NSButton!
    private var selectedListLabel: NSTextField!
    private var cancelButton: NSButton!
    private var confirmButton: NSButton!

    // MARK: - Initialization

    init(selectedDate: Date, tags: [String] = [], taskLists: [[String: String]] = []) {
        self.selectedDate = selectedDate
        self.availableTags = tags
        self.availableTaskLists = taskLists
        super.init(frame: NSRect(x: 0, y: 0, width: 600, height: 60))
        setupCompactUI()
    }

    /// 更新数据（热键再次触发时调用）
    func updateData(tags: [String], taskLists: [[String: String]]) {
        self.availableTags = tags
        self.availableTaskLists = taskLists
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup（基础模式）

    private func setupCompactUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        // 圆角容器（白色背景）
        containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.white.cgColor
        containerView.layer?.cornerRadius = 12
        containerView.layer?.shadowColor = NSColor.black.cgColor
        containerView.layer?.shadowOpacity = 0.2
        containerView.layer?.shadowRadius = 20
        containerView.layer?.shadowOffset = CGSize(width: 0, height: -5)
        addSubview(containerView)

        // Logo（使用琥珀图片）
        logoImageView = NSImageView()
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.imageScaling = .scaleProportionallyUpOrDown
        logoImageView.wantsLayer = true
        logoImageView.layer?.cornerRadius = 16
        logoImageView.layer?.masksToBounds = true

        // 尝试加载琥珀图片
        if let logoImage = loadAmberLogo() {
            logoImageView.image = logoImage
        } else {
            // 备用：使用系统图标
            if #available(macOS 11.0, *) {
                logoImageView.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "琥珀")
                logoImageView.contentTintColor = amberColor
            }
        }
        containerView.addSubview(logoImageView)

        // 输入框
        textField = NSTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholderString = "添加任务...（Tab 展开详情）"
        textField.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        textField.delegate = self
        containerView.addSubview(textField)

        // 提交按钮（Enter 图标）
        submitButton = NSButton()
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        submitButton.bezelStyle = .regularSquare
        submitButton.isBordered = false
        submitButton.wantsLayer = true
        submitButton.layer?.cornerRadius = 6
        submitButton.layer?.backgroundColor = amberColor.cgColor
        submitButton.target = self
        submitButton.action = #selector(submitTapped)
        submitButton.toolTip = "添加任务 (Enter)"
        submitButton.refusesFirstResponder = true

        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            submitButton.image = NSImage(systemSymbolName: "return", accessibilityDescription: "提交")?
                .withSymbolConfiguration(config)
            submitButton.contentTintColor = NSColor.white
        } else {
            submitButton.title = "↵"
        }
        containerView.addSubview(submitButton)

        // 布局约束
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            logoImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            logoImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 32),
            logoImageView.heightAnchor.constraint(equalToConstant: 32),

            textField.leadingAnchor.constraint(equalTo: logoImageView.trailingAnchor, constant: 12),
            textField.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

            submitButton.leadingAnchor.constraint(equalTo: textField.trailingAnchor, constant: 8),
            submitButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            submitButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            submitButton.widthAnchor.constraint(equalToConstant: 36),
            submitButton.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    // MARK: - Setup（展开模式）

    private func setupExpandedUI() {
        // 移除基础模式的 UI
        containerView.removeFromSuperview()

        // 创建展开模式容器（白色背景）
        expandedContainerView = NSView()
        expandedContainerView.translatesAutoresizingMaskIntoConstraints = false
        expandedContainerView.wantsLayer = true
        expandedContainerView.layer?.backgroundColor = NSColor.white.cgColor
        expandedContainerView.layer?.cornerRadius = 12
        expandedContainerView.layer?.shadowColor = NSColor.black.cgColor
        expandedContainerView.layer?.shadowOpacity = 0.2
        expandedContainerView.layer?.shadowRadius = 20
        expandedContainerView.layer?.shadowOffset = CGSize(width: 0, height: -5)
        addSubview(expandedContainerView)

        // 标题 "准备做什么?"
        titleLabel = NSTextField(labelWithString: "准备做什么?")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .medium)
        titleLabel.textColor = NSColor.labelColor
        expandedContainerView.addSubview(titleLabel)

        // 分隔线
        let separator1 = createSeparator()
        expandedContainerView.addSubview(separator1)

        // 内容输入区域（多行文本）
        // 使用 NSTextView.scrollableTextView() 来正确创建带滚动视图的文本视图
        contentTextView = NSTextView.scrollableTextView()
        contentTextView.translatesAutoresizingMaskIntoConstraints = false
        contentTextView.hasVerticalScroller = false
        contentTextView.borderType = .noBorder
        contentTextView.drawsBackground = false
        contentTextView.autohidesScrollers = true

        // 获取内部的 NSTextView
        guard let textView = contentTextView.documentView as? NSTextView else {
            fatalError("NSTextView.scrollableTextView() should return NSScrollView with NSTextView as documentView")
        }
        contentTextField = textView
        contentTextField.font = NSFont.systemFont(ofSize: 16)
        contentTextField.textColor = NSColor.black
        contentTextField.backgroundColor = NSColor.clear
        contentTextField.drawsBackground = false
        contentTextField.insertionPointColor = NSColor.black
        contentTextField.isRichText = false
        contentTextField.isEditable = true
        contentTextField.isSelectable = true
        contentTextField.delegate = self

        // 设置文本容器
        contentTextField.textContainer?.containerSize = NSSize(width: 560, height: 10000)
        contentTextField.textContainer?.widthTracksTextView = true
        contentTextField.isHorizontallyResizable = false
        contentTextField.isVerticallyResizable = true

        // 设置输入属性
        contentTextField.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 16),
            .foregroundColor: NSColor.black
        ]

        // 保留基础模式输入的内容
        let previousText = textField.stringValue
        if !previousText.isEmpty {
            let attributedString = NSAttributedString(string: previousText, attributes: [
                .font: NSFont.systemFont(ofSize: 16),
                .foregroundColor: NSColor.black
            ])
            contentTextField.textStorage?.setAttributedString(attributedString)
        }

        expandedContainerView.addSubview(contentTextView)

        // 工具栏（列表、标签、日期、优先级）
        toolbarView = NSView()
        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        expandedContainerView.addSubview(toolbarView)

        // 列表按钮（点击切换任务/笔记模式）
        listButton = createToolbarButton(icon: "list.bullet", title: "列表")
        listButton.target = self
        listButton.action = #selector(listButtonTapped)
        let listGesture = NSClickGestureRecognizer(target: self, action: #selector(listButtonTapped))
        listButton.addGestureRecognizer(listGesture)
        toolbarView.addSubview(listButton)

        // 标签按钮
        tagButton = createToolbarButton(icon: "tag", title: "标签")
        tagButton.target = self
        tagButton.action = #selector(tagButtonTapped)
        let tagGesture = NSClickGestureRecognizer(target: self, action: #selector(tagButtonTapped))
        tagButton.addGestureRecognizer(tagGesture)
        toolbarView.addSubview(tagButton)

        // 日期按钮
        dateButton = createToolbarButton(icon: "calendar", title: "日期")
        dateButton.target = self
        dateButton.action = #selector(dateButtonTapped)
        let dateGesture = NSClickGestureRecognizer(target: self, action: #selector(dateButtonTapped))
        dateButton.addGestureRecognizer(dateGesture)
        toolbarView.addSubview(dateButton)

        // 优先级按钮
        priorityButton = createToolbarButton(icon: "flag", title: "优先级")
        priorityButton.target = self
        priorityButton.action = #selector(priorityButtonTapped)
        let priorityGesture = NSClickGestureRecognizer(target: self, action: #selector(priorityButtonTapped))
        priorityButton.addGestureRecognizer(priorityGesture)
        toolbarView.addSubview(priorityButton)

        // 分隔线
        let separator2 = createSeparator()
        expandedContainerView.addSubview(separator2)

        // 底部栏（清单选择 + 取消/确定按钮）
        footerView = NSView()
        footerView.translatesAutoresizingMaskIntoConstraints = false
        expandedContainerView.addSubview(footerView)

        // 清单选择按钮（可点击下拉）
        listSelectorButton = NSButton()
        listSelectorButton.translatesAutoresizingMaskIntoConstraints = false
        listSelectorButton.bezelStyle = .inline
        listSelectorButton.isBordered = false
        listSelectorButton.title = "收集箱"
        listSelectorButton.font = NSFont.systemFont(ofSize: 14)
        listSelectorButton.target = self
        listSelectorButton.action = #selector(listSelectorTapped)
        listSelectorButton.refusesFirstResponder = true
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            listSelectorButton.image = NSImage(systemSymbolName: "tray", accessibilityDescription: "收集箱")?
                .withSymbolConfiguration(config)
            listSelectorButton.imagePosition = .imageLeading
            listSelectorButton.contentTintColor = NSColor.secondaryLabelColor
        }
        footerView.addSubview(listSelectorButton)

        // 列表图标（已弃用，保留兼容性）
        listIcon = NSImageView()
        listIcon.translatesAutoresizingMaskIntoConstraints = false
        listIcon.isHidden = true
        footerView.addSubview(listIcon)

        // 选中的列表名称（已弃用，使用按钮 title）
        selectedListLabel = NSTextField(labelWithString: "")
        selectedListLabel.translatesAutoresizingMaskIntoConstraints = false
        selectedListLabel.isHidden = true
        footerView.addSubview(selectedListLabel)

        // 取消按钮（自定义样式：灰色边框 + 透明背景）
        cancelButton = NSButton(title: "取消", target: self, action: #selector(cancelTapped))
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.bezelStyle = .regularSquare
        cancelButton.isBordered = false
        cancelButton.wantsLayer = true
        cancelButton.layer?.backgroundColor = NSColor.clear.cgColor
        cancelButton.layer?.borderWidth = 1
        cancelButton.layer?.borderColor = NSColor.separatorColor.cgColor
        cancelButton.layer?.cornerRadius = 6
        let cancelTitle = NSAttributedString(
            string: "取消",
            attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.systemFont(ofSize: 13, weight: .regular)
            ]
        )
        cancelButton.attributedTitle = cancelTitle
        cancelButton.refusesFirstResponder = true
        footerView.addSubview(cancelButton)

        // 确定按钮（自定义样式：琥珀色背景）
        confirmButton = NSButton(title: "确定", target: self, action: #selector(confirmTapped))
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.bezelStyle = .regularSquare
        confirmButton.isBordered = false
        confirmButton.wantsLayer = true
        confirmButton.layer?.backgroundColor = amberColor.cgColor
        confirmButton.layer?.cornerRadius = 6
        let confirmTitle = NSAttributedString(
            string: "确定",
            attributes: [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 13, weight: .medium)
            ]
        )
        confirmButton.attributedTitle = confirmTitle
        confirmButton.refusesFirstResponder = true
        footerView.addSubview(confirmButton)

        // 布局约束
        NSLayoutConstraint.activate([
            expandedContainerView.topAnchor.constraint(equalTo: topAnchor),
            expandedContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            expandedContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            expandedContainerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // 标题
            titleLabel.topAnchor.constraint(equalTo: expandedContainerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: expandedContainerView.leadingAnchor, constant: 20),

            // 分隔线1
            separator1.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            separator1.leadingAnchor.constraint(equalTo: expandedContainerView.leadingAnchor),
            separator1.trailingAnchor.constraint(equalTo: expandedContainerView.trailingAnchor),
            separator1.heightAnchor.constraint(equalToConstant: 1),

            // 内容区域
            contentTextView.topAnchor.constraint(equalTo: separator1.bottomAnchor, constant: 12),
            contentTextView.leadingAnchor.constraint(equalTo: expandedContainerView.leadingAnchor, constant: 20),
            contentTextView.trailingAnchor.constraint(equalTo: expandedContainerView.trailingAnchor, constant: -20),
            contentTextView.heightAnchor.constraint(equalToConstant: 80),

            // 工具栏
            toolbarView.topAnchor.constraint(equalTo: contentTextView.bottomAnchor, constant: 12),
            toolbarView.trailingAnchor.constraint(equalTo: expandedContainerView.trailingAnchor, constant: -20),
            toolbarView.heightAnchor.constraint(equalToConstant: 32),

            // 工具栏按钮
            priorityButton.trailingAnchor.constraint(equalTo: toolbarView.trailingAnchor),
            priorityButton.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),

            dateButton.trailingAnchor.constraint(equalTo: priorityButton.leadingAnchor, constant: -8),
            dateButton.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),

            tagButton.trailingAnchor.constraint(equalTo: dateButton.leadingAnchor, constant: -8),
            tagButton.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),

            listButton.trailingAnchor.constraint(equalTo: tagButton.leadingAnchor, constant: -8),
            listButton.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),

            // 分隔线2
            separator2.topAnchor.constraint(equalTo: toolbarView.bottomAnchor, constant: 12),
            separator2.leadingAnchor.constraint(equalTo: expandedContainerView.leadingAnchor),
            separator2.trailingAnchor.constraint(equalTo: expandedContainerView.trailingAnchor),
            separator2.heightAnchor.constraint(equalToConstant: 1),

            // 底部栏
            footerView.topAnchor.constraint(equalTo: separator2.bottomAnchor),
            footerView.leadingAnchor.constraint(equalTo: expandedContainerView.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: expandedContainerView.trailingAnchor),
            footerView.bottomAnchor.constraint(equalTo: expandedContainerView.bottomAnchor),
            footerView.heightAnchor.constraint(equalToConstant: 56),

            // 底部栏内容 - 清单选择按钮
            listSelectorButton.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 16),
            listSelectorButton.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),

            confirmButton.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -20),
            confirmButton.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
            confirmButton.widthAnchor.constraint(equalToConstant: 64),
            confirmButton.heightAnchor.constraint(equalToConstant: 32),

            cancelButton.trailingAnchor.constraint(equalTo: confirmButton.leadingAnchor, constant: -8),
            cancelButton.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 64),
            cancelButton.heightAnchor.constraint(equalToConstant: 32),
        ])

        // 聚焦到内容输入框
        window?.makeFirstResponder(contentTextField)
    }

    // MARK: - Mode Switching

    /// 切换到展开模式
    func expandToDetailMode() {
        guard !isExpanded else { return }
        isExpanded = true

        // 更新视图大小
        frame = NSRect(x: frame.origin.x, y: frame.origin.y, width: 600, height: expandedHeight)

        // 设置展开模式 UI
        setupExpandedUI()

        // 通知窗口大小变化
        onSizeChange?(expandedHeight)

        print("[QuickAddContentView] 已切换到展开模式")
    }

    /// 切换回基础模式
    func collapseToCompactMode() {
        guard isExpanded else { return }
        isExpanded = false

        // 移除展开模式 UI
        expandedContainerView?.removeFromSuperview()

        // 更新视图大小
        frame = NSRect(x: frame.origin.x, y: frame.origin.y, width: 600, height: compactHeight)

        // 重新设置基础模式 UI
        setupCompactUI()

        // 通知窗口大小变化
        onSizeChange?(compactHeight)

        print("[QuickAddContentView] 已切换回基础模式")
    }

    // MARK: - Helper Methods

    private func createSeparator() -> NSView {
        let separator = NSView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        return separator
    }

    private func createToolbarButton(icon: String, title: String) -> NSButton {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setButtonType(.momentaryLight)
        button.bezelStyle = .inline  // 简洁无边框样式
        button.isBordered = false
        button.title = title
        button.font = NSFont.systemFont(ofSize: 12)
        button.refusesFirstResponder = true
        button.isEnabled = true
        button.wantsLayer = true

        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            button.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)?
                .withSymbolConfiguration(config)
            button.imagePosition = .imageLeading
            button.contentTintColor = NSColor.secondaryLabelColor
        }

        return button
    }

    private func loadAmberLogo() -> NSImage? {
        if let image = NSImage(named: "mosquito_amber") {
            return image
        }
        if let resourcePath = Bundle.main.resourcePath {
            let assetPath = "\(resourcePath)/flutter_assets/assets/images/mosquito_amber.png"
            if let image = NSImage(contentsOfFile: assetPath) {
                return image
            }
        }
        return nil
    }

    // MARK: - Actions

    @objc private func submitTapped() {
        submitTask()
    }

    @objc private func cancelTapped() {
        onCancel?()
    }

    @objc private func confirmTapped() {
        submitExpandedTask()
    }

    /// 列表按钮点击：切换任务/笔记模式
    @objc private func listButtonTapped() {
        isNoteMode = !isNoteMode
        updateModeDisplay()
        print("[QuickAddContentView] 切换到\(isNoteMode ? "笔记" : "任务")模式")
    }

    /// 标签按钮点击：显示下拉菜单
    @objc private func tagButtonTapped() {
        guard let button = tagButton else { return }

        let menu = NSMenu()

        // 使用从 Flutter 传来的动态标签
        let tagsToShow = availableTags.isEmpty ? ["工作", "学习", "生活", "重要", "待办"] : availableTags
        for tag in tagsToShow {
            let item = NSMenuItem(title: tag, action: #selector(tagMenuItemClicked(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = tag
            // 如果已选中，显示勾选
            if selectedTags.contains(tag) {
                item.state = .on
            }
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        // 清除标签
        let clearItem = NSMenuItem(title: "清除标签", action: #selector(clearTagsClicked), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        // 显示菜单
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func tagMenuItemClicked(_ sender: NSMenuItem) {
        guard let tag = sender.representedObject as? String else { return }

        if selectedTags.contains(tag) {
            selectedTags.removeAll { $0 == tag }
        } else {
            selectedTags.append(tag)
        }
        updateTagDisplay()
    }

    @objc private func clearTagsClicked() {
        selectedTags = []
        updateTagDisplay()
    }

    /// 清单选择器点击：显示清单下拉菜单
    @objc private func listSelectorTapped() {
        guard let button = listSelectorButton else { return }

        let menu = NSMenu()

        // 收集箱选项（默认）
        let inboxItem = NSMenuItem(title: "收集箱", action: #selector(listMenuItemClicked(_:)), keyEquivalent: "")
        inboxItem.target = self
        inboxItem.representedObject = nil  // nil 表示收集箱
        if selectedListId == nil && !isNoteMode {
            inboxItem.state = .on
        }
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            inboxItem.image = NSImage(systemSymbolName: "tray", accessibilityDescription: "收集箱")?
                .withSymbolConfiguration(config)
        }
        menu.addItem(inboxItem)

        // 分隔线（如果有清单）
        if !availableTaskLists.isEmpty {
            menu.addItem(NSMenuItem.separator())
        }

        // 从 Flutter 传来的清单列表
        for taskList in availableTaskLists {
            guard let id = taskList["id"], let name = taskList["name"] else { continue }
            let item = NSMenuItem(title: name, action: #selector(listMenuItemClicked(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = ["id": id, "name": name]  // 存储 id 和 name
            if selectedListId == id {
                item.state = .on
            }
            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
                item.image = NSImage(systemSymbolName: "list.bullet", accessibilityDescription: name)?
                    .withSymbolConfiguration(config)
            }
            menu.addItem(item)
        }

        // 显示菜单
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    /// 清单菜单项点击
    @objc private func listMenuItemClicked(_ sender: NSMenuItem) {
        if let listData = sender.representedObject as? [String: String] {
            // 选择了具体清单
            selectedListId = listData["id"]
            selectedListName = listData["name"] ?? "清单"
            isNoteMode = false
        } else {
            // 选择了收集箱
            selectedListId = nil
            selectedListName = "收集箱"
            isNoteMode = false
        }
        updateListSelectorDisplay()
    }

    /// 更新清单选择器显示
    private func updateListSelectorDisplay() {
        guard let button = listSelectorButton else { return }

        if isNoteMode {
            button.title = "笔记"
            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
                button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "笔记")?
                    .withSymbolConfiguration(config)
                button.contentTintColor = amberColor
            }
        } else {
            button.title = selectedListName
            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
                let iconName = selectedListId == nil ? "tray" : "list.bullet"
                button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: selectedListName)?
                    .withSymbolConfiguration(config)
                button.contentTintColor = selectedListId == nil ? NSColor.secondaryLabelColor : amberColor
            }
        }
    }

    /// 日期按钮点击：显示下拉菜单
    @objc private func dateButtonTapped() {
        guard let button = dateButton else { return }

        let menu = NSMenu()

        // 今天
        let todayItem = NSMenuItem(title: "今天", action: #selector(dateMenuItemClicked(_:)), keyEquivalent: "")
        todayItem.target = self
        todayItem.representedObject = Date()
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            todayItem.image = NSImage(systemSymbolName: "sun.max", accessibilityDescription: "今天")?
                .withSymbolConfiguration(config)
        }
        menu.addItem(todayItem)

        // 明天
        let tomorrowItem = NSMenuItem(title: "明天", action: #selector(dateMenuItemClicked(_:)), keyEquivalent: "")
        tomorrowItem.target = self
        tomorrowItem.representedObject = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            tomorrowItem.image = NSImage(systemSymbolName: "sunrise", accessibilityDescription: "明天")?
                .withSymbolConfiguration(config)
        }
        menu.addItem(tomorrowItem)

        // 后天
        let dayAfterItem = NSMenuItem(title: "后天", action: #selector(dateMenuItemClicked(_:)), keyEquivalent: "")
        dayAfterItem.target = self
        dayAfterItem.representedObject = Calendar.current.date(byAdding: .day, value: 2, to: Date())
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            dayAfterItem.image = NSImage(systemSymbolName: "cloud.sun", accessibilityDescription: "后天")?
                .withSymbolConfiguration(config)
        }
        menu.addItem(dayAfterItem)

        // 下周
        let nextWeekItem = NSMenuItem(title: "下周", action: #selector(dateMenuItemClicked(_:)), keyEquivalent: "")
        nextWeekItem.target = self
        nextWeekItem.representedObject = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date())
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            nextWeekItem.image = NSImage(systemSymbolName: "calendar.badge.plus", accessibilityDescription: "下周")?
                .withSymbolConfiguration(config)
        }
        menu.addItem(nextWeekItem)

        menu.addItem(NSMenuItem.separator())

        // 选择日期（日期选择器）
        let pickerItem = NSMenuItem(title: "选择日期...", action: #selector(showDatePicker), keyEquivalent: "")
        pickerItem.target = self
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            pickerItem.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "选择日期")?
                .withSymbolConfiguration(config)
        }
        menu.addItem(pickerItem)

        menu.addItem(NSMenuItem.separator())

        // 清除日期
        let clearItem = NSMenuItem(title: "清除日期", action: #selector(clearDateClicked), keyEquivalent: "")
        clearItem.target = self
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            clearItem.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "清除日期")?
                .withSymbolConfiguration(config)
        }
        menu.addItem(clearItem)

        // 显示菜单
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    /// 显示日期选择器弹窗
    @objc private func showDatePicker() {
        guard self.window != nil else { return }

        // 创建日期选择器
        let datePicker = NSDatePicker()
        datePicker.datePickerStyle = .clockAndCalendar
        datePicker.datePickerElements = .yearMonthDay
        datePicker.dateValue = hasSelectedDate ? selectedDate : Date()
        datePicker.minDate = Date()  // 不能选择过去的日期
        datePicker.sizeToFit()

        // 创建包装视图
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: datePicker.frame.width + 32, height: datePicker.frame.height + 60))
        datePicker.frame.origin = NSPoint(x: 16, y: 48)
        containerView.addSubview(datePicker)

        // 确定按钮
        let okButton = NSButton(title: "确定", target: nil, action: nil)
        okButton.bezelStyle = .rounded
        okButton.frame = NSRect(x: containerView.frame.width - 80, y: 12, width: 64, height: 28)
        containerView.addSubview(okButton)

        // 取消按钮
        let cancelButton = NSButton(title: "取消", target: nil, action: nil)
        cancelButton.bezelStyle = .rounded
        cancelButton.frame = NSRect(x: containerView.frame.width - 150, y: 12, width: 64, height: 28)
        containerView.addSubview(cancelButton)

        // 创建弹窗
        let popover = NSPopover()
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = containerView
        popover.behavior = .semitransient  // 改为 semitransient，点击外部不会自动关闭
        popover.contentSize = containerView.frame.size

        // 设置按钮动作
        okButton.target = self
        okButton.action = #selector(datePickerConfirmed(_:))
        cancelButton.target = self
        cancelButton.action = #selector(datePickerCancelled(_:))

        // 存储 popover 和 datePicker 的引用（使用静态指针作为 key）
        objc_setAssociatedObject(okButton, &QuickAddContentView.datePickerKey, datePicker, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(okButton, &QuickAddContentView.popoverKey, popover, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(cancelButton, &QuickAddContentView.popoverKey, popover, .OBJC_ASSOCIATION_RETAIN)

        // 保存当前 popover 引用（阻止窗口关闭）
        activePopover = popover

        // 显示弹窗
        if let dateButton = self.dateButton {
            popover.show(relativeTo: dateButton.bounds, of: dateButton, preferredEdge: .maxY)
        }
    }

    /// 日期选择器确定
    @objc private func datePickerConfirmed(_ sender: NSButton) {
        print("[QuickAddContentView] datePickerConfirmed 被调用")
        if let datePicker = objc_getAssociatedObject(sender, &QuickAddContentView.datePickerKey) as? NSDatePicker,
           let popover = objc_getAssociatedObject(sender, &QuickAddContentView.popoverKey) as? NSPopover {
            selectedDate = datePicker.dateValue
            hasSelectedDate = true
            updateDateDisplay()
            popover.close()
            activePopover = nil
            print("[QuickAddContentView] 日期已选择: \(selectedDate)")

            // 确定后自动聚焦输入框
            DispatchQueue.main.async { [weak self] in
                self?.focusInput()
            }
        } else {
            print("[QuickAddContentView] datePickerConfirmed: 无法获取 datePicker 或 popover")
        }
    }

    /// 日期选择器取消
    @objc private func datePickerCancelled(_ sender: NSButton) {
        print("[QuickAddContentView] datePickerCancelled 被调用")
        if let popover = objc_getAssociatedObject(sender, &QuickAddContentView.popoverKey) as? NSPopover {
            popover.close()
            activePopover = nil

            // 取消后也自动聚焦输入框
            DispatchQueue.main.async { [weak self] in
                self?.focusInput()
            }
        } else {
            print("[QuickAddContentView] datePickerCancelled: 无法获取 popover")
        }
    }

    @objc private func dateMenuItemClicked(_ sender: NSMenuItem) {
        guard let date = sender.representedObject as? Date else { return }
        selectedDate = date
        hasSelectedDate = true
        updateDateDisplay()
    }

    @objc private func clearDateClicked() {
        hasSelectedDate = false
        updateDateDisplay()
    }

    /// 优先级按钮点击：显示下拉菜单
    @objc private func priorityButtonTapped() {
        guard let button = priorityButton else { return }

        let menu = NSMenu()

        // 优先级选项
        let priorities: [(title: String, value: Int, icon: String)] = [
            ("无", 0, "flag"),
            ("低", 1, "flag"),
            ("中", 2, "flag.fill"),
            ("高", 3, "flag.fill")
        ]

        for priority in priorities {
            let item = NSMenuItem(title: priority.title, action: #selector(priorityMenuItemClicked(_:)), keyEquivalent: "")
            item.target = self
            item.tag = priority.value
            if selectedPriority == priority.value {
                item.state = .on
            }
            menu.addItem(item)
        }

        // 显示菜单
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func priorityMenuItemClicked(_ sender: NSMenuItem) {
        selectedPriority = sender.tag
        updatePriorityDisplay()
    }

    /// 更新标签显示
    private func updateTagDisplay() {
        if #available(macOS 11.0, *) {
            if selectedTags.isEmpty {
                tagButton?.title = "标签"
                tagButton?.contentTintColor = NSColor.secondaryLabelColor
            } else {
                tagButton?.title = selectedTags.joined(separator: ", ")
                tagButton?.contentTintColor = amberColor
            }
        }
    }

    /// 更新日期显示
    private func updateDateDisplay() {
        if #available(macOS 11.0, *) {
            if hasSelectedDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "M月d日"
                dateButton?.title = formatter.string(from: selectedDate)
                dateButton?.contentTintColor = amberColor
            } else {
                dateButton?.title = "日期"
                dateButton?.contentTintColor = NSColor.secondaryLabelColor
            }
        }
    }

    /// 更新优先级显示
    private func updatePriorityDisplay() {
        if #available(macOS 11.0, *) {
            let priorityInfo: (icon: String, title: String, color: NSColor) = {
                switch selectedPriority {
                case 1: return ("flag", "低", NSColor.systemGreen)
                case 2: return ("flag.fill", "中", NSColor.systemOrange)
                case 3: return ("flag.fill", "高", NSColor.systemRed)
                default: return ("flag", "优先级", NSColor.secondaryLabelColor)
                }
            }()

            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            priorityButton?.image = NSImage(systemSymbolName: priorityInfo.icon, accessibilityDescription: priorityInfo.title)?
                .withSymbolConfiguration(config)
            priorityButton?.title = priorityInfo.title
            priorityButton?.contentTintColor = priorityInfo.color
        }
    }

    /// 更新模式显示（任务/笔记）
    private func updateModeDisplay() {
        // 更新标题和列表按钮
        if isNoteMode {
            titleLabel?.stringValue = "记录想法..."
            // 更新列表按钮为"笔记"样式
            listButton?.title = "笔记"
            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
                listButton?.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "笔记")?
                    .withSymbolConfiguration(config)
            }
            listButton?.contentTintColor = amberColor
        } else {
            titleLabel?.stringValue = "准备做什么?"
            // 恢复列表按钮为"列表"样式
            listButton?.title = "列表"
            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
                listButton?.image = NSImage(systemSymbolName: "list.bullet", accessibilityDescription: "列表")?
                    .withSymbolConfiguration(config)
            }
            listButton?.contentTintColor = NSColor.secondaryLabelColor
        }

        // 更新底部清单选择器
        updateListSelectorDisplay()
    }

    private func submitTask() {
        let title = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        // 基础模式：只有标题，其他都是默认值，listId 为 nil（收集箱）
        onSubmit?(title, selectedDate, false, false, 0, [], nil)
    }

    private func submitExpandedTask() {
        guard let textView = contentTextField else { return }
        let title = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        // 展开模式：传递所有数据，包括选中的清单 ID
        onSubmit?(title, selectedDate, hasSelectedDate, isNoteMode, selectedPriority, selectedTags, selectedListId)
    }

    // MARK: - Public Methods

    func focusInput() {
        if isExpanded {
            window?.makeFirstResponder(contentTextField)
        } else {
            window?.makeFirstResponder(textField)
        }
    }

    /// 检查是否有 popover 打开（用于阻止窗口关闭）
    func hasActivePopover() -> Bool {
        // 只检查 activePopover 是否存在，不检查 isShown
        // 因为点击 NSDatePicker 内部时 isShown 可能暂时返回 false
        return activePopover != nil
    }

    /// 获取当前打开的 popover（用于检测点击位置）
    func getActivePopover() -> NSPopover? {
        return activePopover
    }

    func clearInput() {
        textField?.stringValue = ""
        contentTextField?.string = ""
    }

    /// 重置到基础模式（不触发回调，用于隐藏窗口时重置）
    func resetToCompactMode() {
        guard isExpanded else { return }
        isExpanded = false

        // 重置所有状态
        isNoteMode = false
        selectedPriority = 0
        selectedTags = []
        hasSelectedDate = false
        selectedListId = nil
        selectedListName = "收集箱"

        // 移除展开模式 UI
        expandedContainerView?.removeFromSuperview()

        // 更新视图大小
        frame = NSRect(x: frame.origin.x, y: frame.origin.y, width: 600, height: compactHeight)

        // 重新设置基础模式 UI
        setupCompactUI()

        print("[QuickAddContentView] 已重置到基础模式")
    }

    // MARK: - Keyboard Handling

    override func keyDown(with event: NSEvent) {
        // ESC 键取消
        if event.keyCode == 53 {
            onCancel?()
            return
        }

        super.keyDown(with: event)
    }
}

// MARK: - NSTextFieldDelegate

extension QuickAddContentView: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline(_:)) {
            // Enter 键提交
            submitTask()
            return true
        } else if commandSelector == #selector(cancelOperation(_:)) {
            // ESC 键取消
            onCancel?()
            return true
        } else if commandSelector == #selector(insertTab(_:)) {
            // Tab 键展开详情模式
            expandToDetailMode()
            return true
        }
        return false
    }
}

// MARK: - NSTextViewDelegate

extension QuickAddContentView: NSTextViewDelegate {
    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(cancelOperation(_:)) {
            // ESC 键取消
            onCancel?()
            return true
        }
        return false
    }
}

// MARK: - Mouse Event Handling

extension QuickAddContentView {
    /// 重写 mouseDown 来手动处理按钮点击
    /// 因为 nonactivatingPanel 会阻止 NSButton 正常接收事件
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        // 检查是否点击了工具栏按钮（仅展开模式）
        if isExpanded {
            if let button = listButton, button.frame.contains(toolbarView.convert(location, from: self)) {
                listButtonTapped()
                return
            }
            if let button = tagButton, button.frame.contains(toolbarView.convert(location, from: self)) {
                tagButtonTapped()
                return
            }
            if let button = dateButton, button.frame.contains(toolbarView.convert(location, from: self)) {
                dateButtonTapped()
                return
            }
            if let button = priorityButton, button.frame.contains(toolbarView.convert(location, from: self)) {
                priorityButtonTapped()
                return
            }
            // 检查底部栏清单选择按钮
            if let button = listSelectorButton, button.frame.contains(footerView.convert(location, from: self)) {
                listSelectorTapped()
                return
            }
        }

        super.mouseDown(with: event)
    }
}
