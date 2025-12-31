/// 任务优先级
enum TaskPriority {
  none(0),
  low(1),
  medium(2),
  high(3);

  final int value;
  const TaskPriority(this.value);

  static TaskPriority fromValue(int value) {
    return TaskPriority.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TaskPriority.none,
    );
  }

  String get label {
    switch (this) {
      case TaskPriority.high:
        return '高优先级';
      case TaskPriority.medium:
        return '中优先级';
      case TaskPriority.low:
        return '低优先级';
      case TaskPriority.none:
        return '无优先级';
    }
  }
}

/// 任务模型
class Task {
  final String id;
  final String title;
  final String? description;
  final String? listId;
  final DateTime? dueDate;
  final TaskPriority priority;
  final bool isCompleted;
  final bool isDeleted; // 是否已删除（移入垃圾桶）
  final DateTime? completedAt;
  final List<String> tags;
  final int sortOrder;
  final String? parentId; // 父任务ID（子任务用）
  final DateTime createdAt;
  final DateTime updatedAt;

  const Task({
    required this.id,
    required this.title,
    this.description,
    this.listId,
    this.dueDate,
    this.priority = TaskPriority.none,
    this.isCompleted = false,
    this.isDeleted = false,
    this.completedAt,
    this.tags = const [],
    this.sortOrder = 0,
    this.parentId,
    required this.createdAt,
    required this.updatedAt,
  });

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? listId,
    DateTime? dueDate,
    TaskPriority? priority,
    bool? isCompleted,
    bool? isDeleted,
    DateTime? completedAt,
    List<String>? tags,
    int? sortOrder,
    String? parentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      listId: listId ?? this.listId,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      isDeleted: isDeleted ?? this.isDeleted,
      completedAt: completedAt ?? this.completedAt,
      tags: tags ?? this.tags,
      sortOrder: sortOrder ?? this.sortOrder,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 切换完成状态
  Task toggleComplete() {
    final now = DateTime.now();
    return copyWith(
      isCompleted: !isCompleted,
      completedAt: !isCompleted ? now : null,
      updatedAt: now,
    );
  }
}
