/// 资源管理模块
///
/// 提供统一的资源加载接口，支持：
/// - 本地资源加载
/// - 加密资源加载（AES-256-CBC）
/// - 网络资源加载（OSS/CDN）
/// - PAK 打包资源加载
/// - LRU 内存缓存
///
/// 使用示例：
/// ```dart
/// // 1. 初始化（在 main.dart 中）
/// ResourceManager.initialize(ResourceConfig.production(
///   networkUrls: {
///     'images/wechat-add.jpg': 'https://cdn.example.com/wechat-add.jpg',
///   },
/// ));
///
/// // 2. 加载资源
/// final imageData = await ResourceManager.instance.load('images/logo.png');
///
/// // 3. 在 Widget 中使用
/// Image.memory(imageData!)
/// ```
library;

export 'cache/memory_cache.dart';
export 'providers/encrypted_resource_provider.dart';
export 'providers/local_resource_provider.dart';
export 'providers/network_resource_provider.dart';
export 'providers/pak_resource_provider.dart';
export 'providers/resource_provider.dart';
export 'resource_manager.dart';
export 'security/aes_cipher.dart';
