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
import '../../data/repositories/note_task_link_repository.dart';
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
    deletedAt: dbTask.deletedAt, // 删除时间（30天自动清理用）
    completedAt: dbTask.completedAt,
    tags: tags,
    sortOrder: dbTask.sortOrder,
    parentId: dbTask.parentId,
    autoPostpone: dbTask.autoPostpone, // 自动顺延状态
    originalDueDate: dbTask.originalDueDate, // 首次截止日期（统计用）
    postponeCount: dbTask.postponeCount, // 顺延次数（统计用）
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

  /// 移动清单/文件夹到新的父级
  /// [newParentId] 为 null 表示移到根目录
  Future<void> moveList(String listId, String? newParentId) async {
    final list = state.firstWhere((l) => l.id == listId);
    // 注意：当 newParentId 为 null（根目录）时，需要用 clearParentId=true
    final updated = newParentId == null
        ? list.copyWith(clearParentId: true)
        : list.copyWith(parentId: newParentId);
    await updateList(updated);
  }

  /// 拖拽排序：移动清单/文件夹到指定位置
  ///
  /// [draggedId] 被拖动的项目 ID
  /// [targetId] 目标位置的项目 ID
  /// [insertBefore] true=插入到目标前面，false=插入到目标后面
  /// [newParentId] 新的父级 ID（null=根目录），如果不传则保持原父级
  ///
  /// 排序逻辑：
  /// 1. 获取同一层级（相同 parentId）的所有项目
  /// 2. 将被拖动项从原位置移除
  /// 3. 将被拖动项插入到目标位置的前面或后面
  /// 4. 重新计算所有项目的 sortOrder
  Future<void> reorderList({
    required String draggedId,
    required String targetId,
    required bool insertBefore,
    String? newParentId,
  }) async {
    // 被拖动的项目
    final dragged = state.firstWhere((l) => l.id == draggedId);
    // 目标项目
    final target = state.firstWhere((l) => l.id == targetId);

    // 确定新的父级（如果提供则使用，否则使用目标项目的父级）
    final effectiveParentId = newParentId ?? target.parentId;

    debugPrint('[reorderList] 开始: dragged=${dragged.name}(parentId=${dragged.parentId}), target=${target.name}(parentId=${target.parentId}), effectiveParentId=$effectiveParentId, insertBefore=$insertBefore');

    // 获取目标层级的所有项目（按 sortOrder 排序）
    final siblings = state
        .where((l) => l.parentId == effectiveParentId)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // ========== 同级无效拖动检测 ==========
    // 如果在同一层级内拖动，且位置实际没变，直接返回避免无谓的数据库操作
    if (dragged.parentId == effectiveParentId) {
      final draggedIndex = siblings.indexWhere((l) => l.id == draggedId);
      final targetIdx = siblings.indexWhere((l) => l.id == targetId);

      // 拖到自己的前面（实际位置不变）
      if (insertBefore && targetIdx == draggedIndex) {
        debugPrint('[reorderList] 位置未变，跳过更新');
        return;
      }
      // 拖到自己的后面（实际位置不变）
      if (!insertBefore && targetIdx == draggedIndex) {
        debugPrint('[reorderList] 位置未变，跳过更新');
        return;
      }
      // 拖到相邻项目的相邻位置（实际位置不变）
      // 例如：[A, B] 把 B 拖到 A 后面，或把 A 拖到 B 前面
      if (insertBefore && targetIdx == draggedIndex + 1) {
        debugPrint('[reorderList] 位置未变（拖到后一项前面），跳过更新');
        return;
      }
      if (!insertBefore && targetIdx == draggedIndex - 1) {
        debugPrint('[reorderList] 位置未变（拖到前一项后面），跳过更新');
        return;
      }
    }

    // 如果被拖动项目跨层级移动，需要先从原层级移除
    // 如果在同一层级内移动，也需要从列表中移除再插入
    siblings.removeWhere((l) => l.id == draggedId);

    // 找到目标在新列表中的索引
    final targetIndex = siblings.indexWhere((l) => l.id == targetId);

    // 计算插入位置
    final insertIndex = insertBefore ? targetIndex : targetIndex + 1;

    // 插入被拖动项
    siblings.insert(insertIndex, dragged);

    // 构建批量更新的 Map
    final updates = <String, int>{};
    for (int i = 0; i < siblings.length; i++) {
      final item = siblings[i];
      // 所有项目都需要更新 sortOrder
      updates[item.id] = i;
    }

    // 如果父级发生变化，需要额外更新 parentId 和原层级的 sortOrder
    if (dragged.parentId != effectiveParentId) {
      debugPrint('[reorderList] 检测到跨层级移动! 原parentId=${dragged.parentId}, 新parentId=$effectiveParentId');
      // 更新被拖动项的 parentId
      // 注意：当 effectiveParentId 为 null（根目录）时，需要用 clearParentId=true
      // 因为 copyWith 的 parentId ?? this.parentId 无法区分"没传参数"和"传了null"
      final updatedDragged = effectiveParentId == null
          ? dragged.copyWith(
              clearParentId: true, // 移到根目录
              sortOrder: insertIndex,
            )
          : dragged.copyWith(
              parentId: effectiveParentId,
              sortOrder: insertIndex,
            );
      debugPrint('[reorderList] 正在更新 parentId...');
      await updateList(updatedDragged);
      debugPrint('[reorderList] parentId 更新完成');
      // 从 updates 中移除，避免重复更新
      updates.remove(draggedId);

      // 更新原层级的 sortOrder（填补空缺）
      final originalSiblings = state
          .where((l) => l.parentId == dragged.parentId && l.id != draggedId)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      final originalUpdates = <String, int>{};
      for (int i = 0; i < originalSiblings.length; i++) {
        originalUpdates[originalSiblings[i].id] = i;
      }

      if (originalUpdates.isNotEmpty) {
        await database.reorderTaskLists(originalUpdates);
      }
    }

    // 批量更新新层级的 sortOrder
    if (updates.isNotEmpty) {
      await database.reorderTaskLists(updates);
    }

    debugPrint(
        '[reorderList] 拖动 ${dragged.name} 到 ${target.name} ${insertBefore ? "前面" : "后面"}, 新父级: ${effectiveParentId ?? "根目录"}');
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

  /// 解散文件夹（递归解散所有子文件夹，只保留清单）
  ///
  /// 逻辑：
  /// 1. 递归收集所有后代清单（非文件夹）
  /// 2. 递归收集所有后代文件夹（需要删除的）
  /// 3. 将所有清单的 parentId 改为当前文件夹的 parentId（提升到目标层级）
  /// 4. 删除所有文件夹（包括当前文件夹和所有子文件夹）
  ///
  /// 示例：解散目录1
  /// - 目录1
  ///   - 清单A
  ///   - 目录2
  ///     - 清单B
  /// 结果：
  /// - 清单A（移到根目录）
  /// - 清单B（移到根目录）
  /// - 目录1 和 目录2 被删除
  Future<void> disbandFolder(String folderId) async {
    final folder = state.firstWhere((l) => l.id == folderId);
    final newParentId = folder.parentId; // 目标父级（文件夹的父级）

    // 递归收集所有后代
    final allLists = <String>[]; // 所有清单 ID（需要移动）
    final allFolders = <String>[]; // 所有文件夹 ID（需要删除）

    void collectDescendants(String parentId) {
      final children = state.where((l) => l.parentId == parentId).toList();
      for (var child in children) {
        if (child.isFolder) {
          allFolders.add(child.id);
          collectDescendants(child.id); // 递归收集子文件夹的内容
        } else {
          allLists.add(child.id);
        }
      }
    }

    collectDescendants(folderId);
    allFolders.add(folderId); // 加上当前文件夹本身

    debugPrint('[disbandFolder] 解散文件夹: ${folder.name} (id=$folderId)');
    debugPrint('[disbandFolder] 目标 parentId: ${newParentId ?? "根目录"}');
    debugPrint('[disbandFolder] 找到 ${allLists.length} 个清单需要移动');
    debugPrint('[disbandFolder] 找到 ${allFolders.length} 个文件夹需要删除');

    // 使用数据库事务，确保所有操作原子性完成
    await database.disbandFolderRecursive(folderId, newParentId, allLists, allFolders);
    debugPrint('[disbandFolder] 完成');
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
      final tasks = _sortTasks(dbTasks.map(_mapDbTaskToModel).toList());

      // 避免数据相同时重复刷新 UI（防止启动闪屏）
      // Drift 的 watch stream 可能在数据不变时也触发回调
      if (_isTaskListEqual(state, tasks)) {
        return;
      }

      state = tasks;

      // 同步到移动端桌面小组件（Android/iOS）
      _updateHomeWidget(tasks);
    });
  }

  /// 任务排序逻辑（提取公共方法）
  List<Task> _sortTasks(List<Task> tasks) {
    return tasks
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
  }

  /// 比较两个任务列表是否内容相同
  /// 用于避免 Drift watch stream 重复触发导致的无意义 UI 刷新
  bool _isTaskListEqual(List<Task> oldList, List<Task> newList) {
    if (oldList.length != newList.length) return false;
    for (int i = 0; i < oldList.length; i++) {
      if (oldList[i].id != newList[i].id ||
          oldList[i].title != newList[i].title ||
          oldList[i].isCompleted != newList[i].isCompleted ||
          oldList[i].dueDate != newList[i].dueDate ||
          oldList[i].priority != newList[i].priority ||
          oldList[i].updatedAt != newList[i].updatedAt) {
        return false;
      }
    }
    return true;
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
    // debugPrint('[TaskNotifier] 手动刷新完成，共 ${tasks.length} 个任务');
  }

  /// 切换任务完成状态
  ///
  /// 返回关联笔记数量（仅在标记完成时返回，用于回顾提示）
  /// 取消完成或无关联笔记时返回 0
  Future<int> toggleTaskComplete(String id) async {
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

    // 完成任务时检查关联笔记数量（用于回顾提示）
    if (isCompleted) {
      try {
        final linkRepo = NoteTaskLinkRepository(database);
        return await linkRepo.getLinkedNotesCount(id);
      } catch (_) {}
    }
    return 0;
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
        // 如果创建时设置了截止日期，记录为原始截止日期（统计达成率用）
        originalDueDate: drift.Value(dueDate),
        postponeCount: const drift.Value(0),
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
      originalDueDate: dueDate, // 创建时的截止日期即为原始截止日期
      postponeCount: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 更新任务
  /// 注意：如果任务之前没有 originalDueDate，但这次设置了 dueDate，
  /// 会自动设置 originalDueDate（用于统计达成率）
  Future<void> updateTask(Task updated) async {
    // 检查是否需要设置 originalDueDate
    DateTime? originalDueDateToSet;
    if (updated.dueDate != null && updated.originalDueDate == null) {
      // 首次设置截止日期，记录为原始截止日期
      originalDueDateToSet = updated.dueDate;
    }

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
        // 首次设置截止日期时记录原始日期
        originalDueDate: originalDueDateToSet != null
            ? drift.Value(originalDueDateToSet)
            : const drift.Value.absent(),
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

    final now = DateTime.now();
    await database.updateTask(
      db.TasksCompanion(
        id: drift.Value(id),
        isDeleted: const drift.Value(true),
        deletedAt: drift.Value(now), // 记录删除时间（30天自动清理用）
        updatedAt: drift.Value(now),
      ),
    );
    return true;
  }

  /// 强制移入垃圾桶（忽略番茄记录）
  Future<void> forceDeleteTask(String id) async {
    final now = DateTime.now();
    await database.updateTask(
      db.TasksCompanion(
        id: drift.Value(id),
        isDeleted: const drift.Value(true),
        deletedAt: drift.Value(now), // 记录删除时间（30天自动清理用）
        updatedAt: drift.Value(now),
      ),
    );
  }

  /// 恢复任务
  /// 恢复时清除 deletedAt，这样如果再次删除会重新计算 30 天
  Future<void> restoreTask(String id) async {
    await database.updateTask(
      db.TasksCompanion(
        id: drift.Value(id),
        isDeleted: const drift.Value(false),
        deletedAt: const drift.Value(null), // 清除删除时间
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

    if (!taskManagementSettings.enableAutoPostpone) return 0;

    if (await notifier.hasCheckedToday()) return 0;

    // 直接从数据库查询过期任务（不依赖 state，避免同步后 state 未更新的时序问题）
    final allDbTasks = await database.getAllTasks();

    final tasksToPostpone = allDbTasks.where((dbTask) {
      // 条件：autoPostpone=true AND 已过期 AND 未完成 AND 未删除
      if (!dbTask.autoPostpone) return false;
      if (dbTask.isCompleted || dbTask.isDeleted) return false;
      if (dbTask.dueDate == null) return false;
      return AmberDateUtils.isOverdue(dbTask.dueDate!);
    }).toList();

    // 无论是否有任务需要顺延，都标记今天已检查（含时分秒）
    final nowStr = TaskManagementSettingsNotifier.getNowDateTimeString();
    notifier.setLastAutoPostponeDate(nowStr);

    if (tasksToPostpone.isEmpty) return 0;

    // 批量顺延
    final today = AmberDateUtils.normalizeToUtcDate(DateTime.now());
    final now = DateTime.now();

    for (final dbTask in tasksToPostpone) {
      await database.updateTask(
        db.TasksCompanion(
          id: drift.Value(dbTask.id),
          dueDate: drift.Value(today),
          // 顺延次数 +1（用于统计达成率）
          postponeCount: drift.Value(dbTask.postponeCount + 1),
          updatedAt: drift.Value(now),
        ),
      );
    }

    return tasksToPostpone.length;
  }

  /// 批量顺延指定任务到今天
  /// [taskIds] 要顺延的任务 ID 列表
  Future<void> postponeTasks(List<String> taskIds) async {
    if (taskIds.isEmpty) return;

    final today = AmberDateUtils.normalizeToUtcDate(DateTime.now());
    final now = DateTime.now();

    // 获取任务当前的 postponeCount
    final allDbTasks = await database.getAllTasks();
    final taskMap = {for (var t in allDbTasks) t.id: t};

    for (final taskId in taskIds) {
      final dbTask = taskMap[taskId];
      if (dbTask == null) continue;

      await database.updateTask(
        db.TasksCompanion(
          id: drift.Value(taskId),
          dueDate: drift.Value(today),
          // 手动顺延也要增加顺延次数
          postponeCount: drift.Value(dbTask.postponeCount + 1),
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
/// 包含：
/// - todayTasks: 截止日期为今天的任务（包括已完成和未完成）
/// - overdueTasks: 已过期但未完成的任务
final todayViewTasksProvider = Provider<TodayViewTasks>((ref) {
  final tasks = ref.watch(taskProvider);

  final todayTasks = <Task>[];
  final overdueTasks = <Task>[];

  for (final task in tasks) {
    if (task.isDeleted) continue;
    if (task.dueDate == null) continue;

    if (AmberDateUtils.isToday(task.dueDate!)) {
      // 今天的任务（包括已完成和未完成）
      todayTasks.add(task);
    } else if (!task.isCompleted && AmberDateUtils.isOverdue(task.dueDate!)) {
      // 过期任务只显示未完成的
      overdueTasks.add(task);
    }
  }

  // 今天的任务按优先级和创建时间排序（未完成在前）
  todayTasks.sort((a, b) {
    // 未完成任务排在前面
    if (a.isCompleted != b.isCompleted) {
      return a.isCompleted ? 1 : -1;
    }
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
