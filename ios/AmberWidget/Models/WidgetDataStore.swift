//
//  WidgetDataStore.swift
//  AmberWidget
//
//  Widget 数据存储管理
//  优先使用 SQLite 数据库直接读写，UserDefaults 仅用于配置存储
//

import Foundation
import WidgetKit

/// Widget 数据存储管理
/// 通过 App Group 共享目录直接访问 SQLite 数据库
class WidgetDataStore {

    // MARK: - Constants

    /// App Group ID（必须与 Flutter HomeWidgetService 和 Xcode 配置一致，大小写敏感！）
    private static let appGroupID = "group.com.amberlist.amberList"

    /// SharedPreferences Keys（仅用于配置，不再用于任务数据）
    private static let keySmallWidgetSkin = "widget_small_skin"
    private static let keyMediumWidgetSkin = "widget_medium_skin"
    private static let keyLargeWidgetSkin = "widget_large_skin"
    private static let keySmallWidgetPage = "small_widget_page"
    private static let keyMediumWidgetPage = "medium_widget_page"
    private static let keyLargeWidgetMonthOffset = "large_widget_month_offset"
    private static let keyTapTextToComplete = "widget_tap_text_to_complete"

    // MARK: - UserDefaults Access

    /// 获取共享 UserDefaults（仅用于配置存储）
    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: - Task Data (SQLite Direct Access)

    /// 加载任务列表
    /// 直接从 SQLite 数据库读取
    static func loadTasks() -> [WidgetTask] {
        // 检查数据库是否存在
        if WidgetDatabaseHelper.databaseExists() {
            return WidgetDatabaseHelper.loadTasks()
        }
        print("[WidgetDataStore] Database not found, returning empty tasks")
        return []
    }

    /// 获取未完成的任务
    static func loadIncompleteTasks() -> [WidgetTask] {
        if WidgetDatabaseHelper.databaseExists() {
            return WidgetDatabaseHelper.loadIncompleteTasks()
        }
        return []
    }

    /// 获取今日任务
    static func loadTodayTasks() -> [WidgetTask] {
        if WidgetDatabaseHelper.databaseExists() {
            return WidgetDatabaseHelper.loadTodayTasks()
        }
        return []
    }

    // MARK: - Task Toggle (SQLite Direct Action)

    /// 切换任务完成状态
    /// 直接更新 SQLite 数据库，无需中转队列
    static func toggleTaskCompletion(taskId: String) {
        print("[WidgetDataStore] toggleTaskCompletion called with taskId: \(taskId)")

        let dbExists = WidgetDatabaseHelper.databaseExists()
        print("[WidgetDataStore] Database exists: \(dbExists)")

        if dbExists {
            let success = WidgetDatabaseHelper.toggleTaskCompletion(taskId: taskId)
            if success {
                print("[WidgetDataStore] Task \(taskId) toggled in SQLite - SUCCESS")
            } else {
                print("[WidgetDataStore] Task \(taskId) toggle FAILED in SQLite")
            }
        } else {
            print("[WidgetDataStore] Database not found, cannot toggle task")
        }
    }

    // MARK: - Skin Settings (UserDefaults)

    /// 加载 Small Widget 皮肤设置（从 Flutter App 存储的 UserDefaults 读取）
    static func loadSmallWidgetSkin() -> WidgetSkinType {
        guard let defaults = sharedDefaults,
              let skinName = defaults.string(forKey: keySmallWidgetSkin) else {
            return .amber  // 默认琥珀金
        }
        return WidgetSkinType(rawValue: skinName) ?? .amber
    }

    /// 加载 Medium Widget 皮肤设置（从 Flutter App 存储的 UserDefaults 读取）
    static func loadMediumWidgetSkin() -> WidgetSkinType {
        guard let defaults = sharedDefaults,
              let skinName = defaults.string(forKey: keyMediumWidgetSkin) else {
            return .amber  // 默认琥珀金
        }
        return WidgetSkinType(rawValue: skinName) ?? .amber
    }

    /// 加载 Large Widget 皮肤设置（从 Flutter App 存储的 UserDefaults 读取）
    static func loadLargeWidgetSkin() -> WidgetSkinType {
        guard let defaults = sharedDefaults,
              let skinName = defaults.string(forKey: keyLargeWidgetSkin) else {
            return .amber  // 默认琥珀金
        }
        return WidgetSkinType(rawValue: skinName) ?? .amber
    }

    /// 保存 Small Widget 皮肤设置
    static func saveSmallWidgetSkin(_ skin: WidgetSkinType) {
        sharedDefaults?.set(skin.rawValue, forKey: keySmallWidgetSkin)
    }

    /// 保存 Medium Widget 皮肤设置
    static func saveMediumWidgetSkin(_ skin: WidgetSkinType) {
        sharedDefaults?.set(skin.rawValue, forKey: keyMediumWidgetSkin)
    }

    /// 保存 Large Widget 皮肤设置
    static func saveLargeWidgetSkin(_ skin: WidgetSkinType) {
        sharedDefaults?.set(skin.rawValue, forKey: keyLargeWidgetSkin)
    }

    // MARK: - Tap Behavior Settings (UserDefaults)

    /// 加载"点击文字完成任务"设置
    /// - Returns: true 表示点击文字也能切换任务状态，false 表示只有点击复选框才能切换
    static func loadTapTextToComplete() -> Bool {
        guard let defaults = sharedDefaults else { return true }  // 默认开启
        // 检查 key 是否存在，不存在则返回默认值 true
        if defaults.object(forKey: keyTapTextToComplete) == nil {
            return true
        }
        return defaults.bool(forKey: keyTapTextToComplete)
    }

    // MARK: - Pagination (UserDefaults)

    /// Widget 尺寸枚举
    enum WidgetSize {
        case small, medium, large
    }

    /// 加载当前页码
    static func loadCurrentPage(for size: WidgetSize) -> Int {
        guard let defaults = sharedDefaults else { return 0 }
        let key = size == .small ? keySmallWidgetPage : keyMediumWidgetPage
        return defaults.integer(forKey: key)
    }

    /// 保存当前页码
    static func saveCurrentPage(_ page: Int, for size: WidgetSize) {
        guard let defaults = sharedDefaults else { return }
        let key = size == .small ? keySmallWidgetPage : keyMediumWidgetPage
        defaults.set(page, forKey: key)
    }

    // MARK: - Large Widget Calendar (UserDefaults)

    /// 加载月份偏移量（0=当前月，-1=上月，1=下月）
    static func loadMonthOffset() -> Int {
        sharedDefaults?.integer(forKey: keyLargeWidgetMonthOffset) ?? 0
    }

    /// 保存月份偏移量
    static func saveMonthOffset(_ offset: Int) {
        sharedDefaults?.set(offset, forKey: keyLargeWidgetMonthOffset)
    }

    // MARK: - Widget Refresh

    /// 刷新所有 Widget
    static func reloadAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 刷新指定 Widget
    static func reloadWidget(kind: String) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
}
