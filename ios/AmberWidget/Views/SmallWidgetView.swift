//
//  SmallWidgetView.swift
//  AmberWidget
//
//  Small Widget (2x2) 视图
//  显示任务列表，支持皮肤切换和分页
//

import SwiftUI
import WidgetKit
import AppIntents

/// Small Widget Entry
struct SmallWidgetEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTask]
    let currentPage: Int
    let skinType: WidgetSkinType
    let tapTextToComplete: Bool  // 点击文字是否也能完成任务
    let configuration: SmallWidgetConfigurationIntent

    // DEBUG: 自动顺延调试信息（始终存在，仅 DEBUG 模式 UI 显示）
    // Note: Swift doesn't support #if DEBUG inside function argument lists,
    // so we always include these fields but only display them in DEBUG builds
    let debugPostponedCount: Int      // 本次刷新顺延的任务数
    let debugLastCheck: String        // 上次检查时间
    let debugRefreshTime: String      // 本次 timeline 刷新时间
}

/// Small Widget Timeline Provider
struct SmallWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = SmallWidgetEntry
    typealias Intent = SmallWidgetConfigurationIntent

    func placeholder(in context: Context) -> SmallWidgetEntry {
        SmallWidgetEntry(
            date: Date(),
            tasks: [],
            currentPage: 0,
            skinType: .amber,
            tapTextToComplete: true,
            configuration: SmallWidgetConfigurationIntent(),
            debugPostponedCount: -1,
            debugLastCheck: "placeholder",
            debugRefreshTime: "placeholder"
        )
    }

    func snapshot(for configuration: SmallWidgetConfigurationIntent, in context: Context) async -> SmallWidgetEntry {
        let tasks = WidgetDataStore.loadTodayTasks()
        let page = WidgetDataStore.loadCurrentPage(for: .small)
        // 获取有效皮肤：长按配置 > App设置 > 默认琥珀金
        let skinType = getEffectiveSkin(from: configuration)
        let tapTextToComplete = WidgetDataStore.loadTapTextToComplete()
        return SmallWidgetEntry(
            date: Date(),
            tasks: tasks,
            currentPage: page,
            skinType: skinType,
            tapTextToComplete: tapTextToComplete,
            configuration: configuration,
            debugPostponedCount: -1,
            debugLastCheck: "snapshot",
            debugRefreshTime: "snapshot"
        )
    }

    func timeline(for configuration: SmallWidgetConfigurationIntent, in context: Context) async -> Timeline<SmallWidgetEntry> {
        // Execute auto-postpone before loading tasks
        // This ensures overdue tasks are updated to today before display
        let postponedCount = WidgetDatabaseHelper.performAutoPostpone()
        if postponedCount > 0 {
            print("[SmallWidget] Auto-postponed \(postponedCount) overdue tasks to today")
        }

        let tasks = WidgetDataStore.loadTodayTasks()
        let page = WidgetDataStore.loadCurrentPage(for: .small)
        // 获取有效皮肤：长按配置 > App设置 > 默认琥珀金
        let skinType = getEffectiveSkin(from: configuration)
        let tapTextToComplete = WidgetDataStore.loadTapTextToComplete()

        // 获取调试信息（Release 时编译器会优化掉 #if DEBUG 内的 UI，但变量仍需存在）
        let debugLastCheck = WidgetSettingsHelper.getLastCheckDate() ?? "nil"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let debugRefreshTime = timeFormatter.string(from: Date())

        let entry = SmallWidgetEntry(
            date: Date(),
            tasks: tasks,
            currentPage: page,
            skinType: skinType,
            tapTextToComplete: tapTextToComplete,
            configuration: configuration,
            debugPostponedCount: postponedCount,
            debugLastCheck: debugLastCheck,
            debugRefreshTime: debugRefreshTime
        )

        // 30 分钟后刷新
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    /// 获取有效的皮肤设置
    /// 优先级：长按 Widget 配置 > Flutter App 设置 > 默认琥珀金
    private func getEffectiveSkin(from configuration: SmallWidgetConfigurationIntent) -> WidgetSkinType {
        // 如果长按配置选择了"跟随 App"或其他具体皮肤
        if let intentSkin = configuration.skinType.toSkinType {
            // 用户在长按配置中明确选择了具体皮肤（非跟随 App）
            return intentSkin
        }
        // 跟随 App 设置：从 Flutter App 设置读取
        return WidgetDataStore.loadSmallWidgetSkin()
    }
}

/// Small Widget 视图
struct SmallWidgetView: View {
    let entry: SmallWidgetEntry

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

    var body: some View {
        ZStack {
            // 主内容
            VStack(alignment: .leading, spacing: 6) {
                // Header: 任务数量 + 翻页按钮
                HStack(spacing: 4) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 11))
                        .foregroundColor(skinConfig.iconColor)

                    Text("\(incompleteTasks.count)项待办")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(skinConfig.textColor)
                        .lineLimit(1)

                    Spacer()

                    // 页码和翻页按钮（多页时显示）
                    if totalPages > 1 {
                        Text("\(currentPage + 1)/\(totalPages)")
                            .font(.system(size: 9))
                            .foregroundColor(skinConfig.secondaryTextColor)

                        Button(intent: SmallNextPageIntent()) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(skinConfig.secondaryTextColor)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()
                    .background(skinConfig.secondaryTextColor.opacity(0.3))
                    .padding(.horizontal, -4)  // 分隔线延伸到边缘

                // 任务列表或空状态
                if incompleteTasks.isEmpty {
                    EmptyStateView(skinConfig: skinConfig)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
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
                    .padding(.horizontal, -4)  // 任务列表左右延伸
                    Spacer()
                }
            }
            .padding(.horizontal, 12)  // 左右间距
            .padding(.vertical, 12)

            // DEBUG: 调试信息覆盖层（放在顶部，避免被底部遮挡）
            // 已验证 iOS Widget 自动顺延功能正常，暂时注释掉调试 UI
            // 如需再次调试，取消下面的注释即可
            /*
            #if DEBUG
            VStack {
                Spacer()
                    .frame(height: 8)  // 顶部留一点空间
                VStack(spacing: 2) {
                    // 第一行：P 顺延数量
                    Text("P:\(entry.debugPostponedCount)")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundColor(.yellow)
                    // 第二行：L 上次检查 / R 本次刷新
                    HStack(spacing: 6) {
                        Text("L:\(String(entry.debugLastCheck.suffix(8)))")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                        Text("R:\(entry.debugRefreshTime)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.85))
                .cornerRadius(6)
                Spacer()
            }
            #endif
            */
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

/// Small Widget 定义
struct SmallAmberWidget: Widget {
    let kind: String = "SmallAmberWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SmallWidgetConfigurationIntent.self,
            provider: SmallWidgetProvider()
        ) { entry in
            SmallWidgetView(entry: entry)
        }
        .configurationDisplayName("琥珀清单")
        .description("显示今日任务，支持皮肤切换")
        .supportedFamilies([.systemSmall])
    }
}
