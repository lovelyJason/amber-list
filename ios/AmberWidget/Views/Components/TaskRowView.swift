//
//  TaskRowView.swift
//  AmberWidget
//
//  任务行组件
//  显示复选框、任务标题、优先级标记
//

import SwiftUI
import AppIntents

/// 任务行视图
struct TaskRowView: View {
    let task: WidgetTask
    let skinConfig: WidgetSkinConfig
    let compact: Bool

    init(task: WidgetTask, skinConfig: WidgetSkinConfig, compact: Bool = false) {
        self.task = task
        self.skinConfig = skinConfig
        self.compact = compact
    }

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            // 复选框图标
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: compact ? 14 : 16))
                .foregroundColor(task.isCompleted ? skinConfig.checkboxColor.opacity(0.5) : skinConfig.checkboxColor)

            // 任务标题
            Text(task.title)
                .font(.system(size: compact ? 12 : 13, weight: .medium))
                .foregroundColor(task.isCompleted ? skinConfig.textColor.opacity(0.5) : skinConfig.textColor)
                .lineLimit(1)
                .strikethrough(task.isCompleted, color: skinConfig.textColor.opacity(0.5))

            Spacer()

            // 优先级旗帜（使用皮肤配置的颜色避免撞色）
            if task.hasPriority {
                Image(systemName: "flag.fill")
                    .font(.system(size: compact ? 10 : 12))
                    .foregroundColor(task.priorityColor(for: skinConfig))
            }
        }
        .frame(height: compact ? 20 : 24)
    }
}

/// 任务行视图（分离操作版）
/// 复选框点击切换任务状态，文字点击打开 App
struct TaskRowWithSeparateActions: View {
    let task: WidgetTask
    let skinConfig: WidgetSkinConfig
    let compact: Bool

    init(task: WidgetTask, skinConfig: WidgetSkinConfig, compact: Bool = false) {
        self.task = task
        self.skinConfig = skinConfig
        self.compact = compact
    }

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            // 复选框：点击切换任务状态
            Button(intent: ToggleTaskIntent(taskId: task.id)) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: compact ? 14 : 16))
                    .foregroundColor(task.isCompleted ? skinConfig.checkboxColor.opacity(0.5) : skinConfig.checkboxColor)
            }
            .buttonStyle(.plain)

            // 任务标题：点击打开 App（使用 Link 或默认行为）
            Text(task.title)
                .font(.system(size: compact ? 12 : 13, weight: .medium))
                .foregroundColor(task.isCompleted ? skinConfig.textColor.opacity(0.5) : skinConfig.textColor)
                .lineLimit(1)
                .strikethrough(task.isCompleted, color: skinConfig.textColor.opacity(0.5))

            Spacer()

            // 优先级旗帜（使用皮肤配置的颜色避免撞色）
            if task.hasPriority {
                Image(systemName: "flag.fill")
                    .font(.system(size: compact ? 10 : 12))
                    .foregroundColor(task.priorityColor(for: skinConfig))
            }
        }
        .frame(height: compact ? 20 : 24)
    }
}

/// 空状态视图
struct EmptyStateView: View {
    let skinConfig: WidgetSkinConfig

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 24))
                .foregroundColor(skinConfig.secondaryTextColor.opacity(0.6))

            Text("暂无任务")
                .font(.system(size: 11))
                .foregroundColor(skinConfig.secondaryTextColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

