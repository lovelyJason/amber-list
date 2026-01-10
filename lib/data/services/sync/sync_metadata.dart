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
  LocalSyncState withSyncFailure(String error) {
    return LocalSyncState(
      lastSyncedVersion: lastSyncedVersion,
      lastSyncTime: DateTime.now(),
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
