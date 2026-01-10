//
//  ChineseCalendar.swift
//  AmberWidget
//
//  中国农历和节假日工具类
//  移植自 Android ChineseHolidays.kt，用于 Large Widget 月历显示
//

import Foundation

// MARK: - 中国农历计算

/// 农历信息结构体
struct LunarDateInfo {
    let month: String    // 农历月份，如 "腊月"
    let day: String      // 农历日期，如 "初九"
    let monthIndex: Int  // 农历月份索引 (1-12)
    let dayIndex: Int    // 农历日期索引 (1-30)
}

/// 中国农历计算工具
class ChineseCalendar {

    // MARK: - 农历数据

    /// 农历日期名称
    private static let lunarDays = [
        "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
        "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
        "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"
    ]

    /// 农历月份名称
    private static let lunarMonths = [
        "正月", "二月", "三月", "四月", "五月", "六月",
        "七月", "八月", "九月", "十月", "冬月", "腊月"
    ]

    /// 农历月份起始日期数据（2024-2026年）
    /// 格式：(公历年, 公历月0索引, 公历日, 农历月份1-12, 农历年)
    private static let lunarMonthStarts: [(Int, Int, Int, Int, Int)] = [
        // 甲辰年 (2024)
        (2024, 1, 10, 1, 2024),   // 正月初一 Feb 10
        (2024, 2, 10, 2, 2024),   // 二月初一 Mar 10
        (2024, 3, 9, 3, 2024),    // 三月初一 Apr 9
        (2024, 4, 8, 4, 2024),    // 四月初一 May 8
        (2024, 5, 6, 5, 2024),    // 五月初一 Jun 6
        (2024, 6, 6, 6, 2024),    // 六月初一 Jul 6
        (2024, 7, 4, 7, 2024),    // 七月初一 Aug 4
        (2024, 8, 3, 8, 2024),    // 八月初一 Sep 3
        (2024, 9, 3, 9, 2024),    // 九月初一 Oct 3
        (2024, 10, 1, 10, 2024),  // 十月初一 Nov 1
        (2024, 11, 1, 11, 2024),  // 冬月初一 Dec 1
        (2024, 11, 31, 12, 2024), // 腊月初一 Dec 31

        // 乙巳年 (2025)
        (2025, 0, 29, 1, 2025),   // 正月初一 Jan 29
        (2025, 1, 28, 2, 2025),   // 二月初一 Feb 28
        (2025, 2, 29, 3, 2025),   // 三月初一 Mar 29
        (2025, 3, 28, 4, 2025),   // 四月初一 Apr 28
        (2025, 4, 27, 5, 2025),   // 五月初一 May 27
        (2025, 5, 25, 6, 2025),   // 六月初一 Jun 25
        (2025, 6, 25, 6, 2025),   // 闰六月初一 Jul 25
        (2025, 7, 23, 7, 2025),   // 七月初一 Aug 23
        (2025, 8, 22, 8, 2025),   // 八月初一 Sep 22
        (2025, 9, 21, 9, 2025),   // 九月初一 Oct 21
        (2025, 10, 20, 10, 2025), // 十月初一 Nov 20
        (2025, 11, 20, 11, 2025), // 冬月初一 Dec 20

        // 丙午年 (2026)
        (2026, 0, 18, 12, 2025),  // 腊月初一 Jan 18 (still 2025 lunar)
        (2026, 1, 17, 1, 2026),   // 正月初一 Feb 17
        (2026, 2, 19, 2, 2026),   // 二月初一 Mar 19
        (2026, 3, 17, 3, 2026),   // 三月初一 Apr 17
        (2026, 4, 17, 4, 2026),   // 四月初一 May 17
        (2026, 5, 15, 5, 2026),   // 五月初一 Jun 15
        (2026, 6, 15, 6, 2026),   // 六月初一 Jul 15
        (2026, 7, 13, 7, 2026),   // 七月初一 Aug 13
        (2026, 8, 12, 8, 2026),   // 八月初一 Sep 12
        (2026, 9, 11, 9, 2026),   // 九月初一 Oct 11
        (2026, 10, 10, 10, 2026), // 十月初一 Nov 10
        (2026, 11, 10, 11, 2026), // 冬月初一 Dec 10
    ]

    // MARK: - 农历计算方法

    /// 获取指定日期的农历信息
    static func getLunarDate(from date: Date) -> LunarDateInfo {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date) - 1 // 0-indexed
        let day = calendar.component(.day, from: date)

        // 查找对应的农历月份
        var foundMonth: (Int, Int, Int, Int, Int)?

        for i in stride(from: lunarMonthStarts.count - 1, through: 0, by: -1) {
            let lms = lunarMonthStarts[i]
            let startDate = createDate(year: lms.0, month: lms.1, day: lms.2)
            if date >= startDate {
                foundMonth = lms
                break
            }
        }

        guard let lunarMonth = foundMonth else {
            return LunarDateInfo(month: "正月", day: "初一", monthIndex: 1, dayIndex: 1)
        }

        // 计算农历日期
        let startDate = createDate(year: lunarMonth.0, month: lunarMonth.1, day: lunarMonth.2)
        let daysDiff = calendar.dateComponents([.day], from: startDate, to: date).day ?? 0
        let lunarDay = daysDiff + 1

        let monthStr = lunarMonth.3 >= 1 && lunarMonth.3 <= 12 ? lunarMonths[lunarMonth.3 - 1] : "正月"
        let dayStr = lunarDay >= 1 && lunarDay <= 30 ? lunarDays[lunarDay - 1] : "三十"

        return LunarDateInfo(
            month: monthStr,
            day: dayStr,
            monthIndex: lunarMonth.3,
            dayIndex: lunarDay
        )
    }

    /// 创建日期
    private static func createDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month + 1 // Calendar uses 1-indexed months
        components.day = day
        components.hour = 0
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components) ?? Date()
    }
}

// MARK: - 中国节假日数据

/// 节假日信息
struct HolidayInfo {
    let name: String     // 节假日名称，如 "休"、"班"
    let isRestDay: Bool  // 是否休息日（true=休息，false=补班）
}

/// 中国节假日工具类
class ChineseHolidays {

    /// 获取指定日期的节假日信息
    /// - Parameters:
    ///   - year: 年份
    ///   - month: 月份 (1-12)
    ///   - day: 日期 (1-31)
    /// - Returns: 节假日信息，如果不是节假日则返回 nil
    static func getHolidayInfo(year: Int, month: Int, day: Int) -> HolidayInfo? {
        let key = String(format: "%04d-%02d-%02d", year, month, day)

        // 2025 年节假日数据
        if let info = holidays2025[key] {
            return info
        }

        // 2026 年节假日数据
        if let info = holidays2026[key] {
            return info
        }

        return nil
    }

    // MARK: - 2025 年节假日

    private static let holidays2025: [String: HolidayInfo] = [
        // 元旦
        "2025-01-01": HolidayInfo(name: "休", isRestDay: true),

        // 春节
        "2025-01-26": HolidayInfo(name: "班", isRestDay: false),
        "2025-01-28": HolidayInfo(name: "休", isRestDay: true),
        "2025-01-29": HolidayInfo(name: "休", isRestDay: true),
        "2025-01-30": HolidayInfo(name: "休", isRestDay: true),
        "2025-01-31": HolidayInfo(name: "休", isRestDay: true),
        "2025-02-01": HolidayInfo(name: "休", isRestDay: true),
        "2025-02-02": HolidayInfo(name: "休", isRestDay: true),
        "2025-02-03": HolidayInfo(name: "休", isRestDay: true),
        "2025-02-04": HolidayInfo(name: "休", isRestDay: true),
        "2025-02-08": HolidayInfo(name: "班", isRestDay: false),

        // 清明节
        "2025-04-04": HolidayInfo(name: "休", isRestDay: true),
        "2025-04-05": HolidayInfo(name: "休", isRestDay: true),
        "2025-04-06": HolidayInfo(name: "休", isRestDay: true),

        // 劳动节
        "2025-04-27": HolidayInfo(name: "班", isRestDay: false),
        "2025-05-01": HolidayInfo(name: "休", isRestDay: true),
        "2025-05-02": HolidayInfo(name: "休", isRestDay: true),
        "2025-05-03": HolidayInfo(name: "休", isRestDay: true),
        "2025-05-04": HolidayInfo(name: "休", isRestDay: true),
        "2025-05-05": HolidayInfo(name: "休", isRestDay: true),

        // 端午节
        "2025-05-31": HolidayInfo(name: "休", isRestDay: true),
        "2025-06-01": HolidayInfo(name: "休", isRestDay: true),
        "2025-06-02": HolidayInfo(name: "休", isRestDay: true),

        // 中秋节+国庆节
        "2025-09-28": HolidayInfo(name: "班", isRestDay: false),
        "2025-10-01": HolidayInfo(name: "休", isRestDay: true),
        "2025-10-02": HolidayInfo(name: "休", isRestDay: true),
        "2025-10-03": HolidayInfo(name: "休", isRestDay: true),
        "2025-10-04": HolidayInfo(name: "休", isRestDay: true),
        "2025-10-05": HolidayInfo(name: "休", isRestDay: true),
        "2025-10-06": HolidayInfo(name: "休", isRestDay: true),
        "2025-10-07": HolidayInfo(name: "休", isRestDay: true),
        "2025-10-08": HolidayInfo(name: "休", isRestDay: true),
        "2025-10-11": HolidayInfo(name: "班", isRestDay: false),
    ]

    // MARK: - 2026 年节假日

    private static let holidays2026: [String: HolidayInfo] = [
        // 元旦
        "2026-01-01": HolidayInfo(name: "休", isRestDay: true),
        "2026-01-02": HolidayInfo(name: "休", isRestDay: true),
        "2026-01-03": HolidayInfo(name: "休", isRestDay: true),

        // 春节（预估，具体以国务院公布为准）
        "2026-02-15": HolidayInfo(name: "班", isRestDay: false),
        "2026-02-17": HolidayInfo(name: "休", isRestDay: true),
        "2026-02-18": HolidayInfo(name: "休", isRestDay: true),
        "2026-02-19": HolidayInfo(name: "休", isRestDay: true),
        "2026-02-20": HolidayInfo(name: "休", isRestDay: true),
        "2026-02-21": HolidayInfo(name: "休", isRestDay: true),
        "2026-02-22": HolidayInfo(name: "休", isRestDay: true),
        "2026-02-23": HolidayInfo(name: "休", isRestDay: true),
        "2026-02-28": HolidayInfo(name: "班", isRestDay: false),
    ]
}
