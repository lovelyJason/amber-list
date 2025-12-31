import 'task.dart';

/// 番茄时钟队列项模型
class PomodoroQueueItemModel {
  final String id;
  final String taskId;
  final int estimatedPomodoros; // 预估番茄钟数
  final int completedPomodoros; // 已完成番茄钟数
  final int sortOrder;
  final DateTime addedAt;

  // 关联的任务对象(用于UI显示,不存数据库)
  final Task? task;

  const PomodoroQueueItemModel({
    required this.id,
    required this.taskId,
    this.estimatedPomodoros = 1,
    this.completedPomodoros = 0,
    this.sortOrder = 0,
    required this.addedAt,
    this.task,
  });

  PomodoroQueueItemModel copyWith({
    String? id,
    String? taskId,
    int? estimatedPomodoros,
    int? completedPomodoros,
    int? sortOrder,
    DateTime? addedAt,
    Task? task,
  }) {
    return PomodoroQueueItemModel(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      estimatedPomodoros: estimatedPomodoros ?? this.estimatedPomodoros,
      completedPomodoros: completedPomodoros ?? this.completedPomodoros,
      sortOrder: sortOrder ?? this.sortOrder,
      addedAt: addedAt ?? this.addedAt,
      task: task ?? this.task,
    );
  }

  /// 增加一个已完成番茄钟
  PomodoroQueueItemModel incrementCompleted() {
    return copyWith(
      completedPomodoros: completedPomodoros + 1,
    );
  }

  /// 是否已完成所有番茄钟
  bool get isFullyCompleted => completedPomodoros >= estimatedPomodoros;

  /// 剩余番茄钟数
  int get remainingPomodoros => (estimatedPomodoros - completedPomodoros).clamp(0, 999);
}
