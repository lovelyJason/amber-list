import 'dart:convert';
import 'dart:io';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/home_widget_service.dart';
import '../../core/services/native_sticky_note_service.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/models.dart';

import '../../data/datasources/local/database.dart' as db;
import 'database_provider.dart';
import 'task_management_settings_provider.dart';
import '../pages/sticky_note/sticky_note_registry.dart';
import '../pages/sticky_note/sticky_note_page.dart';

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
    isInProgress: dbTask.isInProgress, // 进行中状态
    isDeleted: dbTask.isDeleted,
    completedAt: dbTask.completedAt,
    tags: tags,
    sortOrder: dbTask.sortOrder,
    parentId: dbTask.parentId,
    autoPostpone: dbTask.autoPostpone, // 自动顺延状态
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

  /// 删除清单/文件夹
  /// 使用安全删除方法，会先删除关联的任务及其番茄记录，避免外键约束错误
  Future<void> deleteList(String id) async {
    // 递归删除子清单/文件夹
    final children = state.where((l) => l.parentId == id).toList();
    for (var child in children) {
      await deleteList(child.id);
    }

    // 使用安全删除方法，会先删除清单下的任务再删除清单
    await database.deleteTaskListWithTasks(id);
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

      // 同步到移动端桌面小组件（Android/iOS）
      _updateHomeWidget(tasks);
    });
  }

  /// 更新移动端桌面小组件数据
  /// 仅在 Android/iOS 平台生效
  ///
  /// 数据流：
  /// - iOS Widget：直接从 App Group 共享目录的 SQLite 数据库读取
  /// - Android Widget：直接从 app_flutter 目录的 SQLite 数据库读取
  ///
  /// 重要：Flutter Drift 使用 WAL 模式，新写入的数据可能还在 .db-wal 文件中。
  /// Android 必须先执行 checkpoint 将数据合并到主数据库文件，否则 Widget 读到旧数据。
  /// iOS 不受此影响，因为数据库在 App Group 共享目录中，Widget 和 App 用同一个数据库连接。
  Future<void> _updateHomeWidget(List<Task> tasks) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      // Android 平台：先执行 checkpoint 确保 WAL 数据写入主数据库
      // 这样 Widget 直接读取 SQLite 时能获取到最新数据
      if (Platform.isAndroid) {
        await database.checkpoint();
      }
    } catch (e) {
      // checkpoint 失败不影响后续操作
      debugPrint('[TaskNotifier] checkpoint 失败: $e');
    }

    // 触发 Widget 刷新（HomeWidgetService 内部还会写 SharedPreferences，
    // 这是历史遗留代码，Android/iOS Widget 实际都从 SQLite 读数据）
    await HomeWidgetService().updateWidgetData(tasks);
  }

  /// 强制刷新任务数据
  ///
  /// 当外部（如 iOS/Android Widget）直接修改了数据库时调用
  /// 手动从数据库重新查询，更新内存状态
  Future<void> refresh() async {
    final dbTasks = await database.getAllTasks();
    final tasks = dbTasks.map(_mapDbTaskToModel).toList()
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        if (a.priority.value != b.priority.value) {
          return b.priority.value.compareTo(a.priority.value);
        }
        return b.createdAt.compareTo(a.createdAt);
      });
    state = tasks;
    // 同步更新 Widget 数据（Android 使用 SharedPreferences）
    _updateHomeWidget(tasks);
    debugPrint('[TaskNotifier] 手动刷新完成，共 ${tasks.length} 个任务');
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
        isInProgress: const drift.Value(false), // 完成/取消完成时都清除进行中状态
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
    // desktop_multi_window 0.3.0 使用 WindowMethodChannel 进行窗口间通信
    try {
      final registry = ref.read(stickyNoteRegistryProvider);
      if (task.listId != null && registry.containsKey(task.listId!)) {
        final windowId = registry[task.listId!];
        if (windowId != null && windowId.isNotEmpty) {
          // 使用命令通道向便签窗口发送更新
          const commandChannel = WindowMethodChannel(
            StickyNoteChannel.commands,
            mode: ChannelMode.unidirectional,
          );
          await commandChannel.invokeMethod('updateTask', {
            'id': id,
            'isCompleted': isCompleted,
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to sync with sticky note: $e');
    }
  }

  /// 切换任务进行中（半完成）状态
  /// 已完成的任务不能设为进行中
  Future<void> toggleTaskInProgress(String id) async {
    final task = state.firstWhere((t) => t.id == id);

    // 已完成的任务不能设为进行中
    if (task.isCompleted) return;

    final isInProgress = !task.isInProgress;
    final now = DateTime.now();

    await database.updateTask(
      db.TasksCompanion(
        id: drift.Value(id),
        isInProgress: drift.Value(isInProgress),
        updatedAt: drift.Value(now),
      ),
    );
  }

  /// 创建新任务
  ///
  /// 新任务的 autoPostpone 字段会根据全局设置 enableAutoPostpone 来决定：
  /// - 开关打开：新任务 autoPostpone=true，过期后会自动顺延到今天
  /// - 开关关闭：新任务 autoPostpone=false，过期后显示在"已过期"区域
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

    // 从设置中读取自动顺延开关状态，决定新任务的 autoPostpone 值
    final enableAutoPostpone =
        ref.read(taskManagementSettingsProvider).enableAutoPostpone;

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
        autoPostpone: drift.Value(enableAutoPostpone),
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
      autoPostpone: enableAutoPostpone,
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
  /// 返回 true 表示成功，返回 false 表示有番茄记录冲突
  Future<bool> deleteTask(String id) async {
    // 先检查是否有番茄记录
    final hasPomodoroRecords = await database.hasTaskPomodoroRecords(id);
    if (hasPomodoroRecords) {
      return false; // 有冲突，拒绝删除
    }

    await database.updateTask(
      db.TasksCompanion(
        id: drift.Value(id),
        isDeleted: const drift.Value(true),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
    return true;
  }

  /// 强制移入垃圾桶（忽略番茄记录）
  Future<void> forceDeleteTask(String id) async {
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

  /// 检查任务是否有关联的番茄记录
  Future<bool> hasTaskPomodoroRecords(String taskId) async {
    return database.hasTaskPomodoroRecords(taskId);
  }

  /// 彻底删除任务
  /// 如果任务有番茄记录，会抛出异常，需要调用 forceDeleteTaskWithPomodoros
  Future<void> permanentlyDeleteTask(String id) async {
    await database.deleteTask(id);
  }

  /// 强制删除任务及其番茄记录
  Future<void> forceDeleteTaskWithPomodoros(String id) async {
    await database.forceDeleteTaskWithPomodoros(id);
  }

  /// 清空垃圾桶（永久删除所有垃圾桶中的任务）
  /// 包括有番茄记录的任务也会被删除
  Future<void> emptyTrash() async {
    // 获取所有垃圾桶任务
    final trashTasks = state.where((t) => t.isDeleted).toList();

    // 逐个强制删除（包含番茄记录）
    for (final task in trashTasks) {
      await database.forceDeleteTaskWithPomodoros(task.id);
    }
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

  // ========== 每日任务顺延功能 ==========

  /// 执行自动顺延
  /// 在 App 启动时调用，将所有 autoPostpone=true 的过期任务顺延到今天
  /// 返回被顺延的任务数量
  ///
  /// 优化策略：
  /// - 使用 lastAutoPostponeDate 标记位避免同一天重复检查
  /// - 今天已检查过则直接跳过，不访问数据库
  /// - 第二天打开 App 时会重新检查
  Future<int> performAutoPostpone() async {
    final notifier = ref.read(taskManagementSettingsProvider.notifier);
    final taskManagementSettings = ref.read(taskManagementSettingsProvider);

    // 检查全局开关
    if (!taskManagementSettings.enableAutoPostpone) {
      debugPrint('[AutoPostpone] 全局开关已关闭，跳过自动顺延');
      return 0;
    }

    // 检查今天是否已经执行过（避免同一天重复查询数据库）
    if (notifier.hasCheckedToday()) {
      debugPrint('[AutoPostpone] 今天已检查过，跳过');
      return 0;
    }

    // 查找需要顺延的任务
    final tasksToPostpone = state.where((task) {
      // 条件：autoPostpone=true AND 已过期 AND 未完成 AND 未删除
      if (!task.autoPostpone) return false;
      if (task.isCompleted || task.isDeleted) return false;
      if (task.dueDate == null) return false;
      return AmberDateUtils.isOverdue(task.dueDate!);
    }).toList();

    // 无论是否有任务需要顺延，都标记今天已检查
    final todayStr = TaskManagementSettingsNotifier.getTodayDateString();
    notifier.setLastAutoPostponeDate(todayStr);
    debugPrint('[AutoPostpone] 已标记今日($todayStr)检查完成');

    if (tasksToPostpone.isEmpty) {
      debugPrint('[AutoPostpone] 没有需要顺延的任务');
      return 0;
    }

    // 批量顺延
    final today = AmberDateUtils.normalizeToUtcDate(DateTime.now());
    final now = DateTime.now();

    for (final task in tasksToPostpone) {
      await database.updateTask(
        db.TasksCompanion(
          id: drift.Value(task.id),
          dueDate: drift.Value(today),
          updatedAt: drift.Value(now),
        ),
      );
    }

    debugPrint('[AutoPostpone] 已自动顺延 ${tasksToPostpone.length} 个任务到今天');
    return tasksToPostpone.length;
  }

  /// 批量顺延指定任务到今天
  /// [taskIds] 要顺延的任务 ID 列表
  Future<void> postponeTasks(List<String> taskIds) async {
    if (taskIds.isEmpty) return;

    final today = AmberDateUtils.normalizeToUtcDate(DateTime.now());
    final now = DateTime.now();

    for (final taskId in taskIds) {
      await database.updateTask(
        db.TasksCompanion(
          id: drift.Value(taskId),
          dueDate: drift.Value(today),
          updatedAt: drift.Value(now),
        ),
      );
    }

    debugPrint('[Postpone] 已手动顺延 ${taskIds.length} 个任务到今天');
  }

  /// 顺延所有过期任务到今天
  /// 用于"全部顺延"按钮
  Future<void> postponeAllOverdueTasks() async {
    final overdueTasks = state.where((task) {
      if (task.isCompleted || task.isDeleted) return false;
      if (task.dueDate == null) return false;
      return AmberDateUtils.isOverdue(task.dueDate!);
    }).toList();

    await postponeTasks(overdueTasks.map((t) => t.id).toList());
  }

  /// 顺延单个任务到今天
  Future<void> postponeTask(String taskId) async {
    await postponeTasks([taskId]);
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

// ========== 每日任务顺延相关 Provider ==========

/// 已过期任务 Provider
/// 返回所有未完成、未删除、且截止日期早于今天的任务
final overdueTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(taskProvider);

  return tasks.where((task) {
    if (task.isCompleted || task.isDeleted) return false;
    if (task.dueDate == null) return false;
    return AmberDateUtils.isOverdue(task.dueDate!);
  }).toList()
    // 按截止日期倒序排列（最早过期的在前）
    ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
});

/// 今天视图数据模型
/// 包含今天的任务和已过期的任务
class TodayViewTasks {
  /// 今天的任务（截止日期是今天）
  final List<Task> todayTasks;

  /// 已过期的任务（截止日期早于今天）
  final List<Task> overdueTasks;

  const TodayViewTasks({
    required this.todayTasks,
    required this.overdueTasks,
  });

  /// 是否有过期任务
  bool get hasOverdue => overdueTasks.isNotEmpty;

  /// 总任务数（今天 + 过期）
  int get totalCount => todayTasks.length + overdueTasks.length;

  /// 未完成任务数
  int get pendingCount {
    final todayPending = todayTasks.where((t) => !t.isCompleted).length;
    final overduePending = overdueTasks.where((t) => !t.isCompleted).length;
    return todayPending + overduePending;
  }
}

/// 今天视图任务 Provider
/// 返回今天的任务和已过期的任务，用于"今天"视图显示
final todayViewTasksProvider = Provider<TodayViewTasks>((ref) {
  final tasks = ref.watch(taskProvider);

  final todayTasks = <Task>[];
  final overdueTasks = <Task>[];

  for (final task in tasks) {
    if (task.isCompleted || task.isDeleted) continue;
    if (task.dueDate == null) continue;

    if (AmberDateUtils.isToday(task.dueDate!)) {
      todayTasks.add(task);
    } else if (AmberDateUtils.isOverdue(task.dueDate!)) {
      overdueTasks.add(task);
    }
  }

  // 今天的任务按优先级和创建时间排序
  todayTasks.sort((a, b) {
    if (a.priority.value != b.priority.value) {
      return b.priority.value.compareTo(a.priority.value);
    }
    return b.createdAt.compareTo(a.createdAt);
  });

  // 过期任务按截止日期排序（最早过期的在前）
  overdueTasks.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

  return TodayViewTasks(
    todayTasks: todayTasks,
    overdueTasks: overdueTasks,
  );
});
