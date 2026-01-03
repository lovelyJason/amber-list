/// ============================================================
/// 同步存储提供者抽象接口
/// ============================================================
/// 定义所有云同步服务（WebDAV、OSS 等）必须实现的统一接口
/// 遵循 Go 语言风格的面向接口编程，方便将来扩展更多存储后端
/// ============================================================

/// 同步存储提供者类型
enum SyncStorageType {
  /// WebDAV（坚果云等）
  webdav('WebDAV', 'WebDAV 协议同步（支持坚果云等）'),

  /// 七牛云 OSS
  qiniuOss('七牛云 OSS', '七牛云对象存储'),

  /// 阿里云 OSS（预留）
  aliOss('阿里云 OSS', '阿里云对象存储'),

  /// 腾讯云 COS（预留）
  tencentCos('腾讯云 COS', '腾讯云对象存储'),

  /// 琥珀清单托管云（预留）
  amberCloud('琥珀云', '琥珀清单官方托管服务');

  final String displayName;
  final String description;

  const SyncStorageType(this.displayName, this.description);

  /// 是否是 OSS 类型（七牛云、阿里云、腾讯云）
  bool get isOss =>
      this == SyncStorageType.qiniuOss ||
      this == SyncStorageType.aliOss ||
      this == SyncStorageType.tencentCos;
}

/// 同步操作结果
/// 统一封装成功/失败状态、数据和错误信息
class SyncResult<T> {
  final bool success;
  final T? data;
  final String? error;
  final SyncErrorType? errorType;

  /// 成功结果
  const SyncResult.success(this.data)
      : success = true,
        error = null,
        errorType = null;

  /// 失败结果
  const SyncResult.failure(this.error, [this.errorType])
      : success = false,
        data = null;

  @override
  String toString() {
    if (success) {
      return 'SyncResult.success(data: $data)';
    } else {
      return 'SyncResult.failure(error: $error, type: $errorType)';
    }
  }
}

/// 同步错误类型
/// 统一所有云服务的错误分类，方便 UI 层显示不同提示
enum SyncErrorType {
  /// 网络连接失败
  networkError,

  /// 认证失败（用户名/密码/AK/SK 错误）
  authFailed,

  /// 配置无效（URL/Bucket 等格式错误）
  invalidConfig,

  /// 文件/目录不存在
  notFound,

  /// 权限不足
  forbidden,

  /// 服务器错误（5xx）
  serverError,

  /// 文件被锁定（其他设备正在同步）
  locked,

  /// 超时
  timeout,

  /// 未知错误
  unknown,
}

/// ============================================================
/// 同步存储提供者接口
/// ============================================================
/// 所有云同步服务（WebDAV、OSS）必须实现此接口
/// 这是 SyncManager 依赖的唯一抽象
/// ============================================================
abstract class ISyncStorageProvider {
  /// 存储类型
  SyncStorageType get type;

  /// 测试连接和凭证是否有效
  Future<SyncResult<void>> testConnection();

  /// 确保应用根目录存在
  /// 对于 WebDAV：创建 /AmberList/ 目录
  /// 对于 OSS：确保 bucket 存在（OSS 不需要创建目录，key 自带路径）
  Future<SyncResult<void>> ensureAppDirectory();

  /// 上传数据库文件
  /// [localPath] 本地 DB 文件路径
  Future<SyncResult<void>> uploadDatabase(String localPath);

  /// 下载数据库文件
  /// [localPath] 本地保存路径
  /// 返回是否存在远程文件（true: 存在并已下载, false: 远程不存在）
  Future<SyncResult<bool>> downloadDatabase(String localPath);

  /// 读取远程元数据
  /// 返回 null 表示元数据文件不存在（首次同步）
  Future<SyncResult<Map<String, dynamic>?>> readMetadata();

  /// 写入远程元数据
  Future<SyncResult<void>> writeMetadata(Map<String, dynamic> data);

  /// 获取同步锁
  /// [deviceId] 当前设备 ID
  /// [forceAcquire] 是否强制获取（忽略超时锁）
  /// [lockTimeout] 锁超时时间
  /// 返回是否成功获取锁
  Future<SyncResult<bool>> acquireLock({
    required String deviceId,
    bool forceAcquire = false,
    Duration lockTimeout = const Duration(minutes: 5),
  });

  /// 释放同步锁
  /// [deviceId] 当前设备 ID（只能释放自己的锁）
  Future<SyncResult<void>> releaseLock(String deviceId);

  /// 上传快照
  /// [localPath] 本地 DB 文件路径
  /// [snapshotName] 快照文件名（如 amber_list_1234567890.db）
  Future<SyncResult<void>> uploadSnapshot(String localPath, String snapshotName);

  /// 清理旧快照，只保留最近 N 个
  /// [keepCount] 保留的快照数量
  Future<SyncResult<void>> cleanOldSnapshots({int keepCount = 10});

  /// 释放资源
  void dispose() {}
}
