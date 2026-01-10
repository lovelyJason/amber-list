import 'dart:convert'; // Added for JSON
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../core/constants/colors.dart'; // Added for Colors

part 'database.g.dart';

/// 清单表
class TaskLists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(const Constant('list'))();
  IntColumn get color => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  // Phase 2: Hierarchical Lists
  TextColumn get parentId => text().nullable()(); // 父文件夹ID
  BoolColumn get isFolder =>
      boolean().withDefault(const Constant(false))(); // 是否为文件夹
  TextColumn get tags =>
      text().withDefault(const Constant('[]'))(); // 列表标签 JSON

  
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 任务表
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get listId => text().nullable().references(TaskLists, #id)();
  DateTimeColumn get dueDate => dateTime().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isInProgress => boolean().withDefault(const Constant(false))(); // 进行中（半完成）状态
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON数组
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get parentId => text().nullable()();
  /// 是否自动顺延过期任务到今天
  /// - 新任务默认为 true（自动顺延）
  /// - 旧数据迁移后为 false（不自动顺延，显示在已过期区域）
  BoolColumn get autoPostpone => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 笔记表
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get folderId => text().nullable()();
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON数组
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))(); // 排序顺序
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 标签表
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get color => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 番茄时钟会话表
class PomodoroSessions extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().nullable().references(Tasks, #id)();
  IntColumn get type => integer()(); // 0=focus, 1=shortBreak, 2=longBreak
  IntColumn get duration => integer()(); // 实际时长(秒)
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 番茄时钟任务队列表
class PomodoroQueue extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().references(Tasks, #id)();
  IntColumn get estimatedPomodoros => integer().withDefault(const Constant(1))();
  IntColumn get completedPomodoros => integer().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [TaskLists, Tasks, Notes, Tags, PomodoroSessions, PomodoroQueue])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 9; // Bump version for tasks autoPostpone column


  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _seedDatabase();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(taskLists, taskLists.parentId);
          await m.addColumn(taskLists, taskLists.isFolder);
        }
        if (from < 3) {
          await m.addColumn(tasks, tasks.isDeleted);
        }
        if (from < 4) {
          await m.addColumn(taskLists, taskLists.tags);
        }
        if (from < 5) {
          await m.createTable(pomodoroSessions);
          await m.createTable(pomodoroQueue);
        }
        if (from < 6) {
          // 安全迁移：先检查列是否已存在，避免重复添加报错
          final columns = await customSelect(
            "PRAGMA table_info(tasks)",
          ).get();
          final hasIsInProgress = columns.any(
            (row) => row.read<String>('name') == 'is_in_progress',
          );
          if (!hasIsInProgress) {
            await m.addColumn(tasks, tasks.isInProgress);
          }
        }
        if (from < 7) {
          // 为老用户补种笔记数据（如果笔记表为空）
          await _seedNotesIfEmpty();
        }
        if (from < 8) {
          // 安全迁移：先检查列是否已存在，避免重复添加报错
          final columns = await customSelect(
            "PRAGMA table_info(notes)",
          ).get();
          final hasSortOrder = columns.any(
            (row) => row.read<String>('name') == 'sort_order',
          );
          if (!hasSortOrder) {
            await m.addColumn(notes, notes.sortOrder);
          }
        }
        if (from < 9) {
          // 添加 auto_postpone 列
          // 安全迁移：先检查列是否已存在，避免重复添加报错
          final columns = await customSelect(
            "PRAGMA table_info(tasks)",
          ).get();
          final hasAutoPostpone = columns.any(
            (row) => row.read<String>('name') == 'auto_postpone',
          );
          if (!hasAutoPostpone) {
            // 注意：新增列时，旧数据默认为 false（不自动顺延）
            // 这样旧任务不会被自动顺延，而是显示在"已过期"区域
            await customStatement(
              'ALTER TABLE tasks ADD COLUMN auto_postpone INTEGER NOT NULL DEFAULT 0',
            );
          }
        }
      },
    );
  }

  /// 为老用户补种笔记数据（仅当笔记表为空时）
  Future<void> _seedNotesIfEmpty() async {
    final existingNotes = await select(notes).get();
    if (existingNotes.isNotEmpty) return; // 已有笔记，不补种

    final now = DateTime.now();
    await batch((batch) {
      batch.insertAll(notes, [
        NotesCompanion.insert(
          id: 'seed-note-roadmap-001',
          title: '产品路线图 2024',
          content: const Value('## Q1 目标\n- 完成核心功能开发\n- 用户测试\n\n## Q2 目标\n- 上线公测版本'),
          tags: Value(jsonEncode(['工作'])),
          createdAt: now.subtract(const Duration(days: 5)),
          updatedAt: now.subtract(const Duration(hours: 2)),
        ),
        NotesCompanion.insert(
          id: 'seed-note-design-002',
          title: '设计灵感',
          content: const Value('- 简约排版\n- 琥珀色调\n- 圆角设计\n- 柔和阴影'),
          tags: Value(jsonEncode(['灵感'])),
          isPinned: const Value(true),
          createdAt: now.subtract(const Duration(days: 3)),
          updatedAt: now.subtract(const Duration(days: 1)),
        ),
        NotesCompanion.insert(
          id: 'seed-note-shopping-003',
          title: '购物清单',
          content: const Value('- 牛奶\n- 面包\n- 鸡蛋\n- 咖啡豆'),
          tags: Value(jsonEncode(['生活'])),
          createdAt: now.subtract(const Duration(days: 1)),
          updatedAt: now.subtract(const Duration(days: 1)),
        ),
        NotesCompanion.insert(
          id: 'seed-note-flutter-004',
          title: '读书笔记：深入理解Flutter',
          content: const Value('## 第一章\nFlutter是Google开发的跨平台框架...\n\n## 关键概念\n- Widget\n- State\n- BuildContext'),
          tags: Value(jsonEncode(['阅读', '技术'])),
          createdAt: now.subtract(const Duration(days: 10)),
          updatedAt: now.subtract(const Duration(days: 2)),
        ),
        NotesCompanion.insert(
          id: 'seed-note-meeting-005',
          title: '会议记录',
          content: const Value('参会人员：\n- 张三\n- 李四\n\n讨论内容：\n1. 项目进度\n2. 下周计划'),
          tags: Value(jsonEncode(['工作', '会议'])),
          createdAt: now.subtract(const Duration(hours: 5)),
          updatedAt: now.subtract(const Duration(hours: 5)),
        ),
      ]);
    });
  }

  /// 种子数据初始化
  /// 注意：所有种子数据的 ID 都使用固定值，避免多设备同步时产生重复数据
  Future<void> _seedDatabase() async {
    final now = DateTime.now();

        // 1. 插入默认清单（固定ID）
        await batch((batch) {
          batch.insertAll(taskLists, [
            TaskListsCompanion.insert(
              id: 'work',
              name: '工作',
              icon: const Value('work'),
              color: AmberColors.primary.value,
              sortOrder: const Value(0),
              createdAt: now,
              updatedAt: now,
              isFolder: const Value(false),
            ),
            TaskListsCompanion.insert(
              id: 'personal',
              name: '生活',
              icon: const Value('person'),
              color: AmberColors.info.value,
              sortOrder: const Value(1),
              createdAt: now,
              updatedAt: now,
              isFolder: const Value(false),
            ),
            TaskListsCompanion.insert(
              id: 'shopping',
              name: '购物',
              icon: const Value('shopping_cart'),
              color: AmberColors.success.value,
              sortOrder: const Value(2),
              createdAt: now,
              updatedAt: now,
              isFolder: const Value(false),
            ),
          ]);
        });
        
        // 2. 插入默认标签（固定ID，避免多设备同步重复）
        // 注意：这些标签在种子任务中被引用，必须先插入
        await batch((batch) {
          batch.insertAll(tags, [
            TagsCompanion.insert(
              id: 'seed-tag-design',
              name: '设计',
              color: 0xFF2196F3, // 蓝色
              createdAt: now,
            ),
            TagsCompanion.insert(
              id: 'seed-tag-important',
              name: '重要',
              color: 0xFFF44336, // 红色
              createdAt: now,
            ),
            TagsCompanion.insert(
              id: 'seed-tag-reading',
              name: '阅读',
              color: 0xFF4CAF50, // 绿色
              createdAt: now,
            ),
          ]);
        });

        // 3. 插入 Mock 任务（固定ID，避免多设备同步重复）
        await batch((batch) {
          batch.insertAll(tasks, [
            TasksCompanion.insert(
              id: 'seed-task-amber-ui-design-001',
              title: '完成琥珀清单UI设计',
              description: const Value('包括配色方案、布局设计、交互逻辑等'),
              listId: const Value('work'),
              dueDate: Value(now),
              priority: const Value(3), // High
              tags: Value(jsonEncode(['设计', '重要'])),
              createdAt: now.subtract(const Duration(days: 2)),
              updatedAt: now,
            ),
            TasksCompanion.insert(
              id: 'seed-task-sidebar-nav-002',
              title: '实现侧边栏导航',
              listId: const Value('work'),
              dueDate: Value(now),
              priority: const Value(2), // Medium
              createdAt: now.subtract(const Duration(days: 1)),
              updatedAt: now,
            ),
            TasksCompanion.insert(
              id: 'seed-task-buy-coffee-003',
              title: '购买咖啡豆',
              listId: const Value('shopping'),
              dueDate: Value(now.add(const Duration(days: 1))),
              priority: const Value(1), // Low
              createdAt: now,
              updatedAt: now,
            ),
            TasksCompanion.insert(
              id: 'seed-task-read-flutter-004',
              title: '阅读《深入理解Flutter》',
              listId: const Value('personal'),
              dueDate: Value(now.add(const Duration(days: 3))),
              priority: const Value(0), // None
              tags: Value(jsonEncode(['阅读'])),
              createdAt: now,
              updatedAt: now,
            ),
            TasksCompanion.insert(
              id: 'seed-task-completed-demo-005',
              title: '已完成的任务示例',
              listId: const Value('work'),
              isCompleted: const Value(true),
              completedAt: Value(now.subtract(const Duration(hours: 2))),
              createdAt: now.subtract(const Duration(days: 3)),
              updatedAt: now,
            ),
          ]);
    });

    // 4. 插入默认笔记（固定ID，避免多设备同步重复）
    await batch((batch) {
      batch.insertAll(notes, [
        NotesCompanion.insert(
          id: 'seed-note-roadmap-001',
          title: '产品路线图 2024',
          content: const Value('## Q1 目标\n- 完成核心功能开发\n- 用户测试\n\n## Q2 目标\n- 上线公测版本'),
          tags: Value(jsonEncode(['工作'])),
          createdAt: now.subtract(const Duration(days: 5)),
          updatedAt: now.subtract(const Duration(hours: 2)),
        ),
        NotesCompanion.insert(
          id: 'seed-note-design-002',
          title: '设计灵感',
          content: const Value('- 简约排版\n- 琥珀色调\n- 圆角设计\n- 柔和阴影'),
          tags: Value(jsonEncode(['灵感'])),
          isPinned: const Value(true),
          createdAt: now.subtract(const Duration(days: 3)),
          updatedAt: now.subtract(const Duration(days: 1)),
        ),
        NotesCompanion.insert(
          id: 'seed-note-shopping-003',
          title: '购物清单',
          content: const Value('- 牛奶\n- 面包\n- 鸡蛋\n- 咖啡豆'),
          tags: Value(jsonEncode(['生活'])),
          createdAt: now.subtract(const Duration(days: 1)),
          updatedAt: now.subtract(const Duration(days: 1)),
        ),
        NotesCompanion.insert(
          id: 'seed-note-flutter-004',
          title: '读书笔记：深入理解Flutter',
          content: const Value('## 第一章\nFlutter是Google开发的跨平台框架...\n\n## 关键概念\n- Widget\n- State\n- BuildContext'),
          tags: Value(jsonEncode(['阅读', '技术'])),
          createdAt: now.subtract(const Duration(days: 10)),
          updatedAt: now.subtract(const Duration(days: 2)),
        ),
        NotesCompanion.insert(
          id: 'seed-note-meeting-005',
          title: '会议记录',
          content: const Value('参会人员：\n- 张三\n- 李四\n\n讨论内容：\n1. 项目进度\n2. 下周计划'),
          tags: Value(jsonEncode(['工作', '会议'])),
          createdAt: now.subtract(const Duration(hours: 5)),
          updatedAt: now.subtract(const Duration(hours: 5)),
        ),
      ]);
    });
  }

  /// 清空所有数据
  Future<void> clearDatabase() async {
    // 按依赖顺序删除，避免外键约束错误
    await delete(pomodoroQueue).go();
    await delete(pomodoroSessions).go();
    await delete(tasks).go();
    await delete(taskLists).go();
    await delete(notes).go();
    await delete(tags).go();
  }

  /// 重置数据库（清空并重新播种）
  Future<void> resetDatabase() async {
    await clearDatabase();
    await _seedDatabase();
  }

  // ===== 清单操作 =====
  Future<List<TaskList>> getAllTaskLists() => select(taskLists).get();

  Stream<List<TaskList>> watchAllTaskLists() => select(taskLists).watch();

  Future<int> insertTaskList(TaskListsCompanion entry) =>
      into(taskLists).insert(entry);

  Future<bool> updateTaskList(TaskListsCompanion entry) =>
      (update(taskLists)..where((t) => t.id.equals(entry.id.value)))
          .write(entry)
          .then((rows) => rows > 0);

  Future<int> deleteTaskList(String id) =>
      (delete(taskLists)..where((t) => t.id.equals(id))).go();

  /// 获取清单关联数据统计（用于删除前提示）
  /// 返回 {taskCount: 正常任务数, trashCount: 垃圾桶任务数, pomodoroCount: 番茄记录数}
  Future<Map<String, int>> getTaskListStats(String listId) async {
    // 获取该清单下的所有任务
    final listTasks = await (select(tasks)..where((t) => t.listId.equals(listId))).get();

    // 区分正常任务和垃圾桶任务
    final normalTasks = listTasks.where((t) => !t.isDeleted).toList();
    final trashTasks = listTasks.where((t) => t.isDeleted).toList();

    // 统计番茄记录数
    int pomodoroCount = 0;
    for (final task in listTasks) {
      final queueCount = await (selectOnly(pomodoroQueue)
            ..addColumns([pomodoroQueue.id.count()])
            ..where(pomodoroQueue.taskId.equals(task.id)))
          .map((row) => row.read(pomodoroQueue.id.count()) ?? 0)
          .getSingle();
      final sessionCount = await (selectOnly(pomodoroSessions)
            ..addColumns([pomodoroSessions.id.count()])
            ..where(pomodoroSessions.taskId.equals(task.id)))
          .map((row) => row.read(pomodoroSessions.id.count()) ?? 0)
          .getSingle();
      pomodoroCount += queueCount + sessionCount;
    }

    return {
      'taskCount': normalTasks.length,
      'trashCount': trashTasks.length,
      'pomodoroCount': pomodoroCount,
    };
  }

  /// 删除清单及其所有关联任务
  /// 先删除所有属于该清单的任务，再删除清单本身，避免外键约束错误
  Future<void> deleteTaskListWithTasks(String listId) async {
    // 1. 先删除该清单下所有任务关联的番茄记录
    final listTasks = await (select(tasks)..where((t) => t.listId.equals(listId))).get();
    for (final task in listTasks) {
      await (delete(pomodoroQueue)..where((q) => q.taskId.equals(task.id))).go();
      await (delete(pomodoroSessions)..where((s) => s.taskId.equals(task.id))).go();
    }

    // 2. 删除该清单下的所有任务
    await (delete(tasks)..where((t) => t.listId.equals(listId))).go();

    // 3. 最后删除清单本身
    await (delete(taskLists)..where((t) => t.id.equals(listId))).go();
  }

  // ===== 任务操作 =====
  Future<List<Task>> getAllTasks() => select(tasks).get();

  Stream<List<Task>> watchAllTasks() => select(tasks).watch();

  Stream<List<Task>> watchTasksByList(String listId) =>
      (select(tasks)..where((t) => t.listId.equals(listId))).watch();

  Stream<List<Task>> watchTodayTasks() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    return (select(tasks)
          ..where((t) => t.dueDate.isBetweenValues(todayStart, todayEnd)))
        .watch();
  }

  Future<int> insertTask(TasksCompanion entry) => into(tasks).insert(entry);

  Future<bool> updateTask(TasksCompanion entry) =>
      (update(tasks)..where((t) => t.id.equals(entry.id.value)))
          .write(entry)
          .then((rows) => rows > 0);

  /// 删除任务
  /// 注意：如果任务有关联的番茄记录，会抛出外键约束异常
  /// 调用方应先检查 hasTaskPomodoroRecords() 并提示用户
  Future<int> deleteTask(String id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  /// 检查任务是否有关联的番茄记录
  Future<bool> hasTaskPomodoroRecords(String taskId) async {
    // 检查番茄队列
    final queueCount = await (selectOnly(pomodoroQueue)
          ..addColumns([pomodoroQueue.id.count()])
          ..where(pomodoroQueue.taskId.equals(taskId)))
        .map((row) => row.read(pomodoroQueue.id.count()))
        .getSingle();
    if (queueCount != null && queueCount > 0) return true;

    // 检查番茄会话
    final sessionCount = await (selectOnly(pomodoroSessions)
          ..addColumns([pomodoroSessions.id.count()])
          ..where(pomodoroSessions.taskId.equals(taskId)))
        .map((row) => row.read(pomodoroSessions.id.count()))
        .getSingle();
    return sessionCount != null && sessionCount > 0;
  }

  /// 强制删除任务及其所有番茄记录
  /// 仅在用户确认后调用
  Future<int> forceDeleteTaskWithPomodoros(String id) async {
    // 先删除关联的番茄时钟队列项
    await (delete(pomodoroQueue)..where((q) => q.taskId.equals(id))).go();
    // 再删除关联的番茄时钟会话记录
    await (delete(pomodoroSessions)..where((s) => s.taskId.equals(id))).go();
    // 最后删除任务本身
    return (delete(tasks)..where((t) => t.id.equals(id))).go();
  }

  // ===== 笔记操作 =====
  Future<List<Note>> getAllNotes() => select(notes).get();

  /// 监听所有笔记（按创建时间倒序排列，最新的在前）
  Stream<List<Note>> watchAllNotes() =>
      (select(notes)..orderBy([(n) => OrderingTerm.desc(n.createdAt)])).watch();

  Future<int> insertNote(NotesCompanion entry) => into(notes).insert(entry);

  Future<bool> updateNote(NotesCompanion entry) =>
      (update(notes)..where((t) => t.id.equals(entry.id.value)))
          .write(entry)
          .then((rows) => rows > 0);

  Future<int> deleteNote(String id) =>
      (delete(notes)..where((t) => t.id.equals(id))).go();

  /// 批量更新笔记排序顺序
  /// [noteIds] 按新顺序排列的笔记ID列表
  Future<void> updateNotesOrder(List<String> noteIds) async {
    await transaction(() async {
      for (int i = 0; i < noteIds.length; i++) {
        await (update(notes)..where((n) => n.id.equals(noteIds[i])))
            .write(NotesCompanion(sortOrder: Value(i)));
      }
    });
  }

  // ===== 标签操作 =====
  Future<List<Tag>> getAllTags() => select(tags).get();

  Stream<List<Tag>> watchAllTags() => select(tags).watch();

  Future<int> insertTag(TagsCompanion entry) => into(tags).insert(entry);

  Future<int> deleteTag(String id) =>
      (delete(tags)..where((t) => t.id.equals(id))).go();

  // ===== 番茄时钟会话操作 =====
  Future<int> insertPomodoroSession(PomodoroSessionsCompanion entry) =>
      into(pomodoroSessions).insert(entry);

  Future<bool> updatePomodoroSession(PomodoroSessionsCompanion entry) =>
      (update(pomodoroSessions)..where((s) => s.id.equals(entry.id.value)))
          .write(entry)
          .then((rows) => rows > 0);

  Stream<List<PomodoroSession>> watchPomodoroSessions() =>
      select(pomodoroSessions).watch();

  Stream<List<PomodoroSession>> watchTodayPomodoroSessions() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    return (select(pomodoroSessions)
          ..where((s) => s.startedAt.isBiggerOrEqualValue(todayStart))
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
        .watch();
  }

  // ===== 番茄时钟队列操作 =====
  Future<int> insertPomodoroQueueItem(PomodoroQueueCompanion entry) =>
      into(pomodoroQueue).insert(entry);

  Future<bool> updatePomodoroQueueItem(PomodoroQueueCompanion entry) =>
      (update(pomodoroQueue)..where((q) => q.id.equals(entry.id.value)))
          .write(entry)
          .then((rows) => rows > 0);

  Future<int> deletePomodoroQueueItem(String id) =>
      (delete(pomodoroQueue)..where((q) => q.id.equals(id))).go();

  Stream<List<PomodoroQueueData>> watchPomodoroQueue() =>
      (select(pomodoroQueue)..orderBy([(q) => OrderingTerm.asc(q.sortOrder)]))
          .watch();

  Future<void> clearPomodoroQueue() => delete(pomodoroQueue).go();

  // ===== 导入导出 =====

  /// iOS App Group ID（与 Widget Extension 共享数据）
  /// 必须与 Xcode 中配置的 App Group 完全一致
  static const String _iOSAppGroupId = 'group.com.amberlist.amberList';

  /// 获取数据库文件路径
  ///
  /// iOS: 必须使用 App Group 共享目录，Widget Extension 直接访问同一个数据库
  /// 其他平台: 使用默认的 Documents 目录
  static Future<String> getDatabasePath() async {
    if (Platform.isIOS) {
      // iOS 必须使用 App Group 共享目录，不 fallback 到 Documents
      final appGroupDir = await _getAppGroupDirectory();
      if (appGroupDir != null) {
        final dbPath = p.join(appGroupDir, 'amber_list.db');
        debugPrint('[Database] iOS using App Group path: $dbPath');
        return dbPath;
      }
      // 获取失败则抛异常，避免数据写到 Documents 导致 Widget 读不到
      throw Exception('[Database] iOS App Group directory not available');
    }
    // 其他平台使用默认目录
    final dbFolder = await getApplicationDocumentsDirectory();
    return p.join(dbFolder.path, 'amber_list.db');
  }

  /// 缓存 App Group 目录路径
  /// 避免每次都调用 MethodChannel
  static String? _cachedAppGroupPath;

  /// 获取 iOS App Group 共享目录
  /// 返回 null 表示获取失败（非 iOS 平台或配置错误）
  static Future<String?> _getAppGroupDirectory() async {
    if (!Platform.isIOS) return null;

    // 使用缓存
    if (_cachedAppGroupPath != null) {
      return _cachedAppGroupPath;
    }

    try {
      // 使用 MethodChannel 获取 App Group 路径
      const channel = MethodChannel('com.amberlist.database');
      final String? path = await channel.invokeMethod<String>('getAppGroupPath', {
        'groupId': _iOSAppGroupId,
      });
      if (path != null) {
        _cachedAppGroupPath = path;
        debugPrint('[Database] App Group path: $path');
      }
      return path;
    } catch (e) {
      debugPrint('[Database] Failed to get App Group directory: $e');
      // MethodChannel 失败时，尝试直接构造路径
      // iOS App Group 路径可以通过 HOME 环境变量推算
      // 但更可靠的方式是在 main() 中预先初始化
      return null;
    }
  }

  /// 预初始化 App Group 路径
  /// 在 main() 中 WidgetsFlutterBinding 初始化后调用
  /// 确保数据库连接前 MethodChannel 已可用
  static Future<void> initAppGroupPath() async {
    if (!Platform.isIOS) return;

    try {
      const channel = MethodChannel('com.amberlist.database');
      final String? path = await channel.invokeMethod<String>('getAppGroupPath', {
        'groupId': _iOSAppGroupId,
      });
      if (path != null) {
        _cachedAppGroupPath = path;
        debugPrint('[Database] App Group path initialized: $path');
      } else {
        debugPrint('[Database] Warning: App Group path is null');
      }
    } catch (e) {
      debugPrint('[Database] Failed to initialize App Group path: $e');
    }
  }

  /// 迁移旧数据库到 App Group 目录（仅 iOS）
  /// 首次升级时调用，将 Documents 目录的数据库迁移到 App Group
  static Future<bool> migrateToAppGroup() async {
    if (!Platform.isIOS) return false;

    final appGroupDir = await _getAppGroupDirectory();
    if (appGroupDir == null) {
      debugPrint('[Database] App Group directory not available, skip migration');
      return false;
    }

    // 检查新路径是否已有数据库（已迁移过）
    final newDbPath = p.join(appGroupDir, 'amber_list.db');
    final newDbFile = File(newDbPath);
    if (await newDbFile.exists()) {
      debugPrint('[Database] Database already in App Group, skip migration');
      return true;
    }

    // 检查旧路径是否有数据库
    final oldDbFolder = await getApplicationDocumentsDirectory();
    final oldDbPath = p.join(oldDbFolder.path, 'amber_list.db');
    final oldDbFile = File(oldDbPath);
    if (!await oldDbFile.exists()) {
      debugPrint('[Database] No old database to migrate');
      return true;
    }

    try {
      // 确保目标目录存在
      final targetDir = Directory(appGroupDir);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // 复制数据库文件
      await oldDbFile.copy(newDbPath);

      // 复制 WAL 和 SHM 文件（如果存在）
      final walFile = File('$oldDbPath-wal');
      final shmFile = File('$oldDbPath-shm');
      if (await walFile.exists()) {
        await walFile.copy('$newDbPath-wal');
      }
      if (await shmFile.exists()) {
        await shmFile.copy('$newDbPath-shm');
      }

      debugPrint('[Database] Migration to App Group completed');

      // 删除旧文件（可选，暂时保留作为备份）
      // await oldDbFile.delete();

      return true;
    } catch (e) {
      debugPrint('[Database] Migration failed: $e');
      return false;
    }
  }

  /// 导出数据库
  Future<File> exportDatabase(String exportPath) async {
    final dbPath = await getDatabasePath();
    final dbFile = File(dbPath);
    return dbFile.copy(exportPath);
  }

  /// 导入数据库
  static Future<void> importDatabase(String importPath) async {
    final dbPath = await getDatabasePath();
    final importFile = File(importPath);
    await importFile.copy(dbPath);
  }

  /// 强制合并 WAL 文件到主数据库
  /// 用于同步前确保 .db 文件包含最新数据
  Future<void> checkpoint() async {
    await customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbPath = await AppDatabase.getDatabasePath();
    final file = File(dbPath);
    return NativeDatabase(
      file,
      logStatements: false,
      setup: (database) {
        database.execute('PRAGMA journal_mode = WAL');
        database.execute('PRAGMA busy_timeout = 5000');
        database.execute('PRAGMA foreign_keys = ON');
      },
    );
  });
}
