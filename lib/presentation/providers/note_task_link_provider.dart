import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/models.dart';
import '../../data/repositories/note_task_link_repository.dart';
import 'database_provider.dart';

/// 笔记-任务关联 Repository Provider
final noteTaskLinkRepositoryProvider = Provider<NoteTaskLinkRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return NoteTaskLinkRepository(database);
});

/// 某笔记关联的任务列表 Provider（按 noteId 参数化）
///
/// 用法：ref.watch(linkedTasksProvider(noteId))
final linkedTasksProvider =
    StreamProvider.family<List<Task>, String>((ref, noteId) {
  final repo = ref.watch(noteTaskLinkRepositoryProvider);
  return repo.watchLinkedTasks(noteId);
});

/// 某任务关联的笔记列表 Provider（按 taskId 参数化）
///
/// 用法：ref.watch(linkedNotesProvider(taskId))
final linkedNotesProvider =
    StreamProvider.family<List<Note>, String>((ref, taskId) {
  final repo = ref.watch(noteTaskLinkRepositoryProvider);
  return repo.watchLinkedNotes(taskId);
});
