import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 节假日数据仓库（单例）
///
/// 职责:
/// - 从 timor.tech API 获取节假日数据
/// - 缓存到 SharedPreferences（一次获取，永久缓存）
/// - 判断指定日期是否为节假日或周末
///
/// 设计哲学:
/// - 首次启动时从 API 获取数据
/// - 缓存到 SharedPreferences，后续启动不再请求
/// - 数据来源：timor.tech（数据源自国务院办公厅）
/// - 离线时降级为仅判断周末
class HolidayRepository {
  static final HolidayRepository instance = HolidayRepository._();
  HolidayRepository._();

  /// API 基础 URL
  static const _apiBaseUrl = 'https://timor.tech/api/holiday/year';

  /// SharedPreferences key 前缀
  static const _cacheKeyPrefix = 'holiday_data_';

  /// 内存缓存: 年份 -> (holidays: Set<日期>, workdays: Set<日期>)
  final Map<int, _YearHolidayCache> _memoryCache = {};

  /// 判断指定日期是否为节假日（包括周末，但排除调休工作日）
  ///
  /// 判断逻辑优先级:
  /// 1. 调休工作日 → 返回 false（需要上班）
  /// 2. 法定节假日 → 返回 true
  /// 3. 周末 → 返回 true
  /// 4. 其他 → 返回 false（正常工作日）
  Future<bool> isHoliday(DateTime date) async {
    // 1. 加载当年数据
    final cache = await _loadYearData(date.year);
    if (cache == null) {
      // 数据缺失，降级策略: 只判断周末
      return date.weekday == DateTime.saturday ||
          date.weekday == DateTime.sunday;
    }

    final dateStr = _formatDate(date);

    // 2. 检查是否为调休工作日（优先级最高）
    if (cache.workdays.contains(dateStr)) {
      return false; // 调休工作日，需要上班
    }

    // 3. 检查是否为周末
    if (date.weekday == DateTime.saturday ||
        date.weekday == DateTime.sunday) {
      return true;
    }

    // 4. 检查是否在节假日列表中
    return cache.holidays.contains(dateStr);
  }

  /// 加载指定年份的节假日数据
  ///
  /// 优先级: 内存缓存 > SharedPreferences缓存 > API请求
  Future<_YearHolidayCache?> _loadYearData(int year) async {
    // 1. 从内存缓存读取
    if (_memoryCache.containsKey(year)) {
      return _memoryCache[year];
    }

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_cacheKeyPrefix$year';

    // 2. 从 SharedPreferences 读取
    final cachedJson = prefs.getString(cacheKey);
    if (cachedJson != null) {
      try {
        final cache = _parseApiResponse(cachedJson, year);
        if (cache != null) {
          _memoryCache[year] = cache;
          return cache;
        }
      } catch (_) {
        // 缓存数据损坏，继续尝试 API
      }
    }

    // 3. 从 API 获取
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/$year'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
              'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonStr = response.body;
        final cache = _parseApiResponse(jsonStr, year);
        if (cache != null) {
          // 永久缓存到 SharedPreferences
          await prefs.setString(cacheKey, jsonStr);
          _memoryCache[year] = cache;
          return cache;
        }
      }
    } catch (_) {
      // API 请求失败，静默降级
    }

    return null;
  }

  /// 解析 timor.tech API 响应
  ///
  /// API 返回格式:
  /// ```json
  /// {
  ///   "code": 0,
  ///   "holiday": {
  ///     "01-01": {"holiday": true, "name": "元旦", "date": "2025-01-01"},
  ///     "01-26": {"holiday": false, "name": "春节前补班", "date": "2025-01-26"}
  ///   }
  /// }
  /// ```
  ///
  /// holiday: true = 节假日
  /// holiday: false = 调休工作日
  _YearHolidayCache? _parseApiResponse(String jsonStr, int year) {
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final code = json['code'] as int?;
      if (code != 0) return null;

      final holidayMap = json['holiday'] as Map<String, dynamic>?;
      if (holidayMap == null) return null;

      final holidays = <String>{};
      final workdays = <String>{};

      for (final entry in holidayMap.entries) {
        final data = entry.value as Map<String, dynamic>;
        final isHoliday = data['holiday'] as bool;
        final dateStr = data['date'] as String; // 格式: "2025-01-01"

        if (isHoliday) {
          holidays.add(dateStr);
        } else {
          workdays.add(dateStr);
        }
      }

      return _YearHolidayCache(holidays: holidays, workdays: workdays);
    } catch (_) {
      return null;
    }
  }

  /// 格式化日期为 "YYYY-MM-DD" 格式
  String _formatDate(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// 清除缓存（用于测试或强制刷新）
  Future<void> clearCache() async {
    _memoryCache.clear();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_cacheKeyPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}

/// 年度节假日缓存数据
class _YearHolidayCache {
  /// 节假日日期集合（格式: "2025-01-01"）
  final Set<String> holidays;

  /// 调休工作日日期集合（格式: "2025-01-26"）
  final Set<String> workdays;

  const _YearHolidayCache({
    required this.holidays,
    required this.workdays,
  });
}
