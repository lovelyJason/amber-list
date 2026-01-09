package com.example.amber_list.widget

/**
 * Chinese holidays and workday adjustments data
 *
 * Data structure:
 * - holidays: Map of "YYYY-MM-DD" to holiday name (days off)
 * - workdays: Set of "YYYY-MM-DD" for makeup workdays (weekend work)
 *
 * Sources: Chinese government announcements for 2025-2026
 */
object ChineseHolidays {

    /**
     * Holiday info with name and whether it's a rest day
     */
    data class HolidayInfo(
        val name: String,      // Holiday name (e.g., "春节", "国庆")
        val isRestDay: Boolean // true = day off, false = makeup workday
    )

    /**
     * Get holiday info for a specific date
     * @param year Year (e.g., 2025)
     * @param month Month (1-12)
     * @param day Day of month (1-31)
     * @return HolidayInfo if it's a holiday/workday, null otherwise
     */
    fun getHolidayInfo(year: Int, month: Int, day: Int): HolidayInfo? {
        val key = String.format("%04d-%02d-%02d", year, month, day)

        // Check if it's a makeup workday first
        if (workdays.contains(key)) {
            return HolidayInfo("班", false)
        }

        // Check if it's a holiday
        return holidays[key]?.let { HolidayInfo(it, true) }
    }

    /**
     * Check if a date is a rest day (holiday or weekend, excluding makeup workdays)
     */
    fun isRestDay(year: Int, month: Int, day: Int, dayOfWeek: Int): Boolean {
        val key = String.format("%04d-%02d-%02d", year, month, day)

        // If it's a makeup workday, not a rest day
        if (workdays.contains(key)) {
            return false
        }

        // If it's a holiday, it's a rest day
        if (holidays.containsKey(key)) {
            return true
        }

        // Weekend (Saturday=7, Sunday=1 in Calendar)
        return dayOfWeek == java.util.Calendar.SATURDAY || dayOfWeek == java.util.Calendar.SUNDAY
    }

    // =====================================================
    // 2025 Chinese Holidays (Official)
    // =====================================================

    private val holidays2025 = mapOf(
        // New Year's Day (Jan 1)
        "2025-01-01" to "元旦",

        // Spring Festival (Jan 28 - Feb 4, eve Jan 28)
        "2025-01-28" to "除夕",
        "2025-01-29" to "春节",
        "2025-01-30" to "春节",
        "2025-01-31" to "春节",
        "2025-02-01" to "春节",
        "2025-02-02" to "春节",
        "2025-02-03" to "春节",
        "2025-02-04" to "春节",

        // Qingming Festival (Apr 4-6)
        "2025-04-04" to "清明",
        "2025-04-05" to "清明",
        "2025-04-06" to "清明",

        // Labor Day (May 1-5)
        "2025-05-01" to "劳动节",
        "2025-05-02" to "劳动节",
        "2025-05-03" to "劳动节",
        "2025-05-04" to "劳动节",
        "2025-05-05" to "劳动节",

        // Dragon Boat Festival (May 31 - Jun 2)
        "2025-05-31" to "端午",
        "2025-06-01" to "端午",
        "2025-06-02" to "端午",

        // Mid-Autumn Festival + National Day (Oct 1-8)
        "2025-10-01" to "国庆",
        "2025-10-02" to "国庆",
        "2025-10-03" to "国庆",
        "2025-10-04" to "中秋",
        "2025-10-05" to "国庆",
        "2025-10-06" to "国庆",
        "2025-10-07" to "国庆",
        "2025-10-08" to "国庆"
    )

    private val workdays2025 = setOf(
        // Spring Festival makeup workdays
        "2025-01-26", // Sunday -> work
        "2025-02-08", // Saturday -> work

        // Qingming makeup workday - none needed (weekend aligned)

        // Labor Day makeup workday
        "2025-04-27", // Sunday -> work

        // Dragon Boat makeup workday - none needed

        // National Day makeup workdays
        "2025-09-28", // Sunday -> work
        "2025-10-11"  // Saturday -> work
    )

    // =====================================================
    // 2026 Chinese Holidays (Estimated - adjust when official)
    // =====================================================

    private val holidays2026 = mapOf(
        // New Year's Day (Jan 1)
        "2026-01-01" to "元旦",
        "2026-01-02" to "元旦",
        "2026-01-03" to "元旦",

        // Spring Festival (Feb 17 is Chinese New Year)
        "2026-02-16" to "除夕",
        "2026-02-17" to "春节",
        "2026-02-18" to "春节",
        "2026-02-19" to "春节",
        "2026-02-20" to "春节",
        "2026-02-21" to "春节",
        "2026-02-22" to "春节",

        // Qingming Festival (Apr 4-6)
        "2026-04-04" to "清明",
        "2026-04-05" to "清明",
        "2026-04-06" to "清明",

        // Labor Day (May 1-5)
        "2026-05-01" to "劳动节",
        "2026-05-02" to "劳动节",
        "2026-05-03" to "劳动节",
        "2026-05-04" to "劳动节",
        "2026-05-05" to "劳动节",

        // Dragon Boat Festival (Jun 19-21)
        "2026-06-19" to "端午",
        "2026-06-20" to "端午",
        "2026-06-21" to "端午",

        // Mid-Autumn Festival (Sep 25-27)
        "2026-09-25" to "中秋",
        "2026-09-26" to "中秋",
        "2026-09-27" to "中秋",

        // National Day (Oct 1-7)
        "2026-10-01" to "国庆",
        "2026-10-02" to "国庆",
        "2026-10-03" to "国庆",
        "2026-10-04" to "国庆",
        "2026-10-05" to "国庆",
        "2026-10-06" to "国庆",
        "2026-10-07" to "国庆"
    )

    private val workdays2026 = setOf(
        // Spring Festival makeup workdays (estimated)
        "2026-02-14", // Saturday -> work
        "2026-02-28", // Saturday -> work

        // Labor Day makeup workday
        "2026-04-26", // Sunday -> work

        // National Day makeup workdays
        "2026-09-27", // Sunday -> work
        "2026-10-10"  // Saturday -> work
    )

    // Combined maps
    private val holidays = holidays2025 + holidays2026
    private val workdays = workdays2025 + workdays2026
}
