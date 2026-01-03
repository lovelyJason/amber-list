// ============================================================
// 日期工具类
// ============================================================
// 提供跨平台/跨时区一致的日期处理方法
//
// 核心问题：
// Flutter 的 DatePicker 返回本地时间的 DateTime，存入 SQLite 时会
// 转换为 Unix 毫秒时间戳。当数据在不同时区的设备间同步时，时间戳
// 被解析成不同的本地日期，导致"已过期"判断不一致。
//
// 解决方案：
// 对于只关心日期不关心时间的场景（如 dueDate），统一规范化为
// **UTC 日期的午夜零点**，确保跨设备同步时日期一致。
//
// 示例：
// - 用户在东八区选择 2026-01-03
// - 存储为 2026-01-03T00:00:00.000Z（UTC 午夜）
// - 任何时区的设备读取后都是 2026-01-03
// ============================================================

/// 琥珀清单日期工具类
/// 提供跨平台/跨时区一致的日期处理方法
class AmberDateUtils {
  AmberDateUtils._();

  /// 将本地日期规范化为 UTC 午夜
  /// 用于存储只关心日期的场景（如截止日期）
  ///
  /// 例如：
  /// - 输入：2026-01-03 00:00:00.000+0800（东八区午夜）
  /// - 输出：2026-01-03 00:00:00.000Z（UTC 午夜）
  ///
  /// 这样无论在哪个时区读取，转换回本地日期都是 2026-01-03
  static DateTime normalizeToUtcDate(DateTime localDate) {
    // 提取年月日，创建 UTC 日期
    return DateTime.utc(localDate.year, localDate.month, localDate.day);
  }

  /// 从 UTC 日期转换为本地日期（只保留日期部分）
  /// 用于显示时将 UTC 日期转换为本地日期对象
  ///
  /// 例如：
  /// - 输入：2026-01-03 00:00:00.000Z（UTC 午夜）
  /// - 输出：2026-01-03 00:00:00.000（本地午夜）
  static DateTime utcToLocalDate(DateTime utcDate) {
    // 直接用年月日创建本地日期
    return DateTime(utcDate.year, utcDate.month, utcDate.day);
  }

  /// 获取今天的本地日期（午夜零点）
  static DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// 判断日期是否是今天
  /// 无论传入的是 UTC 还是本地时间，都只比较日期部分
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// 判断日期是否已过期（在今天之前）
  /// 使用日期部分比较，忽略时区问题
  static bool isOverdue(DateTime date) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    return dateOnly.isBefore(todayStart);
  }

  /// 判断日期是否是明天
  static bool isTomorrow(DateTime date) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;
  }

  /// 比较两个日期是否是同一天
  /// 忽略时间部分和时区
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 格式化截止日期为友好文本
  /// 返回：已过期 / 今天 / 明天 / M月d日
  static String formatDueDate(DateTime date) {
    if (isOverdue(date)) {
      return '已过期';
    } else if (isToday(date)) {
      return '今天';
    } else if (isTomorrow(date)) {
      return '明天';
    } else {
      return '${date.month}月${date.day}日';
    }
  }
}
