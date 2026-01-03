import '../sync_storage_provider.dart';

/// ============================================================
/// OSS 对象存储统一接口
/// ============================================================
/// 抽象层，定义所有 OSS 服务（七牛云、阿里云、腾讯云）的统一操作
/// 遵循 Go 语言风格的面向接口编程
///
/// 目录结构（与 WebDAV 保持一致）:
/// {bucket}/
/// └── AmberList/
///     ├── amber_list.db           # 数据库文件
///     ├── amber_list_meta.json    # 同步元数据
///     ├── .sync.lock              # 同步锁文件
///     └── snapshots/              # 历史快照
///         └── amber_list_xxxx.db
/// ============================================================

/// OSS 提供商类型
enum OssVendor {
  /// 七牛云
  qiniu('七牛云', 'Qiniu'),

  /// 阿里云（预留）
  aliyun('阿里云', 'Aliyun'),

  /// 腾讯云（预留）
  tencent('腾讯云', 'Tencent');

  final String displayName;
  final String code;

  const OssVendor(this.displayName, this.code);
}

/// OSS 区域配置
class OssRegion {
  /// 区域代码（如 z0, z1, cn-east-1 等）
  final String code;

  /// 显示名称（如 华东、华北）
  final String displayName;

  /// 上传域名
  final String uploadHost;

  /// 下载域名前缀（拼接 bucket 后使用）
  final String downloadHostSuffix;

  const OssRegion({
    required this.code,
    required this.displayName,
    required this.uploadHost,
    required this.downloadHostSuffix,
  });
}

/// OSS 配置
class OssConfig {
  /// OSS 提供商
  final OssVendor vendor;

  /// Access Key
  final String accessKey;

  /// Secret Key（敏感信息，存储在 Keychain）
  final String secretKey;

  /// Bucket 名称
  final String bucket;

  /// 区域
  final OssRegion region;

  /// 自定义域名（可选，用于下载）
  final String? customDomain;

  const OssConfig({
    required this.vendor,
    required this.accessKey,
    required this.secretKey,
    required this.bucket,
    required this.region,
    this.customDomain,
  });

  /// 是否配置完整
  bool get isConfigured =>
      accessKey.isNotEmpty && secretKey.isNotEmpty && bucket.isNotEmpty;
}

/// ============================================================
/// OSS 统一操作接口
/// ============================================================
/// 所有 OSS 实现（七牛云、阿里云、腾讯云）必须实现此接口
/// 这是一个底层接口，OssSyncProvider 会包装它实现 ISyncStorageProvider
/// ============================================================
abstract class IOssClient {
  /// OSS 提供商
  OssVendor get vendor;

  /// 测试连接（验证 AK/SK 和 Bucket）
  Future<SyncResult<void>> testConnection();

  /// 上传文件
  /// [localPath] 本地文件路径
  /// [remoteKey] 远程对象 key（如 AmberList/amber_list.db）
  Future<SyncResult<void>> uploadFile(String localPath, String remoteKey);

  /// 上传字节数据
  /// [data] 字节数据
  /// [remoteKey] 远程对象 key
  Future<SyncResult<void>> uploadBytes(List<int> data, String remoteKey);

  /// 下载文件
  /// [remoteKey] 远程对象 key
  /// [localPath] 本地保存路径
  /// 返回是否存在（true: 存在并已下载, false: 不存在）
  Future<SyncResult<bool>> downloadFile(String remoteKey, String localPath);

  /// 下载字节数据
  /// [remoteKey] 远程对象 key
  /// 返回字节数据，如果不存在返回 null
  Future<SyncResult<List<int>?>> downloadBytes(String remoteKey);

  /// 检查文件是否存在
  /// [remoteKey] 远程对象 key
  Future<SyncResult<bool>> fileExists(String remoteKey);

  /// 删除文件
  /// [remoteKey] 远程对象 key
  Future<SyncResult<void>> deleteFile(String remoteKey);

  /// 列出目录下的文件
  /// [prefix] 前缀（如 AmberList/snapshots/）
  /// 返回文件名列表
  Future<SyncResult<List<String>>> listFiles(String prefix);

  /// 释放资源
  void dispose() {}
}
