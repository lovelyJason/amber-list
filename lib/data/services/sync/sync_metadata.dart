import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// ============================================================
/// 同步元数据模型
/// ============================================================
/// 管理同步状态信息：
/// - 远程元数据（存储在 WebDAV: amber_list_meta.json）
/// - 本地元数据（存储在 SharedPreferences）
/// - 用于判断本地/远程是否有变化
/// ============================================================

/// 远程元数据
/// 存储在 WebDAV 服务器的 amber_list_meta.json
class RemoteSyncMetadata {
  /// 数据版本号（每次同步递增）
  final int version;

  /// 最后修改时间
  final DateTime lastModified;

  /// 最后修改的设备 ID
  final String deviceId;

  /// 数据库文件的 MD5 校验和
  final String checksum;

  const RemoteSyncMetadata({
    required this.version,
    required this.lastModified,
    required this.deviceId,
    required this.checksum,
  });

  /// 创建初始元数据
  factory RemoteSyncMetadata.initial({required String deviceId}) {
    return RemoteSyncMetadata(
      version: 1,
      lastModified: DateTime.now(),
      deviceId: deviceId,
      checksum: '',
    );
  }

  /// 从 JSON 反序列化
  factory RemoteSyncMetadata.fromJson(Map<String, dynamic> json) {
    return RemoteSyncMetadata(
      version: json['version'] as int? ?? 1,
      lastModified: DateTime.parse(json['lastModified'] as String),
      deviceId: json['deviceId'] as String? ?? '',
      checksum: json['checksum'] as String? ?? '',
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() => {
        'version': version,
        'lastModified': lastModified.toIso8601String(),
        'deviceId': deviceId,
        'checksum': checksum,
      };

  /// 创建新版本
  RemoteSyncMetadata nextVersion({
    required String deviceId,
    required String checksum,
  }) {
    return RemoteSyncMetadata(
      version: version + 1,
      lastModified: DateTime.now(),
      deviceId: deviceId,
      checksum: checksum,
    );
  }

  @override
  String toString() {
    return 'RemoteSyncMetadata(version: $version, lastModified: $lastModified, '
        'deviceId: $deviceId, checksum: ${checksum.substring(0, 8)}...)';
  }
}

/// 本地同步状态
/// 存储在 SharedPreferences，用于判断本地是否有未同步的变化
class LocalSyncState {
  /// 上次成功同步的远程版本号
  final int lastSyncedVersion;

  /// 上次成功同步的时间
  final DateTime? lastSyncTime;

  /// 上次同步后本地数据库的校验和
  /// 如果当前校验和与此不同，说明本地有改动
  final String lastSyncedChecksum;

  /// 上次同步是否成功
  final bool lastSyncSuccess;

  /// 上次同步的错误信息
  final String? lastSyncError;

  const LocalSyncState({
    this.lastSyncedVersion = 0,
    this.lastSyncTime,
    this.lastSyncedChecksum = '',
    this.lastSyncSuccess = true,
    this.lastSyncError,
  });

  /// 从 JSON 反序列化
  factory LocalSyncState.fromJson(Map<String, dynamic> json) {
    return LocalSyncState(
      lastSyncedVersion: json['lastSyncedVersion'] as int? ?? 0,
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.parse(json['lastSyncTime'] as String)
          : null,
      lastSyncedChecksum: json['lastSyncedChecksum'] as String? ?? '',
      lastSyncSuccess: json['lastSyncSuccess'] as bool? ?? true,
      lastSyncError: json['lastSyncError'] as String?,
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() => {
        'lastSyncedVersion': lastSyncedVersion,
        'lastSyncTime': lastSyncTime?.toIso8601String(),
        'lastSyncedChecksum': lastSyncedChecksum,
        'lastSyncSuccess': lastSyncSuccess,
        'lastSyncError': lastSyncError,
      };

  /// 更新同步成功状态
  LocalSyncState withSyncSuccess({
    required int version,
    required String checksum,
  }) {
    return LocalSyncState(
      lastSyncedVersion: version,
      lastSyncTime: DateTime.now(),
      lastSyncedChecksum: checksum,
      lastSyncSuccess: true,
      lastSyncError: null,
    );
  }

  /// 更新同步失败状态
  ///
  /// 注意：失败时保持 lastSyncTime 不变，不更新为当前时间。
  /// 这是为了配合启动限流机制：失败的同步不应计入"有效同步"，
  /// 否则会导致用户在网络恢复后仍被限流、无法及时同步数据。
  LocalSyncState withSyncFailure(String error) {
    return LocalSyncState(
      lastSyncedVersion: lastSyncedVersion,
      lastSyncTime: lastSyncTime, // 保持原值，不更新
      lastSyncedChecksum: lastSyncedChecksum,
      lastSyncSuccess: false,
      lastSyncError: error,
    );
  }
}

/// 同步状态服务
/// 负责本地同步状态的持久化
class SyncStateService {
  static const _stateKey = 'amber_list_sync_state';

  /// 加载本地同步状态
  static Future<LocalSyncState> loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_stateKey);

      if (jsonStr == null || jsonStr.isEmpty) {
        return const LocalSyncState();
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return LocalSyncState.fromJson(json);
    } catch (e) {
      return const LocalSyncState();
    }
  }

  /// 保存本地同步状态
  static Future<void> saveState(LocalSyncState state) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(state.toJson());
    await prefs.setString(_stateKey, jsonStr);
  }

  /// 清除同步状态
  static Future<void> clearState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stateKey);
  }
}

/// 文件校验和工具
class ChecksumUtils {
  /// 计算文件的 MD5 校验和
  static Future<String> computeFileChecksum(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return '';
    }

    final bytes = await file.readAsBytes();
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// 计算字节数据的 MD5 校验和
  static String computeBytesChecksum(List<int> bytes) {
    final digest = md5.convert(bytes);
    return digest.toString();
  }
}

/// ============================================================
/// 数据库完整性验证工具
/// ============================================================
/// 用于验证 SQLite 数据库文件是否完整可用。
/// 主要场景：
/// 1. 下载云端数据库后，验证文件是否损坏
/// 2. 上传前验证本地数据库是否正常
/// ============================================================
class DatabaseIntegrityUtils {
  /// 验证数据库文件完整性
  ///
  /// 使用 SQLite 的 PRAGMA integrity_check 命令检查数据库是否损坏。
  /// 返回值：
  /// - [DatabaseIntegrityResult.ok] 数据库正常
  /// - [DatabaseIntegrityResult.corrupted] 数据库损坏
  /// - [DatabaseIntegrityResult.notFound] 文件不存在
  /// - [DatabaseIntegrityResult.error] 其他错误
  ///
  /// 参数：
  /// - [dbPath] 数据库文件路径
  /// - [testWalMode] 是否测试 WAL 模式（默认 false）
  ///   - true: 用于验证下载的临时数据库文件（未被其他连接占用）
  ///   - false: 用于验证正在使用的本地数据库（避免锁冲突）
  static Future<DatabaseIntegrityResult> verifyDatabase(
    String dbPath, {
    bool testWalMode = false,
  }) async {
    final file = File(dbPath);
    if (!await file.exists()) {
      return DatabaseIntegrityResult(
        status: DatabaseIntegrityStatus.notFound,
        message: '数据库文件不存在: $dbPath',
      );
    }

    sqlite3.Database? db;
    try {
      // 根据参数选择打开模式：
      // - testWalMode=true: 读写模式，用于测试下载的临时文件
      // - testWalMode=false: 只读模式，避免与 Drift 连接冲突
      final openMode = testWalMode
          ? sqlite3.OpenMode.readWrite
          : sqlite3.OpenMode.readOnly;
      db = sqlite3.sqlite3.open(dbPath, mode: openMode);

      // 如果需要测试 WAL 模式（仅用于临时文件）
      if (testWalMode) {
        try {
          db.execute('PRAGMA journal_mode = WAL');
          db.execute('PRAGMA busy_timeout = 5000');
          db.execute('PRAGMA foreign_keys = ON');
        } catch (e) {
          debugPrint('[DatabaseIntegrity] ❌ WAL 模式设置失败: $e');
          return DatabaseIntegrityResult(
            status: DatabaseIntegrityStatus.corrupted,
            message: 'WAL 模式设置失败: $e',
          );
        }
      }

      // 执行完整性检查
      final result = db.select('PRAGMA integrity_check;');
      if (result.isEmpty) {
        return DatabaseIntegrityResult(
          status: DatabaseIntegrityStatus.error,
          message: 'integrity_check 返回空结果',
        );
      }

      // 检查结果，正常情况下返回 "ok"
      final checkResult = result.first.values.first?.toString() ?? '';
      if (checkResult.toLowerCase() == 'ok') {
        debugPrint('[DatabaseIntegrity] ✅ 数据库完整性检查通过: $dbPath');
        return DatabaseIntegrityResult(
          status: DatabaseIntegrityStatus.ok,
          message: 'ok',
        );
      } else {
        debugPrint('[DatabaseIntegrity] ❌ 数据库损坏: $checkResult');
        return DatabaseIntegrityResult(
          status: DatabaseIntegrityStatus.corrupted,
          message: checkResult,
        );
      }
    } catch (e) {
      debugPrint('[DatabaseIntegrity] ❌ 验证失败: $e');
      return DatabaseIntegrityResult(
        status: DatabaseIntegrityStatus.error,
        message: e.toString(),
      );
    } finally {
      db?.dispose();
    }
  }

  /// 快速验证数据库是否可打开
  ///
  /// 比 [verifyDatabase] 更快，只检查能否正常打开和执行简单查询。
  /// 适用于快速预检场景。
  static Future<bool> canOpenDatabase(String dbPath) async {
    final file = File(dbPath);
    if (!await file.exists()) {
      return false;
    }

    sqlite3.Database? db;
    try {
      db = sqlite3.sqlite3.open(dbPath, mode: sqlite3.OpenMode.readOnly);
      // 执行一个简单查询验证数据库可用
      db.select('SELECT 1;');
      return true;
    } catch (e) {
      debugPrint('[DatabaseIntegrity] 无法打开数据库: $e');
      return false;
    } finally {
      db?.dispose();
    }
  }

  /// 尝试修复损坏的数据库
  ///
  /// 修复策略：
  /// 1. 先尝试 REINDEX（修复索引损坏）
  /// 2. 再尝试 VACUUM（重建数据库文件）
  /// 3. 如果上述失败，尝试 .dump 导出再导入到新库
  ///
  /// 返回值：
  /// - [DatabaseRepairResult] 包含修复是否成功和详细信息
  static Future<DatabaseRepairResult> repairDatabase(String dbPath) async {
    final file = File(dbPath);
    if (!await file.exists()) {
      return DatabaseRepairResult(
        success: false,
        message: '数据库文件不存在',
      );
    }

    // 先创建备份
    final backupPath = '$dbPath.backup_${DateTime.now().millisecondsSinceEpoch}';
    try {
      await file.copy(backupPath);
      debugPrint('[DatabaseRepair] ✅ 已创建备份: $backupPath');
    } catch (e) {
      return DatabaseRepairResult(
        success: false,
        message: '无法创建备份: $e',
      );
    }

    sqlite3.Database? db;
    try {
      // 尝试方法1：REINDEX + VACUUM
      debugPrint('[DatabaseRepair] 尝试方法1: REINDEX + VACUUM');
      db = sqlite3.sqlite3.open(dbPath, mode: sqlite3.OpenMode.readWrite);

      try {
        db.execute('REINDEX;');
        debugPrint('[DatabaseRepair] REINDEX 执行成功');
      } catch (e) {
        debugPrint('[DatabaseRepair] REINDEX 失败: $e');
      }

      try {
        db.execute('VACUUM;');
        debugPrint('[DatabaseRepair] VACUUM 执行成功');
      } catch (e) {
        debugPrint('[DatabaseRepair] VACUUM 失败: $e');
      }

      db.dispose();
      db = null;

      // 验证修复结果
      final verifyResult = await verifyDatabase(dbPath);
      if (verifyResult.isOk) {
        // 修复成功，删除备份
        try {
          await File(backupPath).delete();
        } catch (_) {}
        return DatabaseRepairResult(
          success: true,
          message: '数据库已通过 REINDEX + VACUUM 修复',
        );
      }

      debugPrint('[DatabaseRepair] 方法1失败，尝试方法2: dump + 重建');

      // 尝试方法2：dump 数据到新库
      final newDbPath = '$dbPath.new';
      db = sqlite3.sqlite3.open(dbPath, mode: sqlite3.OpenMode.readOnly);
      sqlite3.Database? newDb;

      try {
        newDb = sqlite3.sqlite3.open(newDbPath, mode: sqlite3.OpenMode.readWriteCreate);

        // 复制 schema version（Drift 使用 user_version pragma）
        // 这很重要，否则 Drift 会认为是新数据库并尝试插入种子数据
        final userVersionResult = db.select('PRAGMA user_version');
        final userVersion = userVersionResult.isNotEmpty
            ? userVersionResult.first['user_version'] as int
            : 0;
        if (userVersion > 0) {
          newDb.execute('PRAGMA user_version = $userVersion');
          debugPrint('[DatabaseRepair] 复制 schema version: $userVersion');
        }

        // 获取所有表的 schema 和数据
        final tables = db.select(
          "SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
        );

        for (final table in tables) {
          final tableName = table['name'] as String;
          final createSql = table['sql'] as String?;

          if (createSql != null) {
            // 创建表
            try {
              newDb.execute(createSql);
              debugPrint('[DatabaseRepair] 创建表: $tableName');

              // 复制数据
              final rows = db.select('SELECT * FROM "$tableName"');
              if (rows.isNotEmpty) {
                final columns = rows.first.keys.toList();
                final placeholders = List.filled(columns.length, '?').join(', ');
                final insertSql =
                    'INSERT INTO "$tableName" (${columns.map((c) => '"$c"').join(', ')}) VALUES ($placeholders)';

                final stmt = newDb.prepare(insertSql);
                for (final row in rows) {
                  stmt.execute(row.values.toList());
                }
                stmt.dispose();
                debugPrint('[DatabaseRepair] 复制 $tableName: ${rows.length} 行');
              }
            } catch (e) {
              debugPrint('[DatabaseRepair] 处理表 $tableName 失败: $e');
            }
          }
        }

        // 复制索引
        final indexes = db.select(
          "SELECT sql FROM sqlite_master WHERE type='index' AND sql IS NOT NULL",
        );
        for (final idx in indexes) {
          final sql = idx['sql'] as String?;
          if (sql != null) {
            try {
              newDb.execute(sql);
            } catch (_) {}
          }
        }

        newDb.dispose();
        newDb = null;
        db.dispose();
        db = null;

        // 验证新库
        final newVerifyResult = await verifyDatabase(newDbPath);
        if (newVerifyResult.isOk) {
          // 新库正常，替换旧库
          await File(dbPath).delete();
          await File(newDbPath).rename(dbPath);
          // 删除备份
          try {
            await File(backupPath).delete();
          } catch (_) {}
          return DatabaseRepairResult(
            success: true,
            message: '数据库已通过重建方式修复',
          );
        } else {
          // 新库也有问题，删除
          try {
            await File(newDbPath).delete();
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('[DatabaseRepair] 方法2失败: $e');
        newDb?.dispose();
        try {
          await File(newDbPath).delete();
        } catch (_) {}
      }

      // 所有方法都失败
      return DatabaseRepairResult(
        success: false,
        message: '无法修复数据库，备份已保存至: $backupPath',
        backupPath: backupPath,
      );
    } catch (e) {
      debugPrint('[DatabaseRepair] 修复过程异常: $e');
      return DatabaseRepairResult(
        success: false,
        message: '修复异常: $e，备份已保存至: $backupPath',
        backupPath: backupPath,
      );
    } finally {
      db?.dispose();
    }
  }
}

/// 数据库完整性状态
enum DatabaseIntegrityStatus {
  /// 数据库正常
  ok,

  /// 数据库损坏
  corrupted,

  /// 文件不存在
  notFound,

  /// 其他错误
  error,
}

/// 数据库完整性检查结果
class DatabaseIntegrityResult {
  final DatabaseIntegrityStatus status;
  final String message;

  const DatabaseIntegrityResult({
    required this.status,
    required this.message,
  });

  /// 数据库是否正常
  bool get isOk => status == DatabaseIntegrityStatus.ok;

  /// 数据库是否损坏
  bool get isCorrupted => status == DatabaseIntegrityStatus.corrupted;

  @override
  String toString() => 'DatabaseIntegrityResult($status: $message)';
}

/// 数据库修复结果
class DatabaseRepairResult {
  /// 修复是否成功
  final bool success;

  /// 修复过程的详细信息
  final String message;

  /// 备份文件路径（修复失败时保留）
  final String? backupPath;

  const DatabaseRepairResult({
    required this.success,
    required this.message,
    this.backupPath,
  });

  @override
  String toString() => 'DatabaseRepairResult(success: $success, message: $message)';
}
