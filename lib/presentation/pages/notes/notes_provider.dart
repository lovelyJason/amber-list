import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/models.dart';
import '../../../data/datasources/local/database.dart' as db;
import '../../providers/database_provider.dart';

/// 将数据库笔记对象转换为 UI 模型
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

/// 笔记状态管理 Provider
/// 使用数据库持久化存储，支持 CRUD 操作
final notesProvider = StateNotifierProvider<NotesNotifier, List<Note>>((ref) {
  final database = ref.watch(databaseProvider);
  return NotesNotifier(database);
});

/// 垃圾篓笔记 Provider
/// 监听已软删除的笔记列表
final trashNotesProvider = StreamProvider<List<Note>>((ref) {
  final database = ref.watch(databaseProvider);
  return database.watchTrashNotes().map(
        (dbNotes) => dbNotes.map(_mapDbNoteToModel).toList(),
      );
});

/// 笔记状态管理器
/// 订阅数据库 Stream，自动同步状态变更
class NotesNotifier extends StateNotifier<List<Note>> {
  final db.AppDatabase database;

  NotesNotifier(this.database) : super([]) {
    _init();
  }

  /// 初始化：订阅数据库笔记表的变更流
  /// 数据库已按 sortOrder 排序返回，这里不再额外排序
  void _init() {
    database.watchAllNotes().listen((dbNotes) {
      // 转换为 UI 模型（数据库已按 sortOrder 排序）
      final notes = dbNotes.map(_mapDbNoteToModel).toList();
      state = notes;
    });
  }

  /// 添加笔记
  Future<void> addNote(Note note) async {
    await database.insertNote(
      db.NotesCompanion.insert(
        id: note.id,
        title: note.title,
        content: drift.Value(note.content),
        folderId: drift.Value(note.folderId),
        tags: drift.Value(jsonEncode(note.tags)),
        isPinned: drift.Value(note.isPinned),
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
      ),
    );
  }

  /// 更新笔记
  Future<void> updateNote(Note updated) async {
    await database.updateNote(
      db.NotesCompanion(
        id: drift.Value(updated.id),
        title: drift.Value(updated.title),
        content: drift.Value(updated.content),
        folderId: drift.Value(updated.folderId),
        tags: drift.Value(jsonEncode(updated.tags)),
        isPinned: drift.Value(updated.isPinned),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  /// 删除笔记（软删除，移到垃圾篓）
  Future<void> deleteNote(String id) async {
    await database.softDeleteNote(id);
  }

  /// 恢复已删除的笔记
  Future<void> restoreNote(String id) async {
    await database.restoreNote(id);
  }

  /// 永久删除笔记（物理删除）
  Future<void> permanentlyDeleteNote(String id) async {
    await database.permanentlyDeleteNote(id);
  }

  /// 清空垃圾篓
  Future<int> emptyTrash() async {
    return await database.emptyNotesTrash();
  }

  /// 切换置顶状态
  Future<void> togglePin(String id) async {
    final note = state.firstWhere((n) => n.id == id);
    await database.updateNote(
      db.NotesCompanion(
        id: drift.Value(id),
        isPinned: drift.Value(!note.isPinned),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  /// 重排序置顶笔记（持久化到数据库）
  Future<void> reorderPinned(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final pinned = state.where((n) => n.isPinned).toList();
    final item = pinned.removeAt(oldIndex);
    pinned.insert(newIndex, item);

    // 合并：置顶 + 非置顶
    final unpinned = state.where((n) => !n.isPinned).toList();
    final newOrder = [...pinned, ...unpinned];

    // 立即更新UI状态
    state = newOrder;

    // 持久化排序到数据库
    await database.updateNotesOrder(newOrder.map((n) => n.id).toList());
  }

  /// 重排序非置顶笔记（持久化到数据库）
  Future<void> reorderRegular(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final unpinned = state.where((n) => !n.isPinned).toList();
    final item = unpinned.removeAt(oldIndex);
    unpinned.insert(newIndex, item);

    // 合并：置顶 + 非置顶
    final pinned = state.where((n) => n.isPinned).toList();
    final newOrder = [...pinned, ...unpinned];

    // 立即更新UI状态
    state = newOrder;

    // 持久化排序到数据库
    await database.updateNotesOrder(newOrder.map((n) => n.id).toList());
  }
}
