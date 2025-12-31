import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../datasources/local/database.dart' as db;
import '../models/models.dart';

/// 番茄时钟数据仓库
class PomodoroRepository {
  final db.AppDatabase _db;
  final Uuid _uuid = const Uuid();

  PomodoroRepository(this._db);

  // ===== 会话操作 =====

  /// 创建新会话
  Future<String> createSession({
    required PomodoroSessionType type,
    String? taskId,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await _db.insertPomodoroSession(
      db.PomodoroSessionsCompanion.insert(
        id: id,
        taskId: drift.Value(taskId),
        type: type.value,
        duration: type.defaultDuration,
        startedAt: now,
      ),
    );

    return id;
  }

  /// 完成会话
  Future<void> completeSession(String sessionId, int actualDuration) async {
    await _db.updatePomodoroSession(
      db.PomodoroSessionsCompanion(
        id: drift.Value(sessionId),
        duration: drift.Value(actualDuration),
        completed: const drift.Value(true),
        endedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  /// 监听今日会话
  Stream<List<PomodoroSessionModel>> watchTodaySessions() {
    return _db.watchTodayPomodoroSessions().map((dbSessions) {
      return dbSessions.map(_mapDbSessionToModel).toList();
    });
  }

  /// 数据库模型转领域模型
  PomodoroSessionModel _mapDbSessionToModel(db.PomodoroSession dbSession) {
    return PomodoroSessionModel(
      id: dbSession.id,
      taskId: dbSession.taskId,
      type: PomodoroSessionType.fromValue(dbSession.type),
      duration: dbSession.duration,
      completed: dbSession.completed,
      startedAt: dbSession.startedAt,
      endedAt: dbSession.endedAt,
    );
  }

  // ===== 队列操作 =====

  /// 添加任务到队列
  Future<String> addToQueue({
    required String taskId,
    int estimatedPomodoros = 1,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    // 获取当前最大sortOrder
    final queue = await _db.watchPomodoroQueue().first;
    final maxSortOrder = queue.isEmpty ? 0 : queue.map((q) => q.sortOrder).reduce((a, b) => a > b ? a : b);

    await _db.insertPomodoroQueueItem(
      db.PomodoroQueueCompanion.insert(
        id: id,
        taskId: taskId,
        estimatedPomodoros: drift.Value(estimatedPomodoros),
        sortOrder: drift.Value(maxSortOrder + 1),
        addedAt: now,
      ),
    );

    return id;
  }

  /// 从队列移除
  Future<void> removeFromQueue(String queueItemId) async {
    await _db.deletePomodoroQueueItem(queueItemId);
  }

  /// 更新队列项
  Future<void> updateQueueItem({
    required String id,
    int? estimatedPomodoros,
    int? completedPomodoros,
    int? sortOrder,
  }) async {
    await _db.updatePomodoroQueueItem(
      db.PomodoroQueueCompanion(
        id: drift.Value(id),
        estimatedPomodoros: estimatedPomodoros != null ? drift.Value(estimatedPomodoros) : const drift.Value.absent(),
        completedPomodoros: completedPomodoros != null ? drift.Value(completedPomodoros) : const drift.Value.absent(),
        sortOrder: sortOrder != null ? drift.Value(sortOrder) : const drift.Value.absent(),
      ),
    );
  }

  /// 增加队列项完成数
  Future<void> incrementQueueItemCompleted(String queueItemId) async {
    final queue = await _db.watchPomodoroQueue().first;
    final item = queue.firstWhere((q) => q.id == queueItemId);

    await updateQueueItem(
      id: queueItemId,
      completedPomodoros: item.completedPomodoros + 1,
    );
  }

  /// 监听队列(带任务信息)
  Stream<List<PomodoroQueueItemModel>> watchQueue() {
    return _db.watchPomodoroQueue().asyncMap((dbItems) async {
      final result = <PomodoroQueueItemModel>[];
      // 批量获取所有tasks避免重复查询
      final allTasks = await _db.select(_db.tasks).get();

      for (final dbItem in dbItems) {
        final task = allTasks.where((t) => t.id == dbItem.taskId).firstOrNull;
        result.add(_mapDbQueueItemToModel(dbItem, task));
      }
      return result;
    });
  }

  /// 清空队列
  Future<void> clearQueue() async {
    await _db.clearPomodoroQueue();
  }

  /// 删除队列项
  Future<void> deleteQueueItem(String id) async {
    await _db.deletePomodoroQueueItem(id);
  }

  /// 重排队列顺序
  Future<void> reorderQueue(List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await updateQueueItem(
        id: orderedIds[i],
        sortOrder: i,
      );
    }
  }

  /// 数据库队列项转领域模型
  PomodoroQueueItemModel _mapDbQueueItemToModel(
    db.PomodoroQueueData dbItem,
    db.Task? dbTask,
  ) {
    // 将数据库Task转换为领域模型Task
    Task? task;
    if (dbTask != null) {
      task = Task(
        id: dbTask.id,
        title: dbTask.title,
        description: dbTask.description,
        listId: dbTask.listId,
        dueDate: dbTask.dueDate,
        priority: TaskPriority.fromValue(dbTask.priority),
        isCompleted: dbTask.isCompleted,
        isDeleted: dbTask.isDeleted,
        completedAt: dbTask.completedAt,
        tags: dbTask.tags.isEmpty
            ? <String>[]
            : (jsonDecode(dbTask.tags) as List).cast<String>(),
        sortOrder: dbTask.sortOrder,
        parentId: dbTask.parentId,
        createdAt: dbTask.createdAt,
        updatedAt: dbTask.updatedAt,
      );
    }

    return PomodoroQueueItemModel(
      id: dbItem.id,
      taskId: dbItem.taskId,
      estimatedPomodoros: dbItem.estimatedPomodoros,
      completedPomodoros: dbItem.completedPomodoros,
      sortOrder: dbItem.sortOrder,
      addedAt: dbItem.addedAt,
      task: task,
    );
  }
}
