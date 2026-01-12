import 'package:flutter/foundation.dart';

import 'cache/memory_cache.dart';
import 'providers/encrypted_resource_provider.dart';
import 'providers/local_resource_provider.dart';
import 'providers/network_resource_provider.dart';
import 'providers/pak_resource_provider.dart';
import 'providers/resource_provider.dart';

/// 资源配置
///
/// 定义哪些资源走网络加载、是否启用 PAK 等
class ResourceConfig {
  /// 网络资源 URL 映射
  ///
  /// key: 本地路径（如 'images/wechat-add.jpg'）
  /// value: 远程 URL
  final Map<String, String> networkUrls;

  /// 是否启用加密资源（生产环境启用）
  final bool enableEncryption;

  /// 是否启用 PAK 打包资源（Release 模式启用）
  ///
  /// PAK 文件将 assets 目录下的所有文件合并为单个文件，
  /// 隐藏目录结构，防止资源被直接浏览。
  final bool enablePak;

  /// 自定义 PAK 文件路径（可选）
  ///
  /// 为 null 时使用默认路径：
  /// - Windows: `<exe目录>/data/flutter_assets/resources.pak`
  /// - macOS: `<app>/Contents/Frameworks/App.framework/Resources/flutter_assets/resources.pak`
  final String? pakPath;

  /// 是否启用内存缓存
  final bool enableCache;

  const ResourceConfig({
    this.networkUrls = const {},
    this.enableEncryption = true,
    this.enablePak = false,
    this.pakPath,
    this.enableCache = true,
  });

  /// 开发环境配置（不加密、不用 PAK，便于调试）
  static const development = ResourceConfig(
    enableEncryption: false,
    enablePak: false,
    enableCache: true,
  );

  /// 生产环境配置（启用加密和 PAK）
  static ResourceConfig production({
    required Map<String, String> networkUrls,
    bool enablePak = true,
    String? pakPath,
  }) {
    return ResourceConfig(
      networkUrls: networkUrls,
      enableEncryption: true,
      enablePak: enablePak,
      pakPath: pakPath,
      enableCache: true,
    );
  }
}

/// 资源管理器
///
/// 统一的资源加载入口，支持：
/// - 多 Provider 按优先级加载（网络 > PAK > 加密 > 本地）
/// - 内存缓存（LRU 策略）
/// - 自动降级（网络失败时依次尝试其他 Provider）
/// - PAK 打包资源（隐藏目录结构，防止资源被直接浏览）
///
/// 使用方式：
/// ```dart
/// // 初始化（在 main.dart 中）
/// ResourceManager.initialize(ResourceConfig.production(
///   networkUrls: {
///     'images/wechat-add.jpg': 'https://cdn.example.com/wechat-add.jpg',
///   },
///   enablePak: true, // Release 模式启用 PAK
/// ));
///
/// // 加载资源
/// final data = await ResourceManager.instance.load('images/logo.png');
/// ```
///
/// 架构设计：
/// ```
/// ┌───────────────────────────────────────────────────────────────┐
/// │                      ResourceManager                          │
/// │  ┌─────────────────────────────────────────────────────────┐ │
/// │  │                  MemoryCache (LRU)                       │ │
/// │  └─────────────────────────────────────────────────────────┘ │
/// │                            ↓                                  │
/// │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
/// │  │ Network  │→ │   PAK    │→ │Encrypted │→ │  Local   │     │
/// │  │ Provider │  │ Provider │  │ Provider │  │ Provider │     │
/// │  │(优先级 1) │  │(优先级 50)│  │(优先级 10)│  │(优先级100)│    │
/// │  └──────────┘  └──────────┘  └──────────┘  └──────────┘     │
/// └───────────────────────────────────────────────────────────────┘
/// ```
///
/// Provider 优先级说明：
/// - Network (1): 敏感资源优先从网络加载（如微信二维码）
/// - PAK (50): Release 模式下从 PAK 文件加载（隐藏目录结构）
/// - Encrypted (10): 加密资源（AES-256-CBC）
/// - Local (100): 原始本地资源（开发调试用）
class ResourceManager {
  /// 单例实例
  static ResourceManager? _instance;

  /// 获取单例实例
  ///
  /// 必须先调用 [initialize] 初始化
  static ResourceManager get instance {
    if (_instance == null) {
      throw StateError('ResourceManager 未初始化，请先调用 initialize()');
    }
    return _instance!;
  }

  /// 检查是否已初始化
  static bool get isInitialized => _instance != null;

  /// 初始化资源管理器
  ///
  /// [config] 资源配置
  /// 应在 app 启动时调用一次
  static void initialize(ResourceConfig config) {
    _instance = ResourceManager._(config);
  }

  /// 重置（仅用于测试）
  @visibleForTesting
  static void reset() {
    _instance?.dispose();
    _instance = null;
  }

  /// 资源配置
  final ResourceConfig _config;

  /// 内存缓存
  final MemoryCache _cache;

  /// 资源提供者列表（按优先级排序）
  final List<ResourceProvider> _providers;

  /// 网络资源提供者（需要单独持有以便释放）
  NetworkResourceProvider? _networkProvider;

  /// PAK 资源提供者（需要单独持有以便释放）
  PakResourceProvider? _pakProvider;

  /// 私有构造函数
  ResourceManager._(this._config)
      : _cache = MemoryCache(),
        _providers = [] {
    _initProviders();
  }

  /// 初始化资源提供者
  void _initProviders() {
    // 1. 网络资源提供者（最高优先级 = 1）
    if (_config.networkUrls.isNotEmpty) {
      _networkProvider = NetworkResourceProvider(
        urlMapping: _config.networkUrls,
      );
      _providers.add(_networkProvider!);
    }

    // 2. PAK 资源提供者（优先级 = 50）
    //    Release 模式下，资源被打包到单个 PAK 文件中
    if (_config.enablePak) {
      _pakProvider = PakResourceProvider(pakPath: _config.pakPath);
      _providers.add(_pakProvider!);
    }

    // 3. 加密资源提供者（优先级 = 10）
    if (_config.enableEncryption) {
      _providers.add(EncryptedResourceProvider());
    }

    // 4. 本地资源提供者（最低优先级 = 100，作为 fallback）
    _providers.add(LocalResourceProvider());

    // 按优先级排序（数字越小优先级越高）
    _providers.sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// 加载资源
  ///
  /// [path] 资源路径，相对于 assets 目录（如 'images/logo.png'）
  /// [useCache] 是否使用缓存，默认 true
  /// 返回资源数据，加载失败返回 null
  ///
  /// 加载顺序：
  /// 1. 检查内存缓存
  /// 2. 按优先级依次尝试各 Provider
  /// 3. 成功后存入缓存
  Future<Uint8List?> load(String path, {bool useCache = true}) async {
    // 1. 检查缓存
    if (useCache && _config.enableCache) {
      final cached = _cache.get(path);
      if (cached != null) {
        _log('[$path] 命中缓存 (${cached.source})');
        return cached.data;
      }
    }

    // 2. 依次尝试各 Provider
    for (final provider in _providers) {
      final result = await provider.load(path);
      if (result != null) {
        _log('[$path] 从 ${provider.name} 加载成功');

        // 存入缓存
        if (useCache && _config.enableCache) {
          _cache.put(path, result);
        }

        return result.data;
      }
    }

    _log('[$path] 加载失败：所有 Provider 均未找到资源');
    return null;
  }

  /// 加载资源（带详细结果）
  ///
  /// 与 [load] 类似，但返回完整的 [ResourceResult]
  /// 包含资源来源信息，便于调试和监控
  Future<ResourceResult?> loadWithResult(
    String path, {
    bool useCache = true,
  }) async {
    // 1. 检查缓存
    if (useCache && _config.enableCache) {
      final cached = _cache.get(path);
      if (cached != null) {
        return cached;
      }
    }

    // 2. 依次尝试各 Provider
    for (final provider in _providers) {
      final result = await provider.load(path);
      if (result != null) {
        // 存入缓存
        if (useCache && _config.enableCache) {
          _cache.put(path, result);
        }
        return result;
      }
    }

    return null;
  }

  /// 预加载资源列表
  ///
  /// [paths] 资源路径列表
  /// 用于启动时预热常用资源，提高后续加载速度
  Future<void> preload(List<String> paths) async {
    await Future.wait(paths.map((path) => load(path)));
  }

  /// 清除缓存
  void clearCache() {
    _cache.clear();
    _log('缓存已清空');
  }

  /// 获取缓存统计信息
  Map<String, dynamic> get cacheStats => _cache.stats;

  /// 释放资源
  void dispose() {
    _networkProvider?.dispose();
    _pakProvider?.dispose();
    _cache.clear();
  }

  /// 日志输出
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[ResourceManager] $message');
    }
  }
}
