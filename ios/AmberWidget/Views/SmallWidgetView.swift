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
            configuration: SmallWidgetConfigurationIntent()
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
            configuration: configuration
        )
    }

    func timeline(for configuration: SmallWidgetConfigurationIntent, in context: Context) async -> Timeline<SmallWidgetEntry> {
        let tasks = WidgetDataStore.loadTodayTasks()
        let page = WidgetDataStore.loadCurrentPage(for: .small)
        // 获取有效皮肤：长按配置 > App设置 > 默认琥珀金
        let skinType = getEffectiveSkin(from: configuration)
        let tapTextToComplete = WidgetDataStore.loadTapTextToComplete()

        let entry = SmallWidgetEntry(
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
        .containerBackground(for: .widget) {
            skinConfig.backgroundGradient
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
        .contentMarginsDisabled()  // 禁用 iOS 17+ 系统默认边距，使用自定义 padding
    }
}
