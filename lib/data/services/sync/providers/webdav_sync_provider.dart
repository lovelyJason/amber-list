import '../webdav_client.dart';
import 'sync_storage_provider.dart';

/// ============================================================
/// WebDAV 同步存储提供者
/// ============================================================
/// 包装现有的 AmberWebDavClient，实现 ISyncStorageProvider 接口
/// 这样 SyncManager 可以通过统一接口调用，不直接依赖 WebDAV 实现
/// ============================================================
class WebDavSyncProvider implements ISyncStorageProvider {
  final AmberWebDavClient _client;

  WebDavSyncProvider(this._client);

  /// 从配置创建 WebDAV Provider
  factory WebDavSyncProvider.fromCredentials({
    required String serverUrl,
    required String username,
    required String password,
  }) {
    final client = AmberWebDavClient(
      serverUrl: serverUrl,
      username: username,
      password: password,
    );
    return WebDavSyncProvider(client);
  }

  @override
  SyncStorageType get type => SyncStorageType.webdav;

  @override
  Future<SyncResult<void>> testConnection() async {
    final result = await _client.testConnection();
    return _convertResult(result);
  }

  @override
  Future<SyncResult<void>> ensureAppDirectory() async {
    final result = await _client.ensureAppDirectory();
    return _convertResult(result);
  }

  @override
  Future<SyncResult<void>> uploadDatabase(String localPath) async {
    final result = await _client.uploadDatabase(localPath);
    return _convertResult(result);
  }

  @override
  Future<SyncResult<bool>> downloadDatabase(String localPath) async {
    final result = await _client.downloadDatabase(localPath);
    return _convertResult(result);
  }

  @override
  Future<SyncResult<Map<String, dynamic>?>> readMetadata() async {
    final result = await _client.readMetadata();
    return _convertResult(result);
  }

  @override
  Future<SyncResult<void>> writeMetadata(Map<String, dynamic> data) async {
    final result = await _client.writeMetadata(data);
    return _convertResult(result);
  }

  @override
  Future<SyncResult<bool>> acquireLock({
    required String deviceId,
    bool forceAcquire = false,
    Duration lockTimeout = const Duration(minutes: 5),
  }) async {
    final result = await _client.acquireLock(
      deviceId: deviceId,
      forceAcquire: forceAcquire,
      lockTimeout: lockTimeout,
    );
    return _convertResult(result);
  }

  @override
  Future<SyncResult<void>> releaseLock(String deviceId) async {
    final result = await _client.releaseLock(deviceId);
    return _convertResult(result);
  }

  @override
  Future<SyncResult<void>> uploadSnapshot(
    String localPath,
    String snapshotName,
  ) async {
    final result = await _client.uploadSnapshot(localPath, snapshotName);
    return _convertResult(result);
  }

  @override
  Future<SyncResult<void>> cleanOldSnapshots({int keepCount = 10}) async {
    final result = await _client.cleanOldSnapshots(keepCount: keepCount);
    return _convertResult(result);
  }

  @override
  void dispose() {
    // WebDAV 客户端没有需要释放的资源
  }

  /// 将 WebDavResult 转换为 SyncResult
  SyncResult<T> _convertResult<T>(WebDavResult<T> webdavResult) {
    if (webdavResult.success) {
      return SyncResult.success(webdavResult.data);
    } else {
      final errorType = _mapErrorType(webdavResult.errorType);
      return SyncResult.failure(webdavResult.error ?? '未知错误', errorType);
    }
  }

  /// 映射 WebDAV 错误类型到统一错误类型
  SyncErrorType _mapErrorType(WebDavErrorType? type) {
    switch (type) {
      case WebDavErrorType.networkError:
        return SyncErrorType.networkError;
      case WebDavErrorType.authenticationFailed:
        return SyncErrorType.authFailed;
      case WebDavErrorType.invalidServerUrl:
        return SyncErrorType.invalidConfig;
      case WebDavErrorType.notFound:
        return SyncErrorType.notFound;
      case WebDavErrorType.forbidden:
        return SyncErrorType.forbidden;
      case WebDavErrorType.serverError:
        return SyncErrorType.serverError;
      case WebDavErrorType.locked:
        return SyncErrorType.locked;
      case WebDavErrorType.unknown:
      case null:
        return SyncErrorType.unknown;
    }
  }
}
