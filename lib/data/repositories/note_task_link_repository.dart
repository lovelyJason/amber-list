import 'dart:convert';

import 'package:uuid/uuid.dart';
import '../datasources/local/database.dart' as db;
import '../models/models.dart';

/// 笔记-任务关联数据仓库
///
/// 职责：
/// - 管理笔记与任务之间的双向关联关系
/// - 提供创建、删除、查询关联的统一接口
/// - 防止重复关联（同一 noteId+taskId 只允许一条记录）
class NoteTaskLinkRepository {
  final db.AppDatabase _db;
  final Uuid _uuid = const Uuid();

  NoteTaskLinkRepository(this._db);

  /// 创建笔记-任务关联
  ///
  /// 如果关联已存在则跳过，不会抛异常
  /// 返回是否新创建了关联（false 表示已存在）
  Future<bool> linkNoteToTask(String noteId, String taskId) async {
    final exists = await _db.isNoteTaskLinked(noteId, taskId);
    if (exists) return false;

    await _db.insertNoteTaskLink(
      db.NoteTaskLinksCompanion.insert(
        id: _uuid.v4(),
        noteId: noteId,
        taskId: taskId,
        createdAt: DateTime.now(),
      ),
    );
    return true;
  }

  /// 解除笔记-任务关联
  Future<void> unlinkNoteFromTask(String noteId, String taskId) async {
    await _db.deleteNoteTaskLink(noteId, taskId);
  }

  /// 监听某笔记关联的所有任务
  Stream<List<Task>> watchLinkedTasks(String noteId) {
    return _db.watchLinkedTasksForNote(noteId).map(
          (dbTasks) => dbTasks.map(_mapDbTaskToModel).toList(),
        );
  }

  /// 监听某任务关联的所有笔记
  Stream<List<Note>> watchLinkedNotes(String taskId) {
    return _db.watchLinkedNotesForTask(taskId).map(
          (dbNotes) => dbNotes.map(_mapDbNoteToModel).toList(),
        );
  }

  /// 获取任务关联的笔记数量
  Future<int> getLinkedNotesCount(String taskId) {
    return _db.getLinkedNotesCount(taskId);
  }

  /// 删除笔记的所有关联（笔记删除时调用）
  Future<void> deleteAllLinksForNote(String noteId) {
    return _db.deleteAllLinksForNote(noteId);
  }

  /// 删除任务的所有关联（任务删除时调用）
  Future<void> deleteAllLinksForTask(String taskId) {
    return _db.deleteAllLinksForTask(taskId);
  }

  /// 将数据库任务转换为 UI 模型
  Task _mapDbTaskToModel(db.Task dbTask) {
    List<String> tags = [];
    try {
      tags = List<String>.from(jsonDecode(dbTask.tags));
    } catch (_) {}

    return Task(
      id: dbTask.id,
      title: dbTask.title,
      description: dbTask.description ?? '',
      listId: dbTask.listId,
      dueDate: dbTask.dueDate,
      priority: TaskPriority.fromValue(dbTask.priority),
      isCompleted: dbTask.isCompleted,
      isInProgress: dbTask.isInProgress,
      isDeleted: dbTask.isDeleted,
      deletedAt: dbTask.deletedAt,
      completedAt: dbTask.completedAt,
      tags: tags,
      sortOrder: dbTask.sortOrder,
      parentId: dbTask.parentId,
      autoPostpone: dbTask.autoPostpone,
      originalDueDate: dbTask.originalDueDate,
      postponeCount: dbTask.postponeCount,
      createdAt: dbTask.createdAt,
      updatedAt: dbTask.updatedAt,
    );
  }

  /// 将数据库笔记转换为 UI 模型
  Note _mapDbNoteToModel(db.Note dbNote) {
    List<String> tags = [];
    try {
      tags = List<String>.from(jsonDecode(dbNote.tags));
    } catch (_) {}

    return Note(
      id: dbNote.id,
      title: dbNote.title,
      content: dbNote.content,
      folderId: dbNote.folderId,
      tags: tags,
      isPinned: dbNote.isPinned,
      isDeleted: dbNote.isDeleted,
      deletedAt: dbNote.deletedAt,
      createdAt: dbNote.createdAt,
      updatedAt: dbNote.updatedAt,
    );
  }
}
