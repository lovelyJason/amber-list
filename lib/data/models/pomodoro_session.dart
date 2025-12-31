/// 番茄时钟会话类型
enum PomodoroSessionType {
  focus(0, '专注', 25 * 60), // 25分钟
  shortBreak(1, '短休息', 5 * 60), // 5分钟
  longBreak(2, '长休息', 15 * 60); // 15分钟

  final int value;
  final String label;
  final int defaultDuration; // 默认时长(秒)

  const PomodoroSessionType(this.value, this.label, this.defaultDuration);

  static PomodoroSessionType fromValue(int value) {
    return PomodoroSessionType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PomodoroSessionType.focus,
    );
  }
}

/// 番茄时钟会话模型
class PomodoroSessionModel {
  final String id;
  final String? taskId;
  final PomodoroSessionType type;
  final int duration; // 实际时长(秒)
  final bool completed;
  final DateTime startedAt;
  final DateTime? endedAt;

  const PomodoroSessionModel({
    required this.id,
    this.taskId,
    required this.type,
    required this.duration,
    this.completed = false,
    required this.startedAt,
    this.endedAt,
  });

  PomodoroSessionModel copyWith({
    String? id,
    String? taskId,
    PomodoroSessionType? type,
    int? duration,
    bool? completed,
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    return PomodoroSessionModel(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      type: type ?? this.type,
      duration: duration ?? this.duration,
      completed: completed ?? this.completed,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }
}
