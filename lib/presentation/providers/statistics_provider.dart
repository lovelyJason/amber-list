import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/database.dart' as db;
import 'database_provider.dart';

/// 单日达成率详情（用于调试）
class DailyAchievementDetail {
  /// 日期
  final DateTime date;
  /// 星期几（1=周一，7=周日）
  final int weekday;
  /// 应完成的任务数（originalDueDate = 当天的任务）
  final int totalDueTasks;
  /// 按时达成的任务数（isCompleted && postponeCount == 0）
  final int achievedTasks;
  /// 达成率（-1 表示无数据）
  final double rate;
  /// 应完成的任务详情列表
  final List<String> taskDetails;

  const DailyAchievementDetail({
    required this.date,
    required this.weekday,
    required this.totalDueTasks,
    required this.achievedTasks,
    required this.rate,
    required this.taskDetails,
  });

  /// 获取星期几的文字
  String get weekdayText {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[weekday - 1];
  }
}

/// 周统计数据模型
class WeeklyStatistics {
  /// 本周每天完成的任务数（周一到周日，共7个元素）
  final List<int> dailyCompletedCounts;

  /// 本周每天的达成率（0.0-1.0，周一到周日）
  /// 达成率 = 当天按时完成的任务数 / 当天应完成的任务数
  /// 按时完成：postponeCount == 0 的已完成任务
  final List<double> dailyAchievementRates;

  /// 本周每天的达成率详情（用于调试）
  final List<DailyAchievementDetail> dailyAchievementDetails;

  /// 本周总完成任务数
  int get totalCompleted => dailyCompletedCounts.fold(0, (a, b) => a + b);

  /// 日均完成任务数
  double get dailyAverage {
    if (dailyCompletedCounts.isEmpty) return 0;
    // 只计算已过的天数，避免拉低平均值
    final today = DateTime.now().weekday;
    final pastDays = today; // 周一=1，周日=7
    return totalCompleted / pastDays;
  }

  /// 周平均达成率
  double get weeklyAverageRate {
    if (dailyAchievementRates.isEmpty) return 0;
    final validRates =
        dailyAchievementRates.where((r) => r >= 0).toList(); // -1 表示无数据
    if (validRates.isEmpty) return 0;
    return validRates.reduce((a, b) => a + b) / validRates.length;
  }

  const WeeklyStatistics({
    required this.dailyCompletedCounts,
    required this.dailyAchievementRates,
    this.dailyAchievementDetails = const [],
  });

  /// 空数据（全零）
  factory WeeklyStatistics.empty() => const WeeklyStatistics(
        dailyCompletedCounts: [0, 0, 0, 0, 0, 0, 0],
        dailyAchievementRates: [-1, -1, -1, -1, -1, -1, -1], // -1 表示无数据
        dailyAchievementDetails: [],
      );
}

/// 统计数据 Provider
/// 提供周视图和月视图所需的统计数据
/// 自动监听任务数据变化并刷新统计
class StatisticsNotifier extends StateNotifier<WeeklyStatistics> {
  final db.AppDatabase database;
  StreamSubscription<List<db.Task>>? _subscription;

  StatisticsNotifier(this.database) : super(WeeklyStatistics.empty()) {
    // 初始加载
    loadWeeklyStatistics();
    // 监听任务数据变化，自动刷新统计
    _subscription = database.watchAllTasks().listen((_) {
      loadWeeklyStatistics();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// 获取本周的起止日期（周一到周日）
  (DateTime, DateTime) _getThisWeekRange() {
    final now = DateTime.now();
    // 计算本周一
    final weekday = now.weekday; // 周一=1, 周日=7
    final monday = DateTime(now.year, now.month, now.day - (weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return (monday, sunday);
  }

  /// 加载本周统计数据
  Future<void> loadWeeklyStatistics() async {
    final (monday, sunday) = _getThisWeekRange();

    // 获取所有已完成的任务（不包括已删除的）
    final allTasks = await database.getAllTasks();
    final completedTasks = allTasks
        .where((t) => t.isCompleted && !t.isDeleted && t.completedAt != null)
        .toList();

    // 统计每天完成的任务数（按 completedAt 日期分组）
    final dailyCompleted = List<int>.filled(7, 0);
    for (final task in completedTasks) {
      final completedDate = task.completedAt!;
      // 检查是否在本周内（周一 00:00:00 到周日 23:59:59）
      if (!completedDate.isBefore(monday) &&
          completedDate.isBefore(sunday.add(const Duration(days: 1)))) {
        final dayIndex = completedDate.weekday - 1; // 0=周一, 6=周日
        if (dayIndex >= 0 && dayIndex < 7) {
          dailyCompleted[dayIndex]++;
        }
      }
    }

    // 计算每天的达成率
    // 达成率 = 当天按时完成的任务数 / 当天应完成的任务总数
    // 关键：按 originalDueDate 分组，而不是按 completedAt 分组！
    // 未完成的任务也算作"未达成"
    final dailyRates = List<double>.filled(7, -1); // -1 表示无数据
    final dailyDetails = <DailyAchievementDetail>[]; // 详情列表

    // 获取所有未删除的任务（包括未完成的）
    final activeTasks = allTasks.where((t) => !t.isDeleted).toList();

    // 遍历本周每一天
    for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
      final dayDate = monday.add(Duration(days: dayIndex));
      // 只计算已过的天数
      if (dayDate.isAfter(DateTime.now())) continue;

      // 统计"应该"在当天完成的任务（按 originalDueDate 分组）
      int totalDueTasks = 0;
      int achievedTasks = 0;
      final taskDetails = <String>[]; // 当天任务详情

      for (final task in activeTasks) {
        // 按 originalDueDate 判断任务"应该"在哪天完成
        if (task.originalDueDate != null &&
            _isSameDay(task.originalDueDate!, dayDate)) {
          totalDueTasks++;
          final isAchieved = task.isCompleted && task.postponeCount == 0;
          // 达成条件：任务已完成 + 没有被顺延过
          if (isAchieved) {
            achievedTasks++;
          }
          // 记录任务详情
          final status = isAchieved
              ? '✅ 达成'
              : (task.isCompleted ? '⚠️ 延期完成(顺延${task.postponeCount}次)' : '❌ 未完成');
          taskDetails.add('• ${task.title} $status');
        }
      }

      // 计算达成率（避免除零）
      double rate;
      if (totalDueTasks > 0) {
        rate = achievedTasks / totalDueTasks;
        dailyRates[dayIndex] = rate;
      } else {
        rate = -1; // 当天没有应完成的任务
        dailyRates[dayIndex] = -1;
      }

      // 添加详情记录
      dailyDetails.add(DailyAchievementDetail(
        date: dayDate,
        weekday: dayDate.weekday,
        totalDueTasks: totalDueTasks,
        achievedTasks: achievedTasks,
        rate: rate,
        taskDetails: taskDetails,
      ));
    }

    state = WeeklyStatistics(
      dailyCompletedCounts: dailyCompleted,
      dailyAchievementRates: dailyRates,
      dailyAchievementDetails: dailyDetails,
    );
  }

  /// 判断两个日期是否为同一天
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 刷新统计数据
  Future<void> refresh() async {
    await loadWeeklyStatistics();
  }
}

/// 统计数据 Provider 实例
final statisticsProvider =
    StateNotifierProvider<StatisticsNotifier, WeeklyStatistics>((ref) {
  final database = ref.watch(databaseProvider);
  return StatisticsNotifier(database);
});

// ============================================================
// 月统计数据模型和 Provider
// ============================================================

/// 任务类型分布数据（按清单分组）
class TaskTypeDistribution {
  /// 清单名称
  final String name;
  /// 清单颜色
  final int color;
  /// 任务数量
  final int count;
  /// 百分比（0.0-1.0）
  final double percentage;

  const TaskTypeDistribution({
    required this.name,
    required this.color,
    required this.count,
    required this.percentage,
  });
}

/// 成就类型枚举
enum AchievementType {
  /// 深度工作达人 - 累计连续专注超过4小时
  deepWorker,
  /// 清空收件箱 - 本周两次达成"收件箱清零"
  inboxZero,
  /// 早起鸟 - 早上8点前完成任务
  earlyBird,
  /// 完美周 - 本周所有任务按时完成
  perfectWeek,
  /// 效率王者 - 日均完成任务数超过10个
  efficiencyKing,
  /// 坚持不懈 - 连续7天都有完成任务
  persistent,
}

/// 成就数据
class Achievement {
  /// 成就类型
  final AchievementType type;
  /// 成就名称
  final String name;
  /// 成就描述
  final String description;
  /// 是否已达成
  final bool isAchieved;
  /// 成就图标
  final String icon;

  const Achievement({
    required this.type,
    required this.name,
    required this.description,
    required this.isAchieved,
    required this.icon,
  });
}

/// 月统计数据模型
class MonthlyStatistics {
  /// 本月已完成任务数
  final int totalCompleted;
  /// 上月已完成任务数（用于计算环比）
  final int lastMonthCompleted;
  /// 本月日均完成任务数
  final double dailyAverage;
  /// 本月效率指数（0-100）
  final int efficiencyScore;
  /// 效率等级（A+, A, B+, B, C, D）
  final String efficiencyGrade;
  /// 待办积压数（未完成且已过期的任务数）
  final int backlogCount;
  /// 是否需要关注待办积压
  final bool backlogNeedsAttention;
  /// 每日完成任务数（本月每天）
  final List<int> dailyCompletedCounts;
  /// 每日新增任务数（本月每天）
  final List<int> dailyCreatedCounts;
  /// 任务类型分布
  final List<TaskTypeDistribution> typeDistribution;
  /// 热力图数据（本月每天的任务完成数，用于绘制类似 GitHub 的热力图）
  final List<int> heatmapData;
  /// 本月成就列表
  final List<Achievement> achievements;

  const MonthlyStatistics({
    required this.totalCompleted,
    required this.lastMonthCompleted,
    required this.dailyAverage,
    required this.efficiencyScore,
    required this.efficiencyGrade,
    required this.backlogCount,
    required this.backlogNeedsAttention,
    required this.dailyCompletedCounts,
    required this.dailyCreatedCounts,
    required this.typeDistribution,
    required this.heatmapData,
    required this.achievements,
  });

  /// 环比增长率（与上月相比）
  double get growthRate {
    if (lastMonthCompleted == 0) return 0;
    return (totalCompleted - lastMonthCompleted) / lastMonthCompleted;
  }

  /// 空数据
  factory MonthlyStatistics.empty() => const MonthlyStatistics(
        totalCompleted: 0,
        lastMonthCompleted: 0,
        dailyAverage: 0,
        efficiencyScore: 0,
        efficiencyGrade: '-',
        backlogCount: 0,
        backlogNeedsAttention: false,
        dailyCompletedCounts: [],
        dailyCreatedCounts: [],
        typeDistribution: [],
        heatmapData: [],
        achievements: [],
      );
}

/// 月统计数据 Provider
class MonthlyStatisticsNotifier extends StateNotifier<MonthlyStatistics> {
  final db.AppDatabase database;
  StreamSubscription<List<db.Task>>? _subscription;

  MonthlyStatisticsNotifier(this.database) : super(MonthlyStatistics.empty()) {
    loadMonthlyStatistics();
    _subscription = database.watchAllTasks().listen((_) {
      loadMonthlyStatistics();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// 获取本月的起止日期
  (DateTime, DateTime) _getThisMonthRange() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0); // 下月0号 = 本月最后一天
    return (firstDay, lastDay);
  }

  /// 获取上月的起止日期
  (DateTime, DateTime) _getLastMonthRange() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month - 1, 1);
    final lastDay = DateTime(now.year, now.month, 0);
    return (firstDay, lastDay);
  }

  /// 加载月统计数据
  Future<void> loadMonthlyStatistics() async {
    final (monthStart, monthEnd) = _getThisMonthRange();
    final (lastMonthStart, lastMonthEnd) = _getLastMonthRange();
    final now = DateTime.now();
    final daysInMonth = monthEnd.day;
    final currentDay = now.day;

    // 获取所有任务和清单
    final allTasks = await database.getAllTasks();
    final allLists = await database.getAllTaskLists();

    // 本月已完成的任务
    final thisMonthCompleted = allTasks.where((t) =>
        t.isCompleted &&
        !t.isDeleted &&
        t.completedAt != null &&
        !t.completedAt!.isBefore(monthStart) &&
        t.completedAt!.isBefore(monthEnd.add(const Duration(days: 1)))).toList();

    // 上月已完成的任务
    final lastMonthCompleted = allTasks.where((t) =>
        t.isCompleted &&
        !t.isDeleted &&
        t.completedAt != null &&
        !t.completedAt!.isBefore(lastMonthStart) &&
        t.completedAt!.isBefore(lastMonthEnd.add(const Duration(days: 1)))).length;

    // 每日完成任务数
    final dailyCompleted = List<int>.filled(daysInMonth, 0);
    for (final task in thisMonthCompleted) {
      final day = task.completedAt!.day - 1; // 0-indexed
      if (day >= 0 && day < daysInMonth) {
        dailyCompleted[day]++;
      }
    }

    // 每日新增任务数
    final dailyCreated = List<int>.filled(daysInMonth, 0);
    final thisMonthCreated = allTasks.where((t) =>
        !t.isDeleted &&
        !t.createdAt.isBefore(monthStart) &&
        t.createdAt.isBefore(monthEnd.add(const Duration(days: 1)))).toList();
    for (final task in thisMonthCreated) {
      final day = task.createdAt.day - 1;
      if (day >= 0 && day < daysInMonth) {
        dailyCreated[day]++;
      }
    }

    // 日均完成（只计算已过的天数）
    final dailyAvg = currentDay > 0 ? thisMonthCompleted.length / currentDay : 0.0;

    // 待办积压（未完成且已过期）
    final backlog = allTasks.where((t) =>
        !t.isCompleted &&
        !t.isDeleted &&
        t.dueDate != null &&
        t.dueDate!.isBefore(DateTime(now.year, now.month, now.day))).length;

    // 效率指数计算：基于达成率和日均完成数
    // 达成率权重 60%，日均完成数权重 40%
    final activeTasks = allTasks.where((t) => !t.isDeleted).toList();
    int totalDue = 0;
    int achieved = 0;
    for (final task in activeTasks) {
      if (task.originalDueDate != null &&
          !task.originalDueDate!.isBefore(monthStart) &&
          task.originalDueDate!.isBefore(monthEnd.add(const Duration(days: 1)))) {
        totalDue++;
        if (task.isCompleted && task.postponeCount == 0) {
          achieved++;
        }
      }
    }
    final achievementRate = totalDue > 0 ? achieved / totalDue : 0.5;
    // 日均完成数评分（假设5个/天为满分）
    final dailyScore = (dailyAvg / 5).clamp(0.0, 1.0);
    final efficiencyScore = ((achievementRate * 0.6 + dailyScore * 0.4) * 100).round();

    // 效率等级
    String grade;
    if (efficiencyScore >= 90) {
      grade = 'A+';
    } else if (efficiencyScore >= 80) {
      grade = 'A';
    } else if (efficiencyScore >= 70) {
      grade = 'B+';
    } else if (efficiencyScore >= 60) {
      grade = 'B';
    } else if (efficiencyScore >= 50) {
      grade = 'C';
    } else {
      grade = 'D';
    }

    // 任务类型分布（按清单分组）
    final listCounts = <String, int>{};
    final listColors = <String, int>{};
    for (final task in thisMonthCompleted) {
      final listId = task.listId ?? 'inbox';
      listCounts[listId] = (listCounts[listId] ?? 0) + 1;
    }
    // 获取清单颜色
    for (final list in allLists) {
      listColors[list.id] = list.color;
    }
    // 收件箱默认颜色
    listColors['inbox'] = 0xFF9E9E9E;

    final totalCount = thisMonthCompleted.length;
    final typeDistribution = listCounts.entries.map((entry) {
      final listName = allLists.where((l) => l.id == entry.key).map((l) => l.name).firstOrNull ?? '收件箱';
      return TaskTypeDistribution(
        name: listName,
        color: listColors[entry.key] ?? 0xFF9E9E9E,
        count: entry.value,
        percentage: totalCount > 0 ? entry.value / totalCount : 0,
      );
    }).toList();
    // 按数量降序排序
    typeDistribution.sort((a, b) => b.count.compareTo(a.count));

    // 热力图数据（与每日完成数相同）
    final heatmapData = List<int>.from(dailyCompleted);

    // 计算成就
    final achievements = _calculateAchievements(
      allTasks: allTasks,
      thisMonthCompleted: thisMonthCompleted,
      dailyCompleted: dailyCompleted,
      currentDay: currentDay,
      monthStart: monthStart,
    );

    state = MonthlyStatistics(
      totalCompleted: thisMonthCompleted.length,
      lastMonthCompleted: lastMonthCompleted,
      dailyAverage: dailyAvg,
      efficiencyScore: efficiencyScore,
      efficiencyGrade: grade,
      backlogCount: backlog,
      backlogNeedsAttention: backlog >= 5,
      dailyCompletedCounts: dailyCompleted,
      dailyCreatedCounts: dailyCreated,
      typeDistribution: typeDistribution,
      heatmapData: heatmapData,
      achievements: achievements,
    );
  }

  /// 计算成就
  List<Achievement> _calculateAchievements({
    required List<db.Task> allTasks,
    required List<db.Task> thisMonthCompleted,
    required List<int> dailyCompleted,
    required int currentDay,
    required DateTime monthStart,
  }) {
    final achievements = <Achievement>[];

    // 1. 深度工作达人 - 暂时标记为未达成（需要番茄钟数据）
    achievements.add(const Achievement(
      type: AchievementType.deepWorker,
      name: '深度工作达人',
      description: '累计连续专注超过4小时，效率惊人！',
      isAchieved: false,
      icon: '🎯',
    ));

    // 2. 清空收件箱 - 检查是否有两次清空收件箱的记录
    // 简化判断：如果收件箱任务为0，认为达成
    final inboxTasks = allTasks.where((t) =>
        !t.isDeleted &&
        !t.isCompleted &&
        (t.listId == null || t.listId!.isEmpty)).length;
    achievements.add(Achievement(
      type: AchievementType.inboxZero,
      name: '清空收件箱',
      description: inboxTasks == 0 ? '收件箱已清零，继续保持！' : '本周两次达成"收件箱清零"成就。',
      isAchieved: inboxTasks == 0,
      icon: '📥',
    ));

    // 3. 早起鸟 - 检查是否有早上8点前完成的任务
    final earlyTasks = thisMonthCompleted.where((t) =>
        t.completedAt != null && t.completedAt!.hour < 8).length;
    achievements.add(Achievement(
      type: AchievementType.earlyBird,
      name: '早起鸟',
      description: earlyTasks > 0 ? '早起完成了 $earlyTasks 个任务！' : '早上8点前完成任务可获得此成就。',
      isAchieved: earlyTasks > 0,
      icon: '🌅',
    ));

    // 4. 完美周 - 检查最近7天是否所有任务按时完成
    // 简化：检查最近7天是否有顺延任务
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekTasks = allTasks.where((t) =>
        !t.isDeleted &&
        t.originalDueDate != null &&
        !t.originalDueDate!.isBefore(weekAgo) &&
        t.originalDueDate!.isBefore(now)).toList();
    final perfectWeek = weekTasks.isNotEmpty &&
        weekTasks.every((t) => t.isCompleted && t.postponeCount == 0);
    achievements.add(Achievement(
      type: AchievementType.perfectWeek,
      name: '完美周',
      description: perfectWeek ? '本周所有任务按时完成！' : '本周所有任务按时完成可获得此成就。',
      isAchieved: perfectWeek,
      icon: '🏆',
    ));

    // 5. 效率王者 - 日均完成任务数超过10个
    final dailyAvg = currentDay > 0 ? thisMonthCompleted.length / currentDay : 0;
    achievements.add(Achievement(
      type: AchievementType.efficiencyKing,
      name: '效率王者',
      description: dailyAvg >= 10 ? '日均完成 ${dailyAvg.toStringAsFixed(1)} 个任务！' : '日均完成任务数超过10个可获得此成就。',
      isAchieved: dailyAvg >= 10,
      icon: '👑',
    ));

    // 6. 坚持不懈 - 连续7天都有完成任务
    int consecutiveDays = 0;
    for (int i = currentDay - 1; i >= 0 && consecutiveDays < 7; i--) {
      if (dailyCompleted[i] > 0) {
        consecutiveDays++;
      } else {
        break;
      }
    }
    achievements.add(Achievement(
      type: AchievementType.persistent,
      name: '坚持不懈',
      description: consecutiveDays >= 7 ? '连续 $consecutiveDays 天完成任务！' : '连续7天都有完成任务可获得此成就。',
      isAchieved: consecutiveDays >= 7,
      icon: '💪',
    ));

    return achievements;
  }

  /// 刷新统计数据
  Future<void> refresh() async {
    await loadMonthlyStatistics();
  }
}

/// 月统计数据 Provider 实例
final monthlyStatisticsProvider =
    StateNotifierProvider<MonthlyStatisticsNotifier, MonthlyStatistics>((ref) {
  final database = ref.watch(databaseProvider);
  return MonthlyStatisticsNotifier(database);
});
