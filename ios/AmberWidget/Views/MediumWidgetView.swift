//
//  MediumWidgetView.swift
//  AmberWidget
//
//  Medium Widget (4x2) 视图
//  左侧显示日期，右侧显示任务列表
//  支持皮肤切换：长按配置 > App设置 > 默认琥珀金
//

import SwiftUI
import WidgetKit
import AppIntents

/// Medium Widget Entry
struct MediumWidgetEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTask]
    let currentPage: Int
    let skinType: WidgetSkinType
    let tapTextToComplete: Bool  // 点击文字是否也能完成任务
    let configuration: MediumWidgetConfigurationIntent
}

/// Medium Widget Timeline Provider
struct MediumWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = MediumWidgetEntry
    typealias Intent = MediumWidgetConfigurationIntent

    func placeholder(in context: Context) -> MediumWidgetEntry {
        MediumWidgetEntry(
            date: Date(),
            tasks: [],
            currentPage: 0,
            skinType: .amber,
            tapTextToComplete: true,
            configuration: MediumWidgetConfigurationIntent()
        )
    }

    func snapshot(for configuration: MediumWidgetConfigurationIntent, in context: Context) async -> MediumWidgetEntry {
        let tasks = WidgetDataStore.loadTodayTasks()
        let page = WidgetDataStore.loadCurrentPage(for: .medium)
        let skinType = getEffectiveSkin(from: configuration)
        let tapTextToComplete = WidgetDataStore.loadTapTextToComplete()
        return MediumWidgetEntry(
            date: Date(),
            tasks: tasks,
            currentPage: page,
            skinType: skinType,
            tapTextToComplete: tapTextToComplete,
            configuration: configuration
        )
    }

    func timeline(for configuration: MediumWidgetConfigurationIntent, in context: Context) async -> Timeline<MediumWidgetEntry> {
        // Execute auto-postpone before loading tasks
        // This ensures overdue tasks are updated to today before display
        let postponedCount = WidgetDatabaseHelper.performAutoPostpone()
        if postponedCount > 0 {
            print("[MediumWidget] Auto-postponed \(postponedCount) overdue tasks to today")
        }

        let tasks = WidgetDataStore.loadTodayTasks()
        let page = WidgetDataStore.loadCurrentPage(for: .medium)
        let skinType = getEffectiveSkin(from: configuration)
        let tapTextToComplete = WidgetDataStore.loadTapTextToComplete()

        let entry = MediumWidgetEntry(
            date: Date(),
            tasks: tasks,
            currentPage: page,
            skinType: skinType,
            tapTextToComplete: tapTextToComplete,
            configuration: configuration
        )

        // 30 分钟后刷新
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    /// 获取有效的皮肤设置
    /// 优先级：长按 Widget 配置 > Flutter App 设置 > 默认琥珀金
    private func getEffectiveSkin(from configuration: MediumWidgetConfigurationIntent) -> WidgetSkinType {
        // 如果长按配置选择了具体皮肤（非跟随 App），优先使用
        if let intentSkin = configuration.skinType.toSkinType {
            return intentSkin
        }
        // 跟随 App 设置：从 Flutter App 设置读取
        return WidgetDataStore.loadMediumWidgetSkin()
    }
}

/// Medium Widget 视图
struct MediumWidgetView: View {
    let entry: MediumWidgetEntry

    private let tasksPerPage = 5

    private var skinConfig: WidgetSkinConfig {
        WidgetSkinConfig.getConfig(for: entry.skinType)
    }

    private var incompleteTasks: [WidgetTask] {
        entry.tasks.filter { !$0.isCompleted }
    }

    private var totalPages: Int {
        max(1, (incompleteTasks.count + tasksPerPage - 1) / tasksPerPage)
    }

    private var currentPage: Int {
        min(entry.currentPage, totalPages - 1)
    }

    private var pageTasks: [WidgetTask] {
        let startIndex = currentPage * tasksPerPage
        return Array(incompleteTasks.dropFirst(startIndex).prefix(tasksPerPage))
    }

    // 日期信息
    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter.string(from: entry.date)
    }

    private var monthString: String {
        let month = Calendar.current.component(.month, from: entry.date)
        return "\(month)月"
    }

    private var weekdayString: String {
        let weekdays = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
        let weekday = Calendar.current.component(.weekday, from: entry.date)
        return weekdays[weekday - 1]
    }

    private var lunarString: String {
        let lunar = ChineseCalendar.getLunarDate(from: entry.date)
        return "\(lunar.month)\(lunar.day)"
    }

    var body: some View {
        HStack(spacing: 0) {
            // 左侧：日期信息
            VStack(spacing: 4) {
                // 日期数字（大）
                Text(dayString)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(skinConfig.iconColor)

                // 月份胶囊
                Text(monthString)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(skinConfig.startColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(skinConfig.textColor)
                    .cornerRadius(10)

                // 农历
                Text(lunarString)
                    .font(.system(size: 10))
                    .foregroundColor(skinConfig.secondaryTextColor)

                // 星期
                Text(weekdayString)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(skinConfig.textColor)
            }
            .frame(width: 80)
            .padding(.vertical, 12)

            // 分隔线
            Rectangle()
                .fill(skinConfig.secondaryTextColor.opacity(0.3))
                .frame(width: 1)
                .padding(.vertical, 12)

            // 右侧：任务列表
            VStack(alignment: .leading, spacing: 6) {
                // Header: 待办数量 + 翻页按钮
                HStack(spacing: 4) {
                    Text("待办 \(incompleteTasks.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(skinConfig.textColor)
                        .lineLimit(1)

                    Spacer()

                    // 页码和翻页按钮（多页时显示）
                    if totalPages > 1 {
                        Text("\(currentPage + 1)/\(totalPages)")
                            .font(.system(size: 9))
                            .foregroundColor(skinConfig.secondaryTextColor)

                        Button(intent: MediumNextPageIntent()) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(skinConfig.secondaryTextColor)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                // 任务列表或空状态
                if incompleteTasks.isEmpty {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 20))
                                .foregroundColor(skinConfig.secondaryTextColor.opacity(0.6))
                            Text("暂无任务")
                                .font(.system(size: 11))
                                .foregroundColor(skinConfig.secondaryTextColor)
                        }
                        Spacer()
                    }
                    Spacer()
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(pageTasks) { task in
                            if entry.tapTextToComplete {
                                // 点击整行都能切换任务状态
                                Button(intent: ToggleTaskIntent(taskId: task.id)) {
                                    TaskRowView(task: task, skinConfig: skinConfig, compact: true)
                                }
                                .buttonStyle(.plain)
                            } else {
                                // 只有点击复选框才能切换，点击文字打开 App
                                TaskRowWithSeparateActions(task: task, skinConfig: skinConfig, compact: true)
                            }
                        }
                    }
                    Spacer()
                }
            }
            .padding(12)
        }
        .containerBackground(for: .widget) {
            if let bgName = skinConfig.backgroundImageName {
                Image(bgName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                skinConfig.backgroundGradient
            }
        }
    }
}

/// Medium Widget 定义
struct MediumAmberWidget: Widget {
    let kind: String = "MediumAmberWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: MediumWidgetConfigurationIntent.self,
            provider: MediumWidgetProvider()
        ) { entry in
            MediumWidgetView(entry: entry)
        }
        .configurationDisplayName("琥珀清单 - 中")
        .description("显示日期和任务列表，支持皮肤切换")
        .supportedFamilies([.systemMedium])
    }
}
