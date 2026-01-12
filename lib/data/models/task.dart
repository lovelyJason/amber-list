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
  final bool isInProgress; // 是否处于"进行中"状态（半完成）
  final bool isDeleted; // 是否已删除（移入垃圾桶）
  final DateTime? deletedAt; // 删除时间（用于 30 天自动清理）
  final DateTime? completedAt;
  final List<String> tags;
  final int sortOrder;
  final String? parentId; // 父任务ID（子任务用）
  /// 是否自动顺延过期任务到今天
  /// - 新任务默认为 true（自动顺延）
  /// - 旧数据迁移后为 false（不自动顺延，显示在已过期区域）
  final bool autoPostpone;

  /// 任务首次设置的截止日期（用于统计达成率）
  /// - 首次设置 dueDate 时记录此值，之后顺延不修改
  /// - 用于判断任务是否按时完成
  final DateTime? originalDueDate;

  /// 任务被顺延的次数（用于统计达成率）
  /// - 新任务默认为 0
  /// - 每次自动/手动顺延时 +1
  /// - postponeCount > 0 表示任务未按时完成
  final int postponeCount;

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
    this.isInProgress = false,
    this.isDeleted = false,
    this.deletedAt,
    this.completedAt,
    this.tags = const [],
    this.sortOrder = 0,
    this.parentId,
    this.autoPostpone = true, // 新任务默认开启自动顺延
    this.originalDueDate,
    this.postponeCount = 0,
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
    bool? isInProgress,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? completedAt,
    List<String>? tags,
    int? sortOrder,
    String? parentId,
    bool? autoPostpone,
    DateTime? originalDueDate,
    int? postponeCount,
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
      isInProgress: isInProgress ?? this.isInProgress,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      completedAt: completedAt ?? this.completedAt,
      tags: tags ?? this.tags,
      sortOrder: sortOrder ?? this.sortOrder,
      parentId: parentId ?? this.parentId,
      autoPostpone: autoPostpone ?? this.autoPostpone,
      originalDueDate: originalDueDate ?? this.originalDueDate,
      postponeCount: postponeCount ?? this.postponeCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Task toggleComplete() {
    final now = DateTime.now();
    if (isCompleted) {
      // Uncomplete: Must explicitly set completedAt to null
      // copyWith(completedAt: null) would trigger '?? this.completedAt' keeping the old value
      return Task(
        id: id,
        title: title,
        description: description,
        listId: listId,
        dueDate: dueDate,
        priority: priority,
        isCompleted: false,
        isInProgress: false, // 取消完成时也清除进行中状态
        isDeleted: isDeleted,
        deletedAt: deletedAt, // 保留删除时间
        completedAt: null,
        tags: tags,
        sortOrder: sortOrder,
        parentId: parentId,
        autoPostpone: autoPostpone, // 保留自动顺延设置
        originalDueDate: originalDueDate, // 保留原始截止日期
        postponeCount: postponeCount, // 保留顺延次数
        createdAt: createdAt,
        updatedAt: now,
      );
    } else {
      // Complete: 完成时也清除进行中状态
      return copyWith(
        isCompleted: true,
        isInProgress: false,
        completedAt: now,
        updatedAt: now,
      );
    }
  }

  /// 切换进行中（半完成）状态
  /// 如果任务已完成，不能设置为进行中
  Task toggleInProgress() {
    if (isCompleted) return this; // 已完成的任务不能设为进行中
    final now = DateTime.now();
    return copyWith(
      isInProgress: !isInProgress,
      updatedAt: now,
    );
  }
}
