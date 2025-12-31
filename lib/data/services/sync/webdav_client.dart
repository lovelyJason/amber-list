import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

import 'sync_config.dart';

/// ============================================================
/// WebDAV 客户端封装
/// ============================================================
/// 对 webdav_client 库的二次封装，提供：
/// - 统一的异常处理和错误信息
/// - 连接测试和凭证验证
/// - 目录自动创建
/// - DB 文件和 JSON 元数据的读写
/// - 文件锁机制（防止并发同步冲突）
/// ============================================================

/// WebDAV 操作结果
/// 封装操作成功/失败状态和错误信息
class WebDavResult<T> {
  final bool success;
  final T? data;
  final String? error;
  final WebDavErrorType? errorType;

  const WebDavResult.success(this.data)
      : success = true,
        error = null,
        errorType = null;

  const WebDavResult.failure(this.error, [this.errorType])
      : success = false,
        data = null;
}

/// WebDAV 错误类型
/// 用于区分不同类型的错误，方便 UI 层展示不同的提示信息
enum WebDavErrorType {
  /// 网络连接失败
  networkError,

  /// 认证失败（用户名/密码错误）
  authenticationFailed,

  /// 服务器地址无效
  invalidServerUrl,

  /// 文件/目录不存在
  notFound,

  /// 权限不足
  forbidden,

  /// 服务器错误
  serverError,

  /// 文件被锁定（其他设备正在同步）
  locked,

  /// 未知错误
  unknown,
}

/// WebDAV 客户端
/// 负责与 WebDAV 服务器的所有通信
class AmberWebDavClient {
  /// webdav_client 库的客户端实例
  late final webdav.Client _client;

  /// 服务器 URL
  final String serverUrl;

  /// 用户名
  final String username;

  /// 琥珀清单在 WebDAV 服务器上的根目录
  /// 所有同步数据都存储在这个目录下
  static const String appRootDir = 'AmberList';

  /// 数据库文件名
  static const String dbFileName = 'amber_list.db';

  /// 元数据文件名
  static const String metaFileName = 'amber_list_meta.json';

  /// 同步锁文件名（用于防止并发同步）
  static const String lockFile = '.sync.lock';

  /// 快照目录（保存历史版本，用于回滚）
  static const String snapshotDir = 'snapshots';

  /// 构造函数
  /// [serverUrl] WebDAV 服务器地址
  /// [username] 用户名
  /// [password] 密码
  AmberWebDavClient({
    required this.serverUrl,
    required this.username,
    required String password,
  }) {
    // 确保 URL 以斜杠结尾
    final normalizedUrl =
        serverUrl.endsWith('/') ? serverUrl : '$serverUrl/';

    _client = webdav.newClient(
      normalizedUrl,
      user: username,
      password: password,
      debug: false,
    );

    // 设置超时时间
    _client.setConnectTimeout(15000); // 15秒连接超时
    _client.setSendTimeout(120000); // 120秒发送超时（DB文件可能较大）
    _client.setReceiveTimeout(120000); // 120秒接收超时
  }

  /// 从 SyncConfig 创建客户端
  /// [config] 同步配置
  /// [password] 密码（从 Keychain 读取）
  static AmberWebDavClient fromConfig(SyncConfig config, String password) {
    return AmberWebDavClient(
      serverUrl: config.serverUrl,
      username: config.username,
      password: password,
    );
  }

  // ============================================================
  // 连接测试
  // ============================================================

  /// 测试连接和凭证是否有效
  /// 会尝试读取服务器根目录，验证连接和认证
  Future<WebDavResult<void>> testConnection() async {
    try {
      // 尝试读取当前目录（相对于 serverUrl 的根目录）
      // 对于坚果云等服务，serverUrl 已经包含了完整路径（如 /dav/）
      // 所以这里用空字符串或 '.' 来读取 serverUrl 本身对应的目录
      debugPrint('[WebDAV] 测试连接: serverUrl=$serverUrl, username=$username');
      debugPrint('[WebDAV] 尝试读取目录: "."');
      await _client.readDir('.');
      debugPrint('[WebDAV] 连接成功！');
      return const WebDavResult.success(null);
    } catch (e) {
      debugPrint('[WebDAV] 连接失败: $e');
      debugPrint('[WebDAV] 错误类型: ${e.runtimeType}');
      return _handleError<void>(e);
    }
  }

  // ============================================================
  // 目录操作
  // ============================================================

  /// 确保应用根目录存在
  /// 如果不存在则创建 /AmberList/ 目录
  Future<WebDavResult<void>> ensureAppDirectory() async {
    try {
      // 检查目录是否存在
      try {
        await _client.readDir(appRootDir);
        return const WebDavResult.success(null);
      } catch (_) {
        // 目录不存在，创建它
      }

      // 创建应用根目录
      await _client.mkdir(appRootDir);

      // 创建快照目录
      await _client.mkdir('$appRootDir/$snapshotDir');

      return const WebDavResult.success(null);
    } catch (e) {
      return _handleError<void>(e);
    }
  }

  /// 确保快照目录存在
  Future<WebDavResult<void>> ensureSnapshotDirectory() async {
    try {
      try {
        await _client.readDir('$appRootDir/$snapshotDir');
        return const WebDavResult.success(null);
      } catch (_) {
        await _client.mkdir('$appRootDir/$snapshotDir');
        return const WebDavResult.success(null);
      }
    } catch (e) {
      return _handleError<void>(e);
    }
  }

  // ============================================================
  // DB 文件操作
  // ============================================================

  /// 下载远程数据库文件
  /// [localPath] 本地保存路径
  /// 返回是否存在远程文件
  Future<WebDavResult<bool>> downloadDatabase(String localPath) async {
    try {
      final remotePath = '$appRootDir/$dbFileName';

      // 检查远程文件是否存在
      try {
        await _client.read(remotePath);
      } catch (e) {
        if (_isNotFoundError(e)) {
          return const WebDavResult.success(false); // 远程没有 DB 文件
        }
        rethrow;
      }

      // 下载文件
      await _client.read2File(remotePath, localPath);
      return const WebDavResult.success(true);
    } catch (e) {
      return _handleError<bool>(e);
    }
  }

  /// 上传数据库文件到远程
  /// [localPath] 本地 DB 文件路径
  Future<WebDavResult<void>> uploadDatabase(String localPath) async {
    try {
      final remotePath = '$appRootDir/$dbFileName';
      await _client.writeFromFile(localPath, remotePath);
      return const WebDavResult.success(null);
    } catch (e) {
      return _handleError<void>(e);
    }
  }

  /// 下载快照文件
  /// [snapshotName] 快照文件名（如 amber_list_20251228.db）
  /// [localPath] 本地保存路径
  Future<WebDavResult<bool>> downloadSnapshot(
    String snapshotName,
    String localPath,
  ) async {
    try {
      final remotePath = '$appRootDir/$snapshotDir/$snapshotName';

      try {
        await _client.read(remotePath);
      } catch (e) {
        if (_isNotFoundError(e)) {
          return const WebDavResult.success(false);
        }
        rethrow;
      }

      await _client.read2File(remotePath, localPath);
      return const WebDavResult.success(true);
    } catch (e) {
      return _handleError<bool>(e);
    }
  }

  /// 上传快照文件
  /// [localPath] 本地 DB 文件路径
  /// [snapshotName] 快照文件名
  Future<WebDavResult<void>> uploadSnapshot(
    String localPath,
    String snapshotName,
  ) async {
    try {
      await ensureSnapshotDirectory();

      final remotePath = '$appRootDir/$snapshotDir/$snapshotName';
      await _client.writeFromFile(localPath, remotePath);
      return const WebDavResult.success(null);
    } catch (e) {
      return _handleError<void>(e);
    }
  }

  /// 获取所有快照列表
  /// 返回快照文件名列表（按时间排序）
  Future<WebDavResult<List<String>>> listSnapshots() async {
    try {
      final path = '$appRootDir/$snapshotDir';
      final files = await _client.readDir(path);

      final snapshots = files
          .where((f) => !f.isDir! && f.name!.endsWith('.db'))
          .map((f) => f.name!)
          .toList()
        ..sort(); // 按名称排序

      return WebDavResult.success(snapshots);
    } catch (e) {
      if (_isNotFoundError(e)) {
        return const WebDavResult.success(<String>[]);
      }
      return _handleError<List<String>>(e);
    }
  }

  /// 删除旧快照（只保留最近 N 个）
  /// [keepCount] 保留的快照数量
  Future<WebDavResult<void>> cleanOldSnapshots({int keepCount = 10}) async {
    try {
      final listResult = await listSnapshots();
      if (!listResult.success) {
        return WebDavResult.failure(
          listResult.error!,
          listResult.errorType,
        );
      }

      final snapshots = listResult.data!;
      if (snapshots.length <= keepCount) {
        return const WebDavResult.success(null);
      }

      // 删除最旧的快照
      final toDelete = snapshots.take(snapshots.length - keepCount);
      for (final snapshotName in toDelete) {
        final path = '$appRootDir/$snapshotDir/$snapshotName';
        await _client.remove(path);
      }

      return const WebDavResult.success(null);
    } catch (e) {
      return _handleError<void>(e);
    }
  }

  // ============================================================
  // 元数据操作
  // ============================================================

  /// 读取远程元数据
  /// 返回元数据 Map，如果不存在返回 null
  Future<WebDavResult<Map<String, dynamic>?>> readMetadata() async {
    try {
      final path = '$appRootDir/$metaFileName';
      final bytes = await _client.read(path);
      final jsonStr = utf8.decode(bytes);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      return WebDavResult.success(data);
    } catch (e) {
      if (_isNotFoundError(e)) {
        return const WebDavResult.success(null);
      }
      return _handleError<Map<String, dynamic>?>(e);
    }
  }

  /// 写入远程元数据
  /// [data] 元数据 Map
  Future<WebDavResult<void>> writeMetadata(Map<String, dynamic> data) async {
    try {
      final path = '$appRootDir/$metaFileName';
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
      await _client.write(path, bytes);
      return const WebDavResult.success(null);
    } catch (e) {
      return _handleError<void>(e);
    }
  }

  // ============================================================
  // 同步锁机制
  // ============================================================

  /// 读取锁信息
  Future<WebDavResult<Map<String, dynamic>?>> readLock() async {
    try {
      final path = '$appRootDir/$lockFile';
      final bytes = await _client.read(path);
      final jsonStr = utf8.decode(bytes);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      return WebDavResult.success(data);
    } catch (e) {
      if (_isNotFoundError(e)) {
        return const WebDavResult.success(null);
      }
      return _handleError<Map<String, dynamic>?>(e);
    }
  }

  /// 获取同步锁
  /// [deviceId] 当前设备 ID
  /// [forceAcquire] 是否强制获取锁（超时时使用）
  /// [lockTimeout] 锁超时时间（超过此时间认为锁已失效）
  Future<WebDavResult<bool>> acquireLock({
    required String deviceId,
    bool forceAcquire = false,
    Duration lockTimeout = const Duration(minutes: 5),
  }) async {
    try {
      // 检查现有锁
      final lockResult = await readLock();
      if (!lockResult.success) {
        return WebDavResult.failure(
          lockResult.error!,
          lockResult.errorType,
        );
      }

      final existingLock = lockResult.data;
      if (existingLock != null && !forceAcquire) {
        final lockTime = DateTime.parse(existingLock['lockTime'] as String);
        final lockAge = DateTime.now().difference(lockTime);

        // 如果锁未超时且不是自己的锁，则获取失败
        if (lockAge < lockTimeout &&
            existingLock['deviceId'] != deviceId) {
          return const WebDavResult.failure(
            '其他设备正在同步中，请稍后再试',
            WebDavErrorType.locked,
          );
        }
      }

      // 写入新锁
      final lockData = {
        'deviceId': deviceId,
        'lockTime': DateTime.now().toIso8601String(),
      };

      final path = '$appRootDir/$lockFile';
      final jsonStr = jsonEncode(lockData);
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
      await _client.write(path, bytes);

      return const WebDavResult.success(true);
    } catch (e) {
      return _handleError<bool>(e);
    }
  }

  /// 释放同步锁
  /// [deviceId] 当前设备 ID（只能释放自己的锁）
  Future<WebDavResult<void>> releaseLock(String deviceId) async {
    try {
      // 检查锁是否属于自己
      final lockResult = await readLock();
      if (lockResult.success && lockResult.data != null) {
        if (lockResult.data!['deviceId'] != deviceId) {
          // 不是自己的锁，不操作
          return const WebDavResult.success(null);
        }
      }

      // 删除锁文件
      final path = '$appRootDir/$lockFile';
      await _client.remove(path);
      return const WebDavResult.success(null);
    } catch (e) {
      // 锁文件不存在也算成功
      if (_isNotFoundError(e)) {
        return const WebDavResult.success(null);
      }
      return _handleError<void>(e);
    }
  }

  // ============================================================
  // 错误处理
  // ============================================================

  /// 判断是否是"文件不存在"错误
  bool _isNotFoundError(dynamic e) {
    final errorStr = e.toString().toLowerCase();
    return errorStr.contains('404') ||
        errorStr.contains('not found') ||
        errorStr.contains('no such file');
  }

  /// 统一错误处理
  /// 将各种异常转换为统一的 WebDavResult
  WebDavResult<T> _handleError<T>(dynamic e) {
    final errorStr = e.toString().toLowerCase();

    // 认证失败
    if (errorStr.contains('401') || errorStr.contains('unauthorized')) {
      return const WebDavResult.failure(
        '用户名或密码错误',
        WebDavErrorType.authenticationFailed,
      );
    }

    // 权限不足
    if (errorStr.contains('403') || errorStr.contains('forbidden')) {
      return const WebDavResult.failure(
        '权限不足，请检查 WebDAV 权限设置',
        WebDavErrorType.forbidden,
      );
    }

    // 文件不存在
    if (_isNotFoundError(e)) {
      return const WebDavResult.failure(
        '文件或目录不存在',
        WebDavErrorType.notFound,
      );
    }

    // 服务器错误
    if (errorStr.contains('5')) {
      // 5xx 错误
      return WebDavResult.failure(
        '服务器错误: $e',
        WebDavErrorType.serverError,
      );
    }

    // 网络错误
    if (errorStr.contains('timeout') ||
        errorStr.contains('connection') ||
        errorStr.contains('network') ||
        errorStr.contains('socket')) {
      return const WebDavResult.failure(
        '网络连接失败，请检查网络设置',
        WebDavErrorType.networkError,
      );
    }

    // 无效 URL
    if (errorStr.contains('invalid') && errorStr.contains('url')) {
      return const WebDavResult.failure(
        'WebDAV 服务器地址无效',
        WebDavErrorType.invalidServerUrl,
      );
    }

    // 未知错误
    return WebDavResult.failure(
      '同步失败: $e',
      WebDavErrorType.unknown,
    );
  }
}
