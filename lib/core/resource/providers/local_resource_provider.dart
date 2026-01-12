import 'package:flutter/services.dart';

import 'resource_provider.dart';

/// 本地资源提供者
///
/// 直接从 Flutter assets 加载未加密的资源文件
/// 用于加载不需要保护的公开资源（如通用图标、开源字体等）
///
/// 使用场景：
/// - 开发调试阶段（所有资源未加密）
/// - 公开资源（无需保护的图标等）
class LocalResourceProvider implements ResourceProvider {
  /// assets 基础路径前缀
  final String _basePath;

  /// 创建本地资源提供者
  ///
  /// [basePath] assets 基础路径，默认为 'assets/'
  LocalResourceProvider({String basePath = 'assets/'}) : _basePath = basePath;

  @override
  Future<ResourceResult?> load(String path) async {
    try {
      final fullPath = _basePath + path;
      final data = await rootBundle.load(fullPath);
      return ResourceResult(
        data: data.buffer.asUint8List(),
        source: ResourceSource.local,
      );
    } catch (e) {
      // 资源不存在或加载失败
      return null;
    }
  }

  @override
  Future<bool> exists(String path) async {
    try {
      final fullPath = _basePath + path;
      await rootBundle.load(fullPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  int get priority => 100; // 最低优先级，作为 fallback

  @override
  String get name => 'LocalResourceProvider';
}
