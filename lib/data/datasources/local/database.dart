import 'dart:convert'; // Added for JSON
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart'; // Added for UUID
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
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON数组
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get parentId => text().nullable()();
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
  int get schemaVersion => 5; // Bump version for Pomodoro tables


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
      },
    );
  }

  /// 种子数据初始化
  Future<void> _seedDatabase() async {
    const uuid = Uuid();
    final now = DateTime.now();

        // 1. 插入默认清单
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
        
        // 2. 插入 Mock 任务 (不变)
        await batch((batch) {
          // ... tasks ...
          batch.insertAll(tasks, [
            TasksCompanion.insert(
              id: uuid.v4(),
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
              id: uuid.v4(),
              title: '实现侧边栏导航',
              listId: const Value('work'),
              dueDate: Value(now),
              priority: const Value(2), // Medium
              createdAt: now.subtract(const Duration(days: 1)),
              updatedAt: now,
            ),
            TasksCompanion.insert(
              id: uuid.v4(),
              title: '购买咖啡豆',
              listId: const Value('shopping'),
              dueDate: Value(now.add(const Duration(days: 1))),
              priority: const Value(1), // Low
              createdAt: now,
              updatedAt: now,
            ),
            TasksCompanion.insert(
              id: uuid.v4(),
              title: '阅读《深入理解Flutter》',
              listId: const Value('personal'),
              dueDate: Value(now.add(const Duration(days: 3))),
              priority: const Value(0), // None
              tags: Value(jsonEncode(['阅读'])),
              createdAt: now,
              updatedAt: now,
            ),
            TasksCompanion.insert(
              id: uuid.v4(),
              title: '已完成的任务示例',
              listId: const Value('work'),
              isCompleted: const Value(true),
              completedAt: Value(now.subtract(const Duration(hours: 2))),
              createdAt: now.subtract(const Duration(days: 3)),
              updatedAt: now,
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

  Future<int> deleteTask(String id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  // ===== 笔记操作 =====
  Future<List<Note>> getAllNotes() => select(notes).get();

  Stream<List<Note>> watchAllNotes() => select(notes).watch();

  Future<int> insertNote(NotesCompanion entry) => into(notes).insert(entry);

  Future<bool> updateNote(NotesCompanion entry) =>
      (update(notes)..where((t) => t.id.equals(entry.id.value)))
          .write(entry)
          .then((rows) => rows > 0);

  Future<int> deleteNote(String id) =>
      (delete(notes)..where((t) => t.id.equals(id))).go();

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
  /// 获取数据库文件路径
  static Future<String> getDatabasePath() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return p.join(dbFolder.path, 'amber_list.db');
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
      logStatements: true,
      setup: (database) {
        database.execute('PRAGMA journal_mode = WAL');
        database.execute('PRAGMA busy_timeout = 5000');
        database.execute('PRAGMA foreign_keys = ON');
      },
    );
  });
}
