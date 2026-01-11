//
//  AppIntent.swift
//  AmberWidget
//
//  Widget 配置和交互 Intent
//  包含：皮肤选择、翻页、月历导航等 AppIntent
//

import WidgetKit
import AppIntents

// MARK: - Small Widget 皮肤配置 Intent

/// Small Widget 配置 Intent（用于 Widget 编辑界面选择皮肤）
/// 注意：Small Widget 不支持撞色皮肤（背景图渲染有问题），使用 SmallWidgetSkinAppEnum
struct SmallWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "小组件设置"
    static var description = IntentDescription("选择小组件的皮肤主题")

    @Parameter(title: "皮肤主题", default: .followApp)
    var skinType: SmallWidgetSkinAppEnum

    init(skinType: SmallWidgetSkinAppEnum = .followApp) {
        self.skinType = skinType
    }

    init() {
        self.skinType = .followApp
    }
}

// MARK: - Medium Widget 皮肤配置 Intent

/// Medium Widget 配置 Intent（用于 Widget 编辑界面选择皮肤）
struct MediumWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "中组件设置"
    static var description = IntentDescription("选择中组件的皮肤主题")

    @Parameter(title: "皮肤主题", default: .followApp)
    var skinType: WidgetSkinAppEnum

    init(skinType: WidgetSkinAppEnum = .followApp) {
        self.skinType = skinType
    }

    init() {
        self.skinType = .followApp
    }
}

// MARK: - Large Widget 皮肤配置 Intent

/// Large Widget 配置 Intent（用于 Widget 编辑界面选择皮肤）
struct LargeWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "大组件设置"
    static var description = IntentDescription("选择大组件的皮肤主题")

    @Parameter(title: "皮肤主题", default: .followApp)
    var skinType: WidgetSkinAppEnum

    init(skinType: WidgetSkinAppEnum = .followApp) {
        self.skinType = skinType
    }

    init() {
        self.skinType = .followApp
    }
}

// MARK: - 翻页 Intent（iOS 17+ Widget 内交互）

/// Small Widget 翻页 Intent
struct SmallNextPageIntent: AppIntent {
    static var title: LocalizedStringResource = "下一页"
    static var description = IntentDescription("切换到下一页任务")

    func perform() async throws -> some IntentResult {
        let tasks = WidgetDataStore.loadIncompleteTasks()
        let tasksPerPage = 5
        let totalPages = max(1, (tasks.count + tasksPerPage - 1) / tasksPerPage)

        var currentPage = WidgetDataStore.loadCurrentPage(for: .small)
        currentPage = (currentPage + 1) % totalPages
        WidgetDataStore.saveCurrentPage(currentPage, for: .small)

        // 刷新 Widget
        WidgetDataStore.reloadWidget(kind: "SmallAmberWidget")

        return .result()
    }
}

/// Medium Widget 翻页 Intent
struct MediumNextPageIntent: AppIntent {
    static var title: LocalizedStringResource = "下一页"
    static var description = IntentDescription("切换到下一页任务")

    func perform() async throws -> some IntentResult {
        let tasks = WidgetDataStore.loadIncompleteTasks()
        let tasksPerPage = 5
        let totalPages = max(1, (tasks.count + tasksPerPage - 1) / tasksPerPage)

        var currentPage = WidgetDataStore.loadCurrentPage(for: .medium)
        currentPage = (currentPage + 1) % totalPages
        WidgetDataStore.saveCurrentPage(currentPage, for: .medium)

        // 刷新 Widget
        WidgetDataStore.reloadWidget(kind: "MediumAmberWidget")

        return .result()
    }
}

// MARK: - Large Widget 月历导航 Intent

/// 上一个月 Intent
struct PrevMonthIntent: AppIntent {
    static var title: LocalizedStringResource = "上一月"
    static var description = IntentDescription("切换到上一个月")

    func perform() async throws -> some IntentResult {
        var offset = WidgetDataStore.loadMonthOffset()
        offset -= 1
        WidgetDataStore.saveMonthOffset(offset)
        WidgetDataStore.reloadWidget(kind: "LargeAmberWidget")
        return .result()
    }
}

/// 下一个月 Intent
struct NextMonthIntent: AppIntent {
    static var title: LocalizedStringResource = "下一月"
    static var description = IntentDescription("切换到下一个月")

    func perform() async throws -> some IntentResult {
        var offset = WidgetDataStore.loadMonthOffset()
        offset += 1
        WidgetDataStore.saveMonthOffset(offset)
        WidgetDataStore.reloadWidget(kind: "LargeAmberWidget")
        return .result()
    }
}

/// 返回今天 Intent
struct TodayIntent: AppIntent {
    static var title: LocalizedStringResource = "今天"
    static var description = IntentDescription("返回当前月份")

    func perform() async throws -> some IntentResult {
        WidgetDataStore.saveMonthOffset(0)
        WidgetDataStore.reloadWidget(kind: "LargeAmberWidget")
        return .result()
    }
}

// MARK: - 任务勾选 Intent

/// 切换任务完成状态 Intent
/// 在 Widget 上点击任务时触发，直接更新 UserDefaults 中的任务状态
struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "切换任务状态"
    static var description = IntentDescription("标记任务为完成或未完成")

    /// 任务 ID
    @Parameter(title: "任务ID")
    var taskId: String

    init() {
        self.taskId = ""
    }

    init(taskId: String) {
        self.taskId = taskId
    }

    func perform() async throws -> some IntentResult {
        print("[ToggleTaskIntent] perform() called with taskId: \(taskId)")

        // 切换任务状态
        WidgetDataStore.toggleTaskCompletion(taskId: taskId)

        // 刷新所有 Widget
        WidgetDataStore.reloadAllWidgets()

        print("[ToggleTaskIntent] completed, widgets reloaded")
        return .result()
    }
}
