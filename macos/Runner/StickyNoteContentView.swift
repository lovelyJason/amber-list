import Cocoa

/// 便签内容视图
/// 包含标题栏、任务列表、操作按钮等
class StickyNoteContentView: NSView {

    // MARK: - Properties

    private var noteTitle: String
    private var activeTasks: [[String: Any]]
    private var completedTasks: [[String: Any]]
    private var themeColor: NSColor

    var isPinned: Bool = true {
        didSet {
            updatePinButton()
        }
    }

    // MARK: - Callbacks

    var onTaskToggled: ((String, Bool) -> Void)?
    var onPinToggled: (() -> Void)?
    var onColorChanged: ((String) -> Void)?
    var onCloseRequested: (() -> Void)?

    // MARK: - UI Components

    private var headerView: NSView!
    private var titleLabel: NSTextField!
    private var scrollView: NSScrollView!
    private var taskStackView: NSStackView!
    private var pinButton: NSButton!
    private var colorButton: NSButton!
    private var closeButton: NSButton!
    private var colorPickerView: NSStackView?

    // MARK: - 预定义颜色

    private let availableColors: [(hex: String, color: NSColor)] = [
        ("0xFFFFF7D1", NSColor(red: 1.0, green: 0.969, blue: 0.820, alpha: 1.0)),
        ("0xFFE1F5FE", NSColor(red: 0.882, green: 0.961, blue: 0.996, alpha: 1.0)),
        ("0xFFFFEBEE", NSColor(red: 1.0, green: 0.922, blue: 0.933, alpha: 1.0)),
        ("0xFFE8F5E9", NSColor(red: 0.910, green: 0.961, blue: 0.914, alpha: 1.0)),
    ]

    // MARK: - Initialization

    init(title: String, activeTasks: [[String: Any]], completedTasks: [[String: Any]], themeColor: NSColor) {
        self.noteTitle = title
        self.activeTasks = activeTasks
        self.completedTasks = completedTasks
        self.themeColor = themeColor

        // 使用固定 frame 初始化，防止 Auto Layout 计算导致窗口变窄
        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 400))

        // 禁用 autoresizing mask 转换为约束，使用纯 Auto Layout
        self.translatesAutoresizingMaskIntoConstraints = false

        setupUI()
    }

    // 返回固定的 intrinsic size，防止内容影响窗口大小
    override var intrinsicContentSize: NSSize {
        return NSSize(width: 320, height: 400)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = themeColor.cgColor

        setupHeader()
        setupScrollView()
        rebuildTaskList()
    }

    private func setupHeader() {
        headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.02).cgColor
        addSubview(headerView)

        // 标题标签
        let iconLabel = NSTextField(labelWithString: "📝")
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.font = NSFont.systemFont(ofSize: 12)
        headerView.addSubview(iconLabel)

        let appTitleLabel = NSTextField(labelWithString: "琥珀便签")
        appTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        appTitleLabel.font = NSFont.systemFont(ofSize: 12)
        appTitleLabel.textColor = NSColor.secondaryLabelColor
        headerView.addSubview(appTitleLabel)

        // 操作按钮容器
        let buttonStack = NSStackView()
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 4
        headerView.addSubview(buttonStack)

        // 颜色按钮
        colorButton = createIconButton(systemName: "paintpalette", action: #selector(toggleColorPicker))
        colorButton.toolTip = "更换皮肤"
        buttonStack.addArrangedSubview(colorButton)

        // 置顶按钮
        pinButton = createIconButton(systemName: "pin.fill", action: #selector(pinButtonClicked))
        pinButton.toolTip = "固定便签"
        buttonStack.addArrangedSubview(pinButton)

        // 关闭按钮
        closeButton = createIconButton(systemName: "xmark", action: #selector(closeButtonClicked))
        closeButton.toolTip = "关闭"
        buttonStack.addArrangedSubview(closeButton)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: topAnchor),
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 32),

            iconLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
            iconLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            appTitleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 6),
            appTitleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            buttonStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -8),
            buttonStack.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
        ])

        // 便签标题
        titleLabel = NSTextField(labelWithString: noteTitle)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = NSColor.labelColor.withAlphaComponent(0.87)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
        ])
    }

    private func createIconButton(systemName: String, action: Selector) -> NSButton {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .inline
        button.isBordered = false
        button.target = self
        button.action = action

        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            button.image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        } else {
            button.title = systemName == "xmark" ? "×" : (systemName == "pin.fill" ? "📌" : "🎨")
        }

        button.contentTintColor = NSColor.secondaryLabelColor

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 24),
            button.heightAnchor.constraint(equalToConstant: 24),
        ])

        return button
    }

    private func setupScrollView() {
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        addSubview(scrollView)

        // 使用 FlippedView 作为 documentView 的容器
        // 这样内容会从顶部开始排列（macOS 默认是从底部开始）
        let flippedContainer = FlippedView()
        flippedContainer.translatesAutoresizingMaskIntoConstraints = false
        flippedContainer.wantsLayer = true

        taskStackView = NSStackView()
        taskStackView.translatesAutoresizingMaskIntoConstraints = false
        taskStackView.orientation = .vertical
        taskStackView.alignment = .leading
        taskStackView.spacing = 4

        flippedContainer.addSubview(taskStackView)
        scrollView.documentView = flippedContainer

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            // taskStackView 固定在 flippedContainer 顶部
            taskStackView.topAnchor.constraint(equalTo: flippedContainer.topAnchor),
            taskStackView.leadingAnchor.constraint(equalTo: flippedContainer.leadingAnchor),
            taskStackView.trailingAnchor.constraint(equalTo: flippedContainer.trailingAnchor),
            taskStackView.bottomAnchor.constraint(equalTo: flippedContainer.bottomAnchor),

            // flippedContainer 宽度等于 scrollView 内容宽度
            flippedContainer.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])
    }

    private func rebuildTaskList() {
        // 清空现有
        taskStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // 添加活跃任务
        for task in activeTasks {
            let taskView = createTaskRow(task: task, isCompleted: false)
            taskStackView.addArrangedSubview(taskView)
        }

        // 分隔线（如果两者都有内容）
        if !activeTasks.isEmpty && !completedTasks.isEmpty {
            let separator = NSBox()
            separator.boxType = .separator
            separator.translatesAutoresizingMaskIntoConstraints = false
            taskStackView.addArrangedSubview(separator)

            NSLayoutConstraint.activate([
                separator.leadingAnchor.constraint(equalTo: taskStackView.leadingAnchor),
                separator.trailingAnchor.constraint(equalTo: taskStackView.trailingAnchor),
                separator.heightAnchor.constraint(equalToConstant: 1),
            ])
        }

        // 添加已完成任务
        for task in completedTasks {
            let taskView = createTaskRow(task: task, isCompleted: true)
            taskStackView.addArrangedSubview(taskView)
        }

        // 无任务提示
        if activeTasks.isEmpty && completedTasks.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "暂无任务")
            emptyLabel.textColor = NSColor.secondaryLabelColor
            emptyLabel.font = NSFont.systemFont(ofSize: 14)
            taskStackView.addArrangedSubview(emptyLabel)
        }
    }

    private func createTaskRow(task: [String: Any], isCompleted: Bool) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let taskId = task["id"] as? String ?? ""
        let taskTitle = task["title"] as? String ?? ""

        // Checkbox
        let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(checkboxClicked(_:)))
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        checkbox.state = isCompleted ? .on : .off
        checkbox.identifier = NSUserInterfaceItemIdentifier(taskId)
        // 防止 checkbox 被压缩
        checkbox.setContentHuggingPriority(.required, for: .horizontal)
        checkbox.setContentCompressionResistancePriority(.required, for: .horizontal)
        container.addSubview(checkbox)

        // 任务标题
        let titleLabel = NSTextField(labelWithString: taskTitle)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 14)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        // 允许标题被压缩以适应宽度
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        if isCompleted {
            titleLabel.textColor = NSColor.secondaryLabelColor
            // 删除线效果
            let attributedString = NSMutableAttributedString(string: taskTitle)
            attributedString.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: taskTitle.count))
            titleLabel.attributedStringValue = attributedString
        } else {
            titleLabel.textColor = NSColor.labelColor.withAlphaComponent(0.87)
        }

        container.addSubview(titleLabel)

        // 固定容器宽度为 280（窗口宽度 320 - 左右边距各 16 - 滚动条空间 8）
        // 这是解决已完成任务导致窗口变窄的关键！
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 280),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 28),

            checkbox.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            checkbox.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: checkbox.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        return container
    }

    // MARK: - Actions

    @objc private func checkboxClicked(_ sender: NSButton) {
        guard let taskId = sender.identifier?.rawValue else { return }
        let isCompleted = sender.state == .on
        onTaskToggled?(taskId, isCompleted)
    }

    @objc private func pinButtonClicked() {
        onPinToggled?()
    }

    @objc private func closeButtonClicked() {
        onCloseRequested?()
    }

    @objc private func toggleColorPicker() {
        if colorPickerView != nil {
            hideColorPicker()
        } else {
            showColorPicker()
        }
    }

    private func showColorPicker() {
        let pickerStack = NSStackView()
        pickerStack.translatesAutoresizingMaskIntoConstraints = false
        pickerStack.orientation = .horizontal
        pickerStack.spacing = 8
        pickerStack.alignment = .centerY

        for (hex, color) in availableColors {
            // 使用 NSButton 但必须设置空标题，否则会显示 "Bu"
            let colorDot = NSButton()
            colorDot.translatesAutoresizingMaskIntoConstraints = false
            colorDot.title = ""  // 关键：清空标题，否则显示 "Bu"
            colorDot.bezelStyle = .smallSquare
            colorDot.isBordered = false
            colorDot.wantsLayer = true
            colorDot.layer?.backgroundColor = color.cgColor
            colorDot.layer?.cornerRadius = 8
            colorDot.layer?.borderWidth = 1
            colorDot.layer?.borderColor = NSColor.black.withAlphaComponent(0.1).cgColor
            colorDot.target = self
            colorDot.action = #selector(colorDotClicked(_:))
            colorDot.identifier = NSUserInterfaceItemIdentifier(hex)

            NSLayoutConstraint.activate([
                colorDot.widthAnchor.constraint(equalToConstant: 16),
                colorDot.heightAnchor.constraint(equalToConstant: 16),
            ])

            pickerStack.addArrangedSubview(colorDot)
        }

        // 取消按钮
        let cancelButton = createIconButton(systemName: "xmark.circle", action: #selector(hideColorPickerAction))
        cancelButton.contentTintColor = NSColor.secondaryLabelColor
        pickerStack.addArrangedSubview(cancelButton)

        headerView.addSubview(pickerStack)
        colorPickerView = pickerStack

        NSLayoutConstraint.activate([
            pickerStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -8),
            pickerStack.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
        ])

        // 隐藏原有按钮
        colorButton.isHidden = true
        pinButton.isHidden = true
        closeButton.isHidden = true
    }

    @objc private func hideColorPickerAction() {
        hideColorPicker()
    }

    private func hideColorPicker() {
        colorPickerView?.removeFromSuperview()
        colorPickerView = nil

        colorButton.isHidden = false
        pinButton.isHidden = false
        closeButton.isHidden = false
    }

    @objc private func colorDotClicked(_ sender: NSButton) {
        guard let colorHex = sender.identifier?.rawValue else { return }
        hideColorPicker()
        onColorChanged?(colorHex)
    }

    // MARK: - Public Methods

    func updateTasks(active: [[String: Any]], completed: [[String: Any]]) {
        self.activeTasks = active
        self.completedTasks = completed
        rebuildTaskList()
    }

    func updateThemeColor(_ color: NSColor) {
        self.themeColor = color
        layer?.backgroundColor = color.cgColor
    }

    private func updatePinButton() {
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            let symbolName = isPinned ? "pin.fill" : "pin"
            pinButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?.withSymbolConfiguration(config)
            pinButton.contentTintColor = isPinned ? NSColor.systemOrange : NSColor.secondaryLabelColor
        }
        pinButton.toolTip = isPinned ? "取消固定" : "固定便签"
    }
}

// MARK: - FlippedView

/// 翻转坐标系的 NSView
/// macOS 默认坐标系是 Y 轴向上（原点在左下角）
/// 使用 FlippedView 可以让内容从顶部开始排列（原点在左上角）
/// 这样 ScrollView 的内容就不会显示在底部了
class FlippedView: NSView {
    override var isFlipped: Bool {
        return true
    }
}
