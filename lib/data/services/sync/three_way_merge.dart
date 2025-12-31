import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

/// ============================================================
/// 三向合并引擎 (Three-Way Merge Engine)
/// ============================================================
/// 基于 DB 文件的三向合并，处理本地与远程数据的冲突：
///
/// 核心概念：
/// - Base（基准版本）：上次成功同步后保存的 DB 快照
/// - Local（本地版本）：当前本地的数据库
/// - Remote（远程版本）：从 WebDAV 下载的数据库
///
/// 合并规则（逐记录比较）：
/// 1. 只有本地有 → 本地新增，保留
/// 2. 只有远程有 → 远程新增，插入本地
/// 3. 本地没改、远程改了 → 用远程
/// 4. 本地改了、远程没改 → 保持本地
/// 5. 两边都改了 → 智能合并（用 updatedAt 更新的）
///
/// 使用原始 SQLite 操作，避免 Drift 的复杂性
/// ============================================================

/// 合并统计
class MergeStats {
  int tasksAdded = 0;
  int tasksUpdated = 0;
  int tasksDeleted = 0;
  int taskListsAdded = 0;
  int taskListsUpdated = 0;
  int taskListsDeleted = 0;
  int notesAdded = 0;
  int notesUpdated = 0;
  int notesDeleted = 0;
  int tagsAdded = 0;
  int tagsDeleted = 0;
  int conflicts = 0;
  List<TagConflict> tagConflicts = [];

  /// 是否有任何变化
  bool get hasChanges =>
      tasksAdded > 0 ||
      tasksUpdated > 0 ||
      tasksDeleted > 0 ||
      taskListsAdded > 0 ||
      taskListsUpdated > 0 ||
      taskListsDeleted > 0 ||
      notesAdded > 0 ||
      notesUpdated > 0 ||
      notesDeleted > 0 ||
      tagsAdded > 0 ||
      tagsDeleted > 0;

  @override
  String toString() {
    final parts = <String>[];
    if (tasksAdded > 0) parts.add('任务+$tasksAdded');
    if (tasksUpdated > 0) parts.add('任务↑$tasksUpdated');
    if (tasksDeleted > 0) parts.add('任务-$tasksDeleted');
    if (taskListsAdded > 0) parts.add('清单+$taskListsAdded');
    if (taskListsUpdated > 0) parts.add('清单↑$taskListsUpdated');
    if (taskListsDeleted > 0) parts.add('清单-$taskListsDeleted');
    if (notesAdded > 0) parts.add('笔记+$notesAdded');
    if (notesUpdated > 0) parts.add('笔记↑$notesUpdated');
    if (notesDeleted > 0) parts.add('笔记-$notesDeleted');
    if (conflicts > 0) parts.add('冲突$conflicts');

    return parts.isEmpty ? '无变化' : parts.join(', ');
  }
}

/// 合并结果
class MergeResult {
  final bool success;
  final MergeStats stats;
  final String? error;

  const MergeResult({
    required this.success,
    required this.stats,
    this.error,
  });

  factory MergeResult.successful(MergeStats stats) {
    return MergeResult(success: true, stats: stats);
  }

  factory MergeResult.failed(String error) {
    return MergeResult(success: false, stats: MergeStats(), error: error);
  }
}

/// 三向合并引擎
class ThreeWayMergeEngine {
  /// 执行三向合并
  /// [localDbPath] 本地数据库路径
  /// [remoteDbPath] 远程数据库路径（下载的临时文件）
  /// [baseDbPath] 基准数据库路径（上次同步快照），可为 null（首次同步）
  ///
  /// 合并结果会写入本地数据库
  Future<MergeResult> merge({
    required String localDbPath,
    required String remoteDbPath,
    String? baseDbPath,
  }) async {
    final stats = MergeStats();

    // 检查文件是否存在
    if (!File(localDbPath).existsSync()) {
      return MergeResult.failed('本地数据库不存在');
    }
    if (!File(remoteDbPath).existsSync()) {
      return MergeResult.failed('远程数据库不存在');
    }

    Database? localDb;
    Database? remoteDb;
    Database? baseDb;

    try {
      // 打开三个数据库
      localDb = sqlite3.open(localDbPath);
      remoteDb = sqlite3.open(remoteDbPath);

      if (baseDbPath != null && File(baseDbPath).existsSync()) {
        baseDb = sqlite3.open(baseDbPath);
      }

      // 合并各表
      _mergeTaskLists(localDb, remoteDb, baseDb, stats);
      _mergeTasks(localDb, remoteDb, baseDb, stats);
      _mergeNotes(localDb, remoteDb, baseDb, stats);
      _mergeTags(localDb, remoteDb, baseDb, stats);

      return MergeResult.successful(stats);
    } catch (e, stack) {
      debugPrint('[ThreeWayMerge] 合并失败: $e\n$stack');
      return MergeResult.failed('合并失败: $e');
    } finally {
      // 关闭数据库连接
      localDb?.dispose();
      remoteDb?.dispose();
      baseDb?.dispose();
    }
  }

  // ============================================================
  // 清单合并
  // ============================================================

  void _mergeTaskLists(
    Database localDb,
    Database remoteDb,
    Database? baseDb,
    MergeStats stats,
  ) {
    final localRows = localDb.select('SELECT * FROM task_lists');
    final remoteRows = remoteDb.select('SELECT * FROM task_lists');
    final baseRows = baseDb?.select('SELECT * FROM task_lists') ?? [];

    final localMap = {for (final r in localRows) r['id'] as String: r};
    final remoteMap = {for (final r in remoteRows) r['id'] as String: r};
    final baseMap = {for (final r in baseRows) r['id'] as String: r};

    final allIds = {...localMap.keys, ...remoteMap.keys, ...baseMap.keys};

    for (final id in allIds) {
      final local = localMap[id];
      final remote = remoteMap[id];
      final base = baseMap[id];

      final action = _determineAction(
        local: local,
        remote: remote,
        base: base,
        getUpdatedAt: (r) => r['updated_at'] as int,
        equals: (a, b) => _rowEquals(a, b, ['id', 'created_at', 'updated_at']),
      );

      switch (action) {
        case _MergeAction.addFromRemote:
          _insertRow(localDb, 'task_lists', remote!);
          stats.taskListsAdded++;
          break;
        case _MergeAction.updateFromRemote:
          _updateRow(localDb, 'task_lists', id, remote!);
          stats.taskListsUpdated++;
          break;
        case _MergeAction.deleteLocal:
          localDb.execute('DELETE FROM task_lists WHERE id = ?', [id]);
          stats.taskListsDeleted++;
          break;
        case _MergeAction.conflict:
          final localTime = local!['updated_at'] as int;
          final remoteTime = remote!['updated_at'] as int;
          if (remoteTime > localTime) {
            _updateRow(localDb, 'task_lists', id, remote);
            stats.taskListsUpdated++;
          }
          stats.conflicts++;
          break;
        case _MergeAction.keepLocal:
          break;
      }
    }
  }

  // ============================================================
  // 任务合并
  // ============================================================

  void _mergeTasks(
    Database localDb,
    Database remoteDb,
    Database? baseDb,
    MergeStats stats,
  ) {
    final localRows = localDb.select('SELECT * FROM tasks');
    final remoteRows = remoteDb.select('SELECT * FROM tasks');
    final baseRows = baseDb?.select('SELECT * FROM tasks') ?? [];

    final localMap = {for (final r in localRows) r['id'] as String: r};
    final remoteMap = {for (final r in remoteRows) r['id'] as String: r};
    final baseMap = {for (final r in baseRows) r['id'] as String: r};

    final allIds = {...localMap.keys, ...remoteMap.keys, ...baseMap.keys};

    for (final id in allIds) {
      final local = localMap[id];
      final remote = remoteMap[id];
      final base = baseMap[id];

      final action = _determineAction(
        local: local,
        remote: remote,
        base: base,
        getUpdatedAt: (r) => r['updated_at'] as int,
        equals: (a, b) => _rowEquals(a, b, ['id', 'created_at', 'updated_at']),
      );

      switch (action) {
        case _MergeAction.addFromRemote:
          _insertRow(localDb, 'tasks', remote!);
          stats.tasksAdded++;
          break;
        case _MergeAction.updateFromRemote:
          _updateRow(localDb, 'tasks', id, remote!);
          stats.tasksUpdated++;
          break;
        case _MergeAction.deleteLocal:
          localDb.execute('DELETE FROM tasks WHERE id = ?', [id]);
          stats.tasksDeleted++;
          break;
        case _MergeAction.conflict:
          // 智能合并
          final merged = _smartMergeRow(local!, remote!, base);
          _updateRowFromMap(localDb, 'tasks', id, merged);
          stats.tasksUpdated++;
          stats.conflicts++;
          break;
        case _MergeAction.keepLocal:
          break;
      }
    }
  }

  // ============================================================
  // 笔记合并
  // ============================================================

  void _mergeNotes(
    Database localDb,
    Database remoteDb,
    Database? baseDb,
    MergeStats stats,
  ) {
    final localRows = localDb.select('SELECT * FROM notes');
    final remoteRows = remoteDb.select('SELECT * FROM notes');
    final baseRows = baseDb?.select('SELECT * FROM notes') ?? [];

    final localMap = {for (final r in localRows) r['id'] as String: r};
    final remoteMap = {for (final r in remoteRows) r['id'] as String: r};
    final baseMap = {for (final r in baseRows) r['id'] as String: r};

    final allIds = {...localMap.keys, ...remoteMap.keys, ...baseMap.keys};

    for (final id in allIds) {
      final local = localMap[id];
      final remote = remoteMap[id];
      final base = baseMap[id];

      final action = _determineAction(
        local: local,
        remote: remote,
        base: base,
        getUpdatedAt: (r) => r['updated_at'] as int,
        equals: (a, b) => _rowEquals(a, b, ['id', 'created_at', 'updated_at']),
      );

      switch (action) {
        case _MergeAction.addFromRemote:
          _insertRow(localDb, 'notes', remote!);
          stats.notesAdded++;
          break;
        case _MergeAction.updateFromRemote:
          _updateRow(localDb, 'notes', id, remote!);
          stats.notesUpdated++;
          break;
        case _MergeAction.deleteLocal:
          localDb.execute('DELETE FROM notes WHERE id = ?', [id]);
          stats.notesDeleted++;
          break;
        case _MergeAction.conflict:
          final localTime = local!['updated_at'] as int;
          final remoteTime = remote!['updated_at'] as int;
          if (remoteTime > localTime) {
            _updateRow(localDb, 'notes', id, remote);
            stats.notesUpdated++;
          }
          stats.conflicts++;
          break;
        case _MergeAction.keepLocal:
          break;
      }
    }
  }

  // ============================================================
  // 标签合并
  // ============================================================

  // ============================================================
  // 标签合并
  // ============================================================

  void _mergeTags(
    Database localDb,
    Database remoteDb,
    Database? baseDb,
    MergeStats stats,
  ) {
    final localRows = localDb.select('SELECT * FROM tags');
    final remoteRows = remoteDb.select('SELECT * FROM tags');
    final baseRows = baseDb?.select('SELECT * FROM tags') ?? [];

    final localMap = {for (final r in localRows) r['id'] as String: r};
    final remoteMap = {for (final r in remoteRows) r['id'] as String: r};
    final baseMap = {for (final r in baseRows) r['id'] as String: r};

    // Index local tags by name for duplicate detection
    final localNameMap = {for (final r in localRows) r['name'] as String: r};

    final allIds = {...localMap.keys, ...remoteMap.keys, ...baseMap.keys};

    for (final id in allIds) {
      final local = localMap[id];
      final remote = remoteMap[id];
      final base = baseMap[id];

      // 标签没有 updatedAt，简化处理
      if (local == null && remote != null) {
        // 远程新增
        final remoteName = remote['name'] as String;

        // Check for duplicate name in local (with different ID)
        if (localNameMap.containsKey(remoteName)) {
          final existingLocal = localNameMap[remoteName]!;
          // Conflict Detected!
          stats.tagConflicts.add(
            TagConflict(
              local: Map<String, dynamic>.from(existingLocal),
              remote: Map<String, dynamic>.from(remote),
            ),
          );
          stats.conflicts++;
          // We do NOT insert the remote tag yet. We skip it until resolved.
        } else {
          _insertRow(localDb, 'tags', remote);
          stats.tagsAdded++;
          // Add to localNameMap to catch duplicates within the same merge batch (rare but possible)
          localNameMap[remoteName] = remote;
        }
      } else if (local != null && remote == null && base != null) {
        // 远程删除
        localDb.execute('DELETE FROM tags WHERE id = ?', [id]);
        stats.tagsDeleted++;
        localNameMap.remove(local['name']);
      }
    }
  }

  // ============================================================
  // 辅助方法
  // ============================================================

  /// 比较两行是否相等（排除某些列）
  bool _rowEquals(Row a, Row b, List<String> excludeColumns) {
    final keysA = a.keys.where((k) => !excludeColumns.contains(k)).toSet();
    final keysB = b.keys.where((k) => !excludeColumns.contains(k)).toSet();

    if (!keysA.containsAll(keysB) || !keysB.containsAll(keysA)) {
      return false;
    }

    for (final key in keysA) {
      if (a[key] != b[key]) {
        return false;
      }
    }
    return true;
  }

  /// 智能合并行（字段级别）
  Map<String, Object?> _smartMergeRow(Row local, Row remote, Row? base) {
    final result = <String, Object?>{};
    final localTime = local['updated_at'] as int;
    final remoteTime = remote['updated_at'] as int;

    for (final key in local.keys) {
      final localVal = local[key];
      final remoteVal = remote[key];
      final baseVal = base?[key];

      if (localVal == remoteVal) {
        result[key] = localVal;
      } else if (localVal == baseVal) {
        result[key] = remoteVal; // 本地没改，用远程
      } else if (remoteVal == baseVal) {
        result[key] = localVal; // 远程没改，用本地
      } else {
        // 都改了，用时间更新的
        result[key] = localTime > remoteTime ? localVal : remoteVal;
      }
    }

    // 特殊处理：完成状态（任何一边完成就算完成）
    if (local.containsKey('is_completed')) {
      final localCompleted = (local['is_completed'] as int?) == 1;
      final remoteCompleted = (remote['is_completed'] as int?) == 1;
      result['is_completed'] = (localCompleted || remoteCompleted) ? 1 : 0;
    }

    // 更新时间取最新的
    result['updated_at'] = localTime > remoteTime ? localTime : remoteTime;

    return result;
  }

  /// 插入行
  void _insertRow(Database db, String table, Row row) {
    final columns = row.keys.toList();
    final placeholders = List.filled(columns.length, '?').join(', ');
    final values = columns.map((c) => row[c]).toList();

    db.execute(
      'INSERT OR REPLACE INTO $table (${columns.join(', ')}) VALUES ($placeholders)',
      values,
    );
  }

  /// 更新行（从 Row）
  void _updateRow(Database db, String table, String id, Row row) {
    final columns = row.keys.where((k) => k != 'id').toList();
    final setClause = columns.map((c) => '$c = ?').join(', ');
    final values = [...columns.map((c) => row[c]), id];

    db.execute(
      'UPDATE $table SET $setClause WHERE id = ?',
      values,
    );
  }

  /// 更新行（从 Map）
  void _updateRowFromMap(Database db, String table, String id, Map<String, Object?> row) {
    final columns = row.keys.where((k) => k != 'id').toList();
    final setClause = columns.map((c) => '$c = ?').join(', ');
    final values = [...columns.map((c) => row[c]), id];

    db.execute(
      'UPDATE $table SET $setClause WHERE id = ?',
      values,
    );
  }

  /// 确定合并动作
  _MergeAction _determineAction({
    required Row? local,
    required Row? remote,
    required Row? base,
    required int Function(Row) getUpdatedAt,
    required bool Function(Row, Row) equals,
  }) {
    // 情况 1：只有远程有（远程新增）
    if (local == null && remote != null && base == null) {
      return _MergeAction.addFromRemote;
    }

    // 情况 2：只有本地有（本地新增）
    if (local != null && remote == null && base == null) {
      return _MergeAction.keepLocal;
    }

    // 情况 3：两边都新增了（首次同步时可能出现）
    if (local != null && remote != null && base == null) {
      if (equals(local, remote)) {
        return _MergeAction.keepLocal;
      }
      return _MergeAction.conflict;
    }

    // 情况 4：两边都删了
    if (local == null && remote == null && base != null) {
      return _MergeAction.keepLocal;
    }

    // 情况 5：本地删了，远程有
    if (local == null && remote != null && base != null) {
      final remoteUpdatedAt = getUpdatedAt(remote);
      final baseUpdatedAt = getUpdatedAt(base);
      if (remoteUpdatedAt > baseUpdatedAt) {
        return _MergeAction.addFromRemote;
      } else {
        return _MergeAction.keepLocal;
      }
    }

    // 情况 6：远程删了，本地有
    if (local != null && remote == null && base != null) {
      final localUpdatedAt = getUpdatedAt(local);
      final baseUpdatedAt = getUpdatedAt(base);
      if (localUpdatedAt > baseUpdatedAt) {
        return _MergeAction.keepLocal;
      } else {
        return _MergeAction.deleteLocal;
      }
    }

    // 情况 7：三方都有
    if (local != null && remote != null && base != null) {
      final localChanged = !equals(local, base);
      final remoteChanged = !equals(remote, base);

      if (!localChanged && !remoteChanged) {
        return _MergeAction.keepLocal;
      }
      if (!localChanged && remoteChanged) {
        return _MergeAction.updateFromRemote;
      }
      if (localChanged && !remoteChanged) {
        return _MergeAction.keepLocal;
      }
      if (equals(local, remote)) {
        return _MergeAction.keepLocal;
      }
      return _MergeAction.conflict;
    }

    return _MergeAction.keepLocal;
  }
}

/// 合并动作
enum _MergeAction {
  keepLocal,
  addFromRemote,
  updateFromRemote,
  deleteLocal,
  conflict,
}

/// 标签冲突
class TagConflict {
  final Map<String, dynamic> local;
  final Map<String, dynamic> remote;

  TagConflict({required this.local, required this.remote});
}
