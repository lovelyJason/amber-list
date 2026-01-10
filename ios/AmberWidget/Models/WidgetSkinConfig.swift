//
//  WidgetSkinConfig.swift
//  AmberWidget
//
//  小组件皮肤配置
//  5 种预设皮肤：琥珀金、纯净白、深空灰、薄荷绿、樱花粉
//  颜色值与 Android drawable XML 和 Flutter widget_skins.dart 保持一致
//

import SwiftUI
import AppIntents

/// 皮肤类型枚举
enum WidgetSkinType: String, Codable, CaseIterable {
    case amber = "amber"   // 琥珀橙（默认）
    case white = "white"   // 纯净白
    case dark = "dark"     // 深空灰
    case mint = "mint"     // 薄荷绿
    case pink = "pink"     // 樱花粉

    /// 中文显示名称
    var displayName: String {
        switch self {
        case .amber: return "琥珀橙"
        case .white: return "纯净白"
        case .dark: return "深空灰"
        case .mint: return "薄荷绿"
        case .pink: return "樱花粉"
        }
    }
}

/// 皮肤配置结构体
struct WidgetSkinConfig {
    let startColor: Color      // 渐变起始色
    let centerColor: Color     // 渐变中间色
    let endColor: Color        // 渐变结束色
    let textColor: Color       // 主文字颜色（任务标题）
    let secondaryTextColor: Color  // 次要文字颜色（时间、页码）
    let iconColor: Color       // 图标颜色
    let checkboxColor: Color   // 复选框颜色
    let mediumPriorityColor: Color // 中等优先级旗帜颜色（避免与背景撞色）

    /// 背景渐变
    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [startColor, centerColor, endColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// 获取指定皮肤类型的配置
    static func getConfig(for type: WidgetSkinType) -> WidgetSkinConfig {
        switch type {
        case .amber:
            // 琥珀橙 - 品牌色（活力橙色渐变）
            return WidgetSkinConfig(
                startColor: Color(hex: 0xFFE0B2),   // 温暖浅橙
                centerColor: Color(hex: 0xFFB74D), // 活力橙
                endColor: Color(hex: 0xFFA726),    // 深琥珀橙
                textColor: Color(hex: 0x4E342E),   // 深棕色文字
                secondaryTextColor: Color(hex: 0x6D4C41), // 中棕色
                iconColor: Color(hex: 0x4E342E),
                checkboxColor: Color(hex: 0x5D4037),
                mediumPriorityColor: Color(hex: 0x8D6E63)  // 深棕色（比红色弱，在橙色背景上清晰）
            )
        case .white:
            // 纯净白 - 简约风格
            return WidgetSkinConfig(
                startColor: Color(hex: 0xFAFAFA),
                centerColor: Color(hex: 0xF5F5F5),
                endColor: Color(hex: 0xEEEEEE),
                textColor: Color(hex: 0x212121),
                secondaryTextColor: Color(hex: 0x757575),
                iconColor: Color(hex: 0x424242),
                checkboxColor: Color(hex: 0x616161),
                mediumPriorityColor: Color(hex: 0xFB8C00)  // 标准橙色
            )
        case .dark:
            // 深空灰 - 深色主题
            return WidgetSkinConfig(
                startColor: Color(hex: 0x424242),
                centerColor: Color(hex: 0x303030),
                endColor: Color(hex: 0x212121),
                textColor: Color(hex: 0xE0E0E0),
                secondaryTextColor: Color(hex: 0x9E9E9E),
                iconColor: Color(hex: 0xBDBDBD),
                checkboxColor: Color(hex: 0xBDBDBD),
                mediumPriorityColor: Color(hex: 0xFFB74D)  // 亮橙色（深色背景需要更亮）
            )
        case .mint:
            // 薄荷绿 - 清新自然
            return WidgetSkinConfig(
                startColor: Color(hex: 0xB2DFDB),
                centerColor: Color(hex: 0x80CBC4),
                endColor: Color(hex: 0x4DB6AC),
                textColor: Color(hex: 0x1B3B38),
                secondaryTextColor: Color(hex: 0x2E5752),
                iconColor: Color(hex: 0x1B3B38),
                checkboxColor: Color(hex: 0x2E5752),
                mediumPriorityColor: Color(hex: 0xFB8C00)  // 标准橙色
            )
        case .pink:
            // 樱花粉 - 温柔少女（淡雅版，与 Android/Flutter 保持一致）
            return WidgetSkinConfig(
                startColor: Color(hex: 0xFCE4EC),   // 淡粉白
                centerColor: Color(hex: 0xF8BBD9), // 浅樱花粉
                endColor: Color(hex: 0xF48FB1),    // 中等樱花粉
                textColor: Color(hex: 0x4A0D2B),
                secondaryTextColor: Color(hex: 0x6D1B42),
                iconColor: Color(hex: 0x4A0D2B),
                checkboxColor: Color(hex: 0x6D1B42),
                mediumPriorityColor: Color(hex: 0xFB8C00)  // 标准橙色
            )
        }
    }
}

// MARK: - AppIntent 皮肤枚举（用于 Widget 配置界面）

/// 皮肤选择 AppEnum（iOS 17+ Widget 配置界面使用）
enum WidgetSkinAppEnum: String, AppEnum {
    case followApp = "followApp"  // 跟随 App 设置（默认）
    case amber = "amber"
    case white = "white"
    case dark = "dark"
    case mint = "mint"
    case pink = "pink"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "皮肤主题")

    static var caseDisplayRepresentations: [WidgetSkinAppEnum: DisplayRepresentation] = [
        .followApp: DisplayRepresentation(title: "跟随 App", subtitle: "使用 App 设置中的皮肤"),
        .amber: DisplayRepresentation(title: "琥珀橙", subtitle: "活力品牌色"),
        .white: DisplayRepresentation(title: "纯净白", subtitle: "简约风格"),
        .dark: DisplayRepresentation(title: "深空灰", subtitle: "深色主题"),
        .mint: DisplayRepresentation(title: "薄荷绿", subtitle: "清新自然"),
        .pink: DisplayRepresentation(title: "樱花粉", subtitle: "温柔少女")
    ]

    /// 转换为 WidgetSkinType（followApp 返回 nil，需要从 App 设置读取）
    var toSkinType: WidgetSkinType? {
        if self == .followApp {
            return nil
        }
        return WidgetSkinType(rawValue: self.rawValue)
    }
}
