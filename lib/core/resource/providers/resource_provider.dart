import 'dart:typed_data';

/// 资源加载结果
///
/// 封装资源加载的结果，包含数据和元信息
class ResourceResult {
  /// 资源数据
  final Uint8List data;

  /// 资源来源（用于调试和日志）
  final ResourceSource source;

  /// 是否来自缓存
  final bool fromCache;

  const ResourceResult({
    required this.data,
    required this.source,
    this.fromCache = false,
  });
}

/// 资源来源枚举
///
/// 标识资源的加载来源，便于调试和监控
enum ResourceSource {
  /// 本地未加密资源
  local,

  /// 本地加密资源（解密后）
  encrypted,

  /// 网络资源（OSS/CDN）
  network,

  /// 内存缓存
  memoryCache,

  /// PAK 打包资源
  pak,
}

/// 资源提供者抽象接口
///
/// 所有资源加载器都需要实现此接口，支持：
/// - 本地原始资源加载
/// - 加密资源加载（自动解密）
/// - 网络资源加载（OSS/CDN）
///
/// 设计原则：
/// - 单一职责：每个 Provider 只负责一种加载方式
/// - 开闭原则：新增加载方式只需实现新 Provider
abstract class ResourceProvider {
  /// 加载资源
  ///
  /// [path] 资源路径，相对于 assets 目录
  /// 返回资源数据，加载失败返回 null
  Future<ResourceResult?> load(String path);

  /// 检查资源是否存在
  ///
  /// [path] 资源路径
  /// 用于快速判断，避免不必要的加载尝试
  Future<bool> exists(String path);

  /// Provider 优先级（数字越小优先级越高）
  ///
  /// 用于 ResourceManager 决定加载顺序
  int get priority;

  /// Provider 名称（用于日志）
  String get name;
}
