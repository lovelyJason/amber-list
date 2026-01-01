import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/native_sticky_note_service.dart';
import '../../data/models/models.dart';

import '../../data/datasources/local/database.dart' as db;
import 'database_provider.dart';
import '../pages/sticky_note/sticky_note_registry.dart';

const _uuid = Uuid();

// ===== Helpers for Mapping =====

IconData _getIconData(String iconName) {
  switch (iconName) {
    case 'work':
      return Icons.work_outline_rounded;
    case 'person':
      return Icons.person_outline_rounded;
    case 'shopping_cart':
      return Icons.shopping_cart_outlined;
    case 'list':
    default:
      return Icons.list_rounded;
  }
}

String _getIconName(IconData icon) {
  if (icon == Icons.work_outline_rounded) return 'work';
  if (icon == Icons.person_outline_rounded) return 'person';
  if (icon == Icons.shopping_cart_outlined) return 'shopping_cart';
  return 'list';
}

TaskList _mapDbListToModel(db.TaskList dbList) {
  List<String> tags = [];
  try {
    tags = List<String>.from(jsonDecode(dbList.tags));
  } catch (_) {}

  return TaskList(
    id: dbList.id,
    name: dbList.name,
    icon: _getIconData(dbList.icon),
    color: Color(dbList.color),
    sortOrder: dbList.sortOrder,
    createdAt: dbList.createdAt,
    updatedAt: dbList.updatedAt,
    parentId: dbList.parentId,
    isFolder: dbList.isFolder,
    tags: tags,
  );
}

Task _mapDbTaskToModel(db.Task dbTask) {
  List<String> tags = [];
  try {
    tags = List<String>.from(jsonDecode(dbTask.tags));
  } catch (_) {}

  return Task(
    id: dbTask.id,
    title: dbTask.title,
    description: dbTask.description,
    listId: dbTask.listId,
    dueDate: dbTask.dueDate,
    priority: TaskPriority.fromValue(dbTask.priority),
    isCompleted: dbTask.isCompleted,
    isDeleted: dbTask.isDeleted,
    completedAt: dbTask.completedAt,
    tags: tags,
    sortOrder: dbTask.sortOrder,
    parentId: dbTask.parentId,
    createdAt: dbTask.createdAt,
    updatedAt: dbTask.updatedAt,
  );
}

Tag _mapDbTagToModel(db.Tag dbTag) {
  return Tag(
    id: dbTag.id,
    name: dbTag.name,
    color: Color(dbTag.color),
    createdAt: dbTag.createdAt,
  );
}

// ===== Notifiers =====

/// 清单列表Provider
class TaskListNotifier extends StateNotifier<List<TaskList>> {
  final db.AppDatabase database;

  TaskListNotifier(this.database) : super([]) {
    _init();
  }

  void _init() {
    database.watchAllTaskLists().listen((dbLists) {
      // 保持排序
      final lists = dbLists.map(_mapDbListToModel).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      state = lists;
    });
  }

  /// 添加清单
  Future<void> addList(
    String name,
    Color color, {
    IconData icon = Icons.list_rounded,
    String? parentId,
    List<String> tags = const [],
  }) async {
    final now = DateTime.now();
    await database.insertTaskList(
      db.TaskListsCompanion.insert(
        id: _uuid.v4(),
        name: name,
        icon: drift.Value(_getIconName(icon)),
        color: color.value,
        sortOrder: drift.Value(state.length),
        createdAt: now,
        updatedAt: now,
        parentId: drift.Value(parentId),
        isFolder: const drift.Value(false),
        tags: drift.Value(jsonEncode(tags)),
      ),
    );
  }

  /// 创建文件夹 (Group)
  Future<void> createFolder(String name, {String? parentId}) async {
    final now = DateTime.now();
    await database.insertTaskList(
      db.TaskListsCompanion.insert(
        id: _uuid.v4(),
        name: name,
        icon: const drift.Value(
          'folder',
        ), // Use a folder icon key if available or default
        color: 0, // Folders might not need color, or use default
        sortOrder: drift.Value(state.length),
        createdAt: now,
        updatedAt: now,
        parentId: drift.Value(parentId),
        isFolder: const drift.Value(true),
      ),
    );
  }

  /// 更新清单
  Future<void> updateList(TaskList updated) async {
    await database.updateTaskList(
      db.TaskListsCompanion(
        id: drift.Value(updated.id),
        name: drift.Value(updated.name),
        icon: drift.Value(_getIconName(updated.icon)),
        color: drift.Value(updated.color.value),
        sortOrder: drift.Value(updated.sortOrder),
        parentId: drift.Value(updated.parentId),
        tags: drift.Value(jsonEncode(updated.tags)),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  /// 移动清单/文件夹
  Future<void> moveList(String listId, String? newParentId) async {
    final list = state.firstWhere((l) => l.id == listId);
    final updated = list.copyWith(parentId: newParentId);
    await updateList(updated);
  }

  /// 重命名
  Future<void> renameList(String id, String newName) async {
    final list = state.firstWhere((l) => l.id == id);
    final updated = list.copyWith(name: newName);
    await updateList(updated);
  }

  /// 置顶 (简单实现：将 sortOrder 设为当前最小 - 1)
  Future<void> pinList(String id) async {
    if (state.isEmpty) return;
    final minOrder = state
        .map((e) => e.sortOrder)
        .reduce((a, b) => a < b ? a : b);
    final list = state.firstWhere((l) => l.id == id);
    // 如果已经是最小且和其他不冲突（虽难判断），或者为了简便，直接减1
    final updated = list.copyWith(sortOrder: minOrder - 1);
    await updateList(updated);
  }

  /// 解散文件夹 (只删除文件夹，保留子项并移至同级)
  Future<void> disbandFolder(String folderId) async {
    final folder = state.firstWhere((l) => l.id == folderId);
    final children = state.where((l) => l.parentId == folderId).toList();

    // 1. 将子项移出 (提升一级)
    for (var child in children) {
      await updateList(child.copyWith(parentId: folder.parentId));
    }

    // 2. 删除文件夹
    await deleteList(folderId);
  }

  /// 删除清单/文件夹 (注意：如果是文件夹，需要根据需求决定是否级联删除。目前 deleteList 仅删除自身)
  Future<void> deleteList(String id) async {
    // 简单的级联删除防止孤儿：如果删除的是文件夹，其子项也删除？
    // 或者目前保持简单：用户应先清空或解散。
    // 为了防止孤儿数据，这里做一个简单的级联删除逻辑 (Optional)
    // 但用户需求里有 "Disband" 和 "Delete".
    // "Delete" for list implies delete. "Delete" for folder usually means delete all.
    // "Disband" means keep children.
    // Let's safe delete children for now to avoid database inconsistencies if we don't have constraints.
    // BUT, Drift usually implies we handle this.
    // Let's just delete the node. Orphans might appear in "All" or just disappear from tree.
    // Given the tree build logic `childrenMap.putIfAbsent(list.parentId!, ...)`
    // if parent doesn't exist in `allLists`, they won't be in `childrenMap` but `rootLists` only takes `parentId == null`.
    // So orphans with non-null `parentId` (that doesn't exist) will vanish from UI.
    // This is "Safe" in terms of UI not crashing, but data is hidden.
    // I will implement recursive delete for `deleteList`.

    final children = state.where((l) => l.parentId == id).toList();
    for (var child in children) {
      await deleteList(child.id); // Recursive delete
    }

    await database.deleteTaskList(id);
  }
}

final taskListProvider =
    StateNotifierProvider<TaskListNotifier, List<TaskList>>((ref) {
      final database = ref.watch(databaseProvider);
      return TaskListNotifier(database);
    });

/// 任务列表Provider
class TaskNotifier extends StateNotifier<List<Task>> {
  final db.AppDatabase database;
  final Ref ref;

  TaskNotifier(this.database, this.ref) : super([]) {
    _init();
  }

  void _init() {
    database.watchAllTasks().listen((dbTasks) {
      final tasks = dbTasks.map(_mapDbTaskToModel).toList()
        ..sort((a, b) {
          // 简单排序：未完成在前，高优先级在前，创建时间倒序
          if (a.isCompleted != b.isCompleted) {
            return a.isCompleted ? 1 : -1;
          }
          if (a.priority.value != b.priority.value) {
            return b.priority.value.compareTo(a.priority.value); // High to Low
          }
          return b.createdAt.compareTo(a.createdAt);
        });
      state = tasks;
    });
  }

  /// 切换任务完成状态
  Future<void> toggleTaskComplete(String id) async {
    final task = state.firstWhere((t) => t.id == id);
    final isCompleted = !task.isCompleted;
    final now = DateTime.now();

    await database.updateTask(
      db.TasksCompanion(
        id: drift.Value(id),
        isCompleted: drift.Value(isCompleted),
        completedAt: drift.Value(isCompleted ? now : null),
        updatedAt: drift.Value(now),
      ),
    );

    // ========== 同步到原生便签窗口 ==========
    try {
      final nativeService = NativeStickyNoteService.instance;
      if (nativeService.isSupported && task.listId != null) {
        // 检查该列表的便签是否打开
        if (nativeService.openNotes.contains(task.listId)) {
          // 获取该列表的所有任务，重新构建任务列表
          final listTasks = state.where((t) => t.listId == task.listId).toList();

          // 更新当前任务的状态（因为 state 还没更新，需要手动调整）
          final activeTasks = <Map<String, dynamic>>[];
          final completedTasks = <Map<String, dynamic>>[];

          for (final t in listTasks) {
            final taskCompleted = t.id == id ? isCompleted : t.isCompleted;
            final taskData = {
              'id': t.id,
              'title': t.title,
              'isCompleted': taskCompleted,
            };
            if (taskCompleted) {
              completedTasks.add(taskData);
            } else {
              activeTasks.add(taskData);
            }
          }

          await nativeService.updateStickyNote(
            id: task.listId!,
            activeTasks: activeTasks,
            completedTasks: completedTasks,
          );
          debugPrint('[TaskProvider] 已同步到原生便签: ${task.listId}');
        }
      }
    } catch (e) {
      debugPrint('[TaskProvider] 同步原生便签失败: $e');
    }

    // ========== Fallback: 同步到 Flutter 多窗口 ==========
    try {
      final registry = ref.read(stickyNoteRegistryProvider);
      if (task.listId != null && registry.containsKey(task.listId!)) {
        final windowId = registry[task.listId!];
        if (windowId != null) {
          await DesktopMultiWindow.invokeMethod(windowId, 'updateTask', {
            'id': id,
            'isCompleted': isCompleted,
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to sync with sticky note: $e');
    }
  }

  /// 创建新任务
  Future<Task> createTask({
    required String title,
    String? description,
    String? listId,
    DateTime? dueDate,
    TaskPriority priority = TaskPriority.none,
    List<String> tags = const [],
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();

    await database.insertTask(
      db.TasksCompanion.insert(
        id: id,
        title: title,
        description: drift.Value(description),
        listId: drift.Value(listId),
        dueDate: drift.Value(dueDate),
        priority: drift.Value(priority.value),
        tags: drift.Value(jsonEncode(tags)),
        isCompleted: const drift.Value(false),
        isDeleted: const drift.Value(false),
        createdAt: now,
        updatedAt: now,
      ),
    );

    // Sync tags automatically
    for (var tagName in tags) {
      await _ensureTagExists(tagName);
    }

    // 这里由于是异步，返回的 task 其实还没有被 DB stream 更新回来。
    // 我们手动构建一个 Task 对象返回给 UI 用（如果 UI 需要立即使用），或者 UI 应该监听 provider 变化。
    // 通常 UI 会等待 provider 更新。
    // 返回构建的对象以备不时之需。
    return Task(
      id: id,
      title: title,
      description: description,
      listId: listId,
      dueDate: dueDate,
      priority: priority,
      tags: tags,
      isCompleted: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 更新任务
  Future<void> updateTask(Task updated) async {
    await database.updateTask(
      db.TasksCompanion(
        id: drift.Value(updated.id),
        title: drift.Value(updated.title),
        description: drift.Value(updated.description),
        listId: drift.Value(updated.listId),
        dueDate: drift.Value(updated.dueDate),
        priority: drift.Value(updated.priority.value),
        tags: drift.Value(jsonEncode(updated.tags)),
        parentId: drift.Value(updated.parentId),
        isDeleted: drift.Value(updated.isDeleted),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  /// 移入垃圾桶（软删除）
  Future<void> deleteTask(String id) async {
    await database.updateTask(
      db.TasksCompanion(
        id: drift.Value(id),
        isDeleted: const drift.Value(true),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  /// 恢复任务
  Future<void> restoreTask(String id) async {
    await database.updateTask(
      db.TasksCompanion(
        id: drift.Value(id),
        isDeleted: const drift.Value(false),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  /// 彻底删除
  Future<void> permanentlyDeleteTask(String id) async {
    await database.deleteTask(id);
  }

  Future<void> _ensureTagExists(String tagName) async {
    final tags = await database.getAllTags();
    if (!tags.any((t) => t.name == tagName)) {
      await database.insertTag(
        db.TagsCompanion.insert(
          id: _uuid.v4(),
          name: tagName,
          color: Colors.blue.value,
          createdAt: DateTime.now(),
        ),
      );
    }
  }
}

/// 标签列表Provider
class TagNotifier extends StateNotifier<List<Tag>> {
  final db.AppDatabase database;

  TagNotifier(this.database) : super([]) {
    _init();
  }

  void _init() {
    database.watchAllTags().listen((dbTags) {
      debugPrint(
        '[TagNotifier] Fetched ${dbTags.length} tags from DB: ${dbTags.map((e) => e.name).toList()}',
      );
      final tags = dbTags.map(_mapDbTagToModel).toList()
        ..sort(
          (a, b) => a.createdAt.compareTo(b.createdAt),
        ); // Sort by creation time
      state = tags;
    });

    // 初始同步：scan existing tasks for tags
    syncTags();
  }

  Future<void> syncTags() async {
    final tasks = await database.getAllTasks();
    final existingTags = await database.getAllTags();
    final Set<String> knownTagNames = existingTags.map((t) => t.name).toSet();
    final Set<String> newTags = {};

    for (var taskDb in tasks) {
      try {
        final List<dynamic> tagList = jsonDecode(taskDb.tags);
        for (var tag in tagList) {
          if (tag is String && !knownTagNames.contains(tag)) {
            newTags.add(tag);
          }
        }
      } catch (_) {}
    }

    for (var tagName in newTags) {
      await addTag(tagName, Colors.blue); // Default color
      knownTagNames.add(tagName); // Avoid double insert
    }
  }

  /// 添加标签
  Future<void> addTag(String name, Color color) async {
    final now = DateTime.now();
    await database.insertTag(
      db.TagsCompanion.insert(
        id: _uuid.v4(),
        name: name,
        color: color.value,
        createdAt: now,
      ),
    );
  }

  /// 更新标签
  Future<void> updateTag(Tag updated, String oldName) async {
    // 1. Update Tag in DB
    await database
        .update(database.tags)
        .replace(
          db.TagsCompanion(
            id: drift.Value(updated.id),
            name: drift.Value(updated.name),
            color: drift.Value(updated.color.value),
            createdAt: drift.Value(updated.createdAt),
          ),
        );

    // 2. If name changed, update all tasks
    if (updated.name != oldName) {
      final tasks = await database.getAllTasks();
      for (var taskDb in tasks) {
        try {
          List<String> tags = List<String>.from(jsonDecode(taskDb.tags));
          if (tags.contains(oldName)) {
            final index = tags.indexOf(oldName);
            tags[index] = updated.name;
            await database.updateTask(
              db.TasksCompanion(
                id: drift.Value(taskDb.id),
                tags: drift.Value(jsonEncode(tags)),
              ),
            );
          }
        } catch (_) {}
      }
    }
  }

  /// 删除标签
  Future<void> deleteTag(String id) async {
    // 1. Get tag name before delete
    final tag = state.where((t) => t.id == id).firstOrNull;
    if (tag == null) return;

    // 2. Delete from DB
    await database.deleteTag(id);

    // 3. Remove tag name from all tasks
    final tasks = await database.getAllTasks();
    for (var taskDb in tasks) {
      try {
        final List<dynamic> rawTags = jsonDecode(taskDb.tags);
        List<String> tags = rawTags.map((e) => e.toString()).toList();

        if (tags.contains(tag.name)) {
          tags.remove(tag.name);
          await database.updateTask(
            db.TasksCompanion(
              id: drift.Value(taskDb.id),
              tags: drift.Value(jsonEncode(tags)),
            ),
          );
        }
      } catch (_) {}
    }
  }

  /// 解决标签冲突
  /// [local] 本地标签数据
  /// [remote] 远程标签数据
  /// forceRemote: true = 使用远程覆盖本地
  Future<void> resolveConflict(
    Map<String, dynamic> local,
    Map<String, dynamic> remote, {
    required bool useRemote,
  }) async {
    if (useRemote) {
      // 1. Delete local tag
      await database.deleteTag(local['id'] as String);

      // 2. Insert remote tag
      // Convert map back to companion or insert directly
      // Since map has all fields, we can use raw insert or companion
      // Use raw insert for simplicity as we have full map
      await database
          .into(database.tags)
          .insert(
            db.TagsCompanion.insert(
              id: remote['id'] as String,
              name: remote['name'] as String,
              color: remote['color'] as int,
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                (remote['created_at'] as int) * 1000,
              ),
            ),
          );
    }
    // If useLocal, do nothing (we kept the local tag, and ignored the remote one during merge)
  }
}

final taskProvider = StateNotifierProvider<TaskNotifier, List<Task>>((ref) {
  final database = ref.watch(databaseProvider);
  return TaskNotifier(database, ref);
});

final tagsProvider = StateNotifierProvider<TagNotifier, List<Tag>>((ref) {
  final database = ref.watch(databaseProvider);
  return TagNotifier(database);
});

// ===== Derived Providers =====

/// 今日任务Provider
final todayTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(taskProvider);
  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);
  final todayEnd = todayStart.add(const Duration(days: 1));

  return tasks.where((t) {
    if (t.isDeleted) return false; // Filter deleted
    // Removed isCompleted filter to show completed tasks
    if (t.dueDate == null) return false;
    return t.dueDate!.isAfter(
          todayStart.subtract(const Duration(seconds: 1)),
        ) &&
        t.dueDate!.isBefore(todayEnd);
  }).toList();
});

/// 最近7天任务Provider
final upcomingTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(taskProvider);
  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);
  final weekEnd = todayStart.add(const Duration(days: 7));

  return tasks.where((t) {
    if (t.isDeleted) return false; // Filter deleted
    // Removed isCompleted filter to show completed tasks
    if (t.dueDate == null) return false;
    return t.dueDate!.isAfter(
          todayStart.subtract(const Duration(seconds: 1)),
        ) &&
        t.dueDate!.isBefore(weekEnd);
  }).toList();
});

/// 收集箱任务Provider（无清单的任务）
final inboxTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(taskProvider);
  return tasks
      .where((t) => t.listId == null && !t.isDeleted) // Removed !t.isCompleted
      .toList();
});

/// 按清单筛选任务Provider
final tasksByListProvider = Provider.family<List<Task>, String>((ref, listId) {
  final tasks = ref.watch(taskProvider);
  return tasks
      .where((t) => t.listId == listId && !t.isDeleted)
      .toList(); // Removed !t.isCompleted
});

/// 已完成任务Provider (Not deleted)
final completedTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(taskProvider);
  return tasks.where((t) => t.isCompleted && !t.isDeleted).toList();
});

/// 垃圾桶任务Provider (Deleted)
final trashTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(taskProvider);
  return tasks.where((t) => t.isDeleted).toList();
});
