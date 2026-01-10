//
//  WidgetTask.swift
//  AmberWidget
//
//  任务数据模型
//  从 App Group UserDefaults 解析 JSON 数据
//

import Foundation
import SwiftUI

/// Widget 任务模型
/// 字段与 Flutter HomeWidgetService 序列化格式一致
struct WidgetTask: Codable, Identifiable {
    let id: String
    let title: String
    let isCompleted: Bool
    let priority: Int           // 0=无, 1=低, 2=中, 3=高
    let dueDate: Int64?         // millisecondsSinceEpoch
    let dueTime: String?        // "YYYY-MM-DD" 格式（用于日历标记）
    let dueTimeDisplay: String? // "HH:mm" 格式（用于显示）

    /// 优先级颜色（默认）
    var priorityColor: Color {
        switch priority {
        case 3: return Color(hex: 0xE53935)  // 高 - 红色
        case 2: return Color(hex: 0xFB8C00)  // 中 - 橙色
        case 1: return Color(hex: 0x43A047)  // 低 - 绿色
        default: return Color(hex: 0x9E9E9E) // 无 - 灰色
        }
    }

    /// 根据皮肤配置获取优先级颜色
    /// 中等优先级颜色会根据皮肤背景色调整，避免撞色
    func priorityColor(for skinConfig: WidgetSkinConfig) -> Color {
        switch priority {
        case 3: return Color(hex: 0xE53935)  // 高 - 红色（所有皮肤一致）
        case 2: return skinConfig.mediumPriorityColor  // 中 - 根据皮肤调整
        case 1: return Color(hex: 0x43A047)  // 低 - 绿色（所有皮肤一致）
        default: return Color(hex: 0x9E9E9E) // 无 - 灰色
        }
    }

    /// 是否有优先级标记
    var hasPriority: Bool {
        priority > 0
    }

    /// 解析截止日期
    var dueDateValue: Date? {
        guard let timestamp = dueDate else { return nil }
        return Date(timeIntervalSince1970: Double(timestamp) / 1000.0)
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: Int, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
