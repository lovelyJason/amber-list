//
//  LargeWidgetView.swift
//  AmberWidget
//
//  Large Widget (4x4) 视图
//  显示月历视图，带农历、节假日标记、任务日期红圈
//  支持皮肤切换：长按配置 > App设置 > 默认琥珀金
//

import SwiftUI
import WidgetKit
import AppIntents

/// Large Widget Entry
struct LargeWidgetEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTask]
    let monthOffset: Int
    let skinType: WidgetSkinType
    let configuration: LargeWidgetConfigurationIntent
}

/// Large Widget Timeline Provider
struct LargeWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = LargeWidgetEntry
    typealias Intent = LargeWidgetConfigurationIntent

    func placeholder(in context: Context) -> LargeWidgetEntry {
        LargeWidgetEntry(
            date: Date(),
            tasks: [],
            monthOffset: 0,
            skinType: .amber,
            configuration: LargeWidgetConfigurationIntent()
        )
    }

    func snapshot(for configuration: LargeWidgetConfigurationIntent, in context: Context) async -> LargeWidgetEntry {
        let tasks = WidgetDataStore.loadTasks()
        let offset = WidgetDataStore.loadMonthOffset()
        let skinType = getEffectiveSkin(from: configuration)
        return LargeWidgetEntry(
            date: Date(),
            tasks: tasks,
            monthOffset: offset,
            skinType: skinType,
            configuration: configuration
        )
    }

    func timeline(for configuration: LargeWidgetConfigurationIntent, in context: Context) async -> Timeline<LargeWidgetEntry> {
        // Execute auto-postpone before loading tasks
        // This ensures overdue tasks are updated to today before display
        let postponedCount = WidgetDatabaseHelper.performAutoPostpone()
        if postponedCount > 0 {
            print("[LargeWidget] Auto-postponed \(postponedCount) overdue tasks to today")
        }

        let tasks = WidgetDataStore.loadTasks()
        let offset = WidgetDataStore.loadMonthOffset()
        let skinType = getEffectiveSkin(from: configuration)

        let entry = LargeWidgetEntry(
            date: Date(),
            tasks: tasks,
            monthOffset: offset,
            skinType: skinType,
            configuration: configuration
        )

        // 30 分钟后刷新
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    /// 获取有效的皮肤设置
    /// 优先级：长按 Widget 配置 > Flutter App 设置 > 默认琥珀金
    private func getEffectiveSkin(from configuration: LargeWidgetConfigurationIntent) -> WidgetSkinType {
        // 如果长按配置选择了具体皮肤（非跟随 App），优先使用
        if let intentSkin = configuration.skinType.toSkinType {
            return intentSkin
        }
        // 跟随 App 设置：从 Flutter App 设置读取
        return WidgetDataStore.loadLargeWidgetSkin()
    }
}

/// Large Widget 视图
struct LargeWidgetView: View {
    let entry: LargeWidgetEntry

    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
    private let calendar = Calendar.current

    private var skinConfig: WidgetSkinConfig {
        WidgetSkinConfig.getConfig(for: entry.skinType)
    }

    // 显示的月份
    private var displayMonth: Date {
        calendar.date(byAdding: .month, value: entry.monthOffset, to: Date()) ?? Date()
    }

    // 年月标题
    private var monthTitle: String {
        let year = calendar.component(.year, from: displayMonth)
        let month = calendar.component(.month, from: displayMonth)
        return "\(year)年\(month)月"
    }

    // 今日信息
    private var today: DateComponents {
        calendar.dateComponents([.year, .month, .day], from: Date())
    }

    // 任务日期集合（用于快速查找）
    private var taskDates: Set<String> {
        var dates = Set<String>()
        for task in entry.tasks {
            if let dueTime = task.dueTime {
                dates.insert(dueTime)
            }
        }
        return dates
    }

    // 当前显示月份的信息
    private var displayMonthInfo: (year: Int, month: Int, firstWeekday: Int, daysInMonth: Int) {
        let year = calendar.component(.year, from: displayMonth)
        let month = calendar.component(.month, from: displayMonth)

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        let firstDayOfMonth = calendar.date(from: components)!

        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) // 1=周日
        let daysInMonth = calendar.range(of: .day, in: .month, for: displayMonth)?.count ?? 30

        return (year, month, firstWeekday, daysInMonth)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Header: 月份导航
            HStack {
                // 上一月按钮
                Button(intent: PrevMonthIntent()) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(skinConfig.iconColor)
                }
                .buttonStyle(.plain)

                Spacer()

                // 年月标题
                Text(monthTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(skinConfig.textColor)

                Spacer()

                // 今天按钮（非当前月时显示）
                if entry.monthOffset != 0 {
                    Button(intent: TodayIntent()) {
                        Text("今")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(skinConfig.startColor)
                            .frame(width: 24, height: 24)
                            .background(skinConfig.textColor)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }

                // 下一月按钮
                Button(intent: NextMonthIntent()) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(skinConfig.iconColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)

            // 星期标题行
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    Text(weekdays[index])
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(weekdayColor(for: index))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)

            // 日历网格 (6行 x 7列 = 42格)
            let monthInfo = displayMonthInfo
            let leadingDays = monthInfo.firstWeekday - 1 // 月初前的空格数

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(0..<42, id: \.self) { index in
                    let dayInfo = getDayInfo(index: index, monthInfo: monthInfo, leadingDays: leadingDays)
                    CalendarDayCell(
                        day: dayInfo.day,
                        isCurrentMonth: dayInfo.isCurrentMonth,
                        isToday: dayInfo.isToday,
                        hasTask: dayInfo.hasTask,
                        holidayInfo: dayInfo.holidayInfo,
                        dateKey: dayInfo.dateKey,
                        skinConfig: skinConfig
                    )
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 12)
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

    // 星期标题颜色
    private func weekdayColor(for index: Int) -> Color {
        switch index {
        case 0: return Color(hex: 0xE53935) // 周日 - 红色
        case 6: return Color(hex: 0x1976D2) // 周六 - 蓝色
        default: return skinConfig.secondaryTextColor // 工作日 - 跟随皮肤
        }
    }

    // 获取日期格子信息
    private func getDayInfo(index: Int, monthInfo: (year: Int, month: Int, firstWeekday: Int, daysInMonth: Int), leadingDays: Int) -> DayInfo {
        let (year, month, _, daysInMonth) = monthInfo

        var dayInfo = DayInfo()

        if index < leadingDays {
            // 上个月的日期
            let prevMonthDate = calendar.date(byAdding: .month, value: -1, to: displayMonth)!
            let prevMonthDays = calendar.range(of: .day, in: .month, for: prevMonthDate)?.count ?? 30
            let prevYear = calendar.component(.year, from: prevMonthDate)
            let prevMonth = calendar.component(.month, from: prevMonthDate)

            dayInfo.day = prevMonthDays - leadingDays + index + 1
            dayInfo.isCurrentMonth = false
            dayInfo.dateKey = String(format: "%04d-%02d-%02d", prevYear, prevMonth, dayInfo.day)
        } else if index < leadingDays + daysInMonth {
            // 当前月的日期
            dayInfo.day = index - leadingDays + 1
            dayInfo.isCurrentMonth = true
            dayInfo.dateKey = String(format: "%04d-%02d-%02d", year, month, dayInfo.day)
            dayInfo.isToday = (year == today.year && month == today.month && dayInfo.day == today.day)
            dayInfo.holidayInfo = ChineseHolidays.getHolidayInfo(year: year, month: month, day: dayInfo.day)
        } else {
            // 下个月的日期
            let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: displayMonth)!
            let nextYear = calendar.component(.year, from: nextMonthDate)
            let nextMonth = calendar.component(.month, from: nextMonthDate)

            dayInfo.day = index - leadingDays - daysInMonth + 1
            dayInfo.isCurrentMonth = false
            dayInfo.dateKey = String(format: "%04d-%02d-%02d", nextYear, nextMonth, dayInfo.day)
        }

        dayInfo.hasTask = taskDates.contains(dayInfo.dateKey)

        return dayInfo
    }
}

/// 日期格子信息
struct DayInfo {
    var day: Int = 1
    var isCurrentMonth: Bool = true
    var isToday: Bool = false
    var hasTask: Bool = false
    var holidayInfo: HolidayInfo? = nil
    var dateKey: String = ""
}

/// 日历日期单元格
struct CalendarDayCell: View {
    let day: Int
    let isCurrentMonth: Bool
    let isToday: Bool
    let hasTask: Bool
    let holidayInfo: HolidayInfo?
    let dateKey: String
    let skinConfig: WidgetSkinConfig

    var body: some View {
        Link(destination: URL(string: "amberlist://widget/calendar?date=\(dateKey)")!) {
            VStack(spacing: 1) {
                ZStack {
                    // 今日标记（跟随皮肤主色）
                    if isToday && isCurrentMonth {
                        Circle()
                            .fill(skinConfig.iconColor)
                            .frame(width: 26, height: 26)
                    }

                    // 任务标记（红色手绘圆圈）
                    if hasTask && isCurrentMonth {
                        Circle()
                            .stroke(Color(hex: 0xE53935).opacity(0.7), lineWidth: 1.5)
                            .frame(width: 28, height: 28)
                    }

                    // 日期数字
                    Text("\(day)")
                        .font(.system(size: 13, weight: isToday ? .bold : .medium))
                        .foregroundColor(dayTextColor)
                }

                // 节假日标记
                if let holiday = holidayInfo, isCurrentMonth {
                    Text(holiday.name)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(holiday.isRestDay ? Color(hex: 0xE53935) : Color(hex: 0x1976D2))
                }
            }
            .frame(height: 36)
            .frame(maxWidth: .infinity)
        }
    }

    private var dayTextColor: Color {
        if !isCurrentMonth {
            return skinConfig.secondaryTextColor.opacity(0.4) // 非当前月 - 浅色
        }
        if isToday {
            return skinConfig.startColor // 今日 - 背景色（形成对比）
        }
        return skinConfig.textColor // 默认 - 跟随皮肤
    }
}

/// Large Widget 定义
struct LargeAmberWidget: Widget {
    let kind: String = "LargeAmberWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: LargeWidgetConfigurationIntent.self,
            provider: LargeWidgetProvider()
        ) { entry in
            LargeWidgetView(entry: entry)
        }
        .configurationDisplayName("琥珀清单 - 月历")
        .description("显示月历视图，有任务的日期带红圈标记，支持皮肤切换")
        .supportedFamilies([.systemLarge])
    }
}
