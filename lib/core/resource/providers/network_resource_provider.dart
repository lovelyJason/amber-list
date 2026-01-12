import 'package:http/http.dart' as http;

import 'resource_provider.dart';

/// 网络资源提供者
///
/// 从远程 URL（OSS/CDN）加载资源
/// 用于加载敏感资源（如微信二维码）的首选方式
///
/// 使用场景：
/// - 微信二维码/收款码（优先网络加载，防止被本地替换）
/// - 动态更新的资源（无需发布新版本）
/// - 大文件资源（减小安装包体积）
///
/// 注意事项：
/// - 网络请求可能失败，需要配合本地 fallback
/// - 建议设置合理的超时时间
/// - 生产环境建议使用 HTTPS
class NetworkResourceProvider implements ResourceProvider {
  /// 资源 URL 映射表
  ///
  /// key: 本地路径（如 'images/wechat-add.jpg'）
  /// value: 远程 URL
  final Map<String, String> _urlMapping;

  /// HTTP 请求超时时间
  final Duration _timeout;

  /// HTTP 客户端
  final http.Client _client;

  /// 创建网络资源提供者
  ///
  /// [urlMapping] 本地路径到远程 URL 的映射
  /// [timeout] 请求超时时间，默认 10 秒
  /// [client] HTTP 客户端，可传入自定义实例（便于测试）
  NetworkResourceProvider({
    required Map<String, String> urlMapping,
    Duration timeout = const Duration(seconds: 10),
    http.Client? client,
  })  : _urlMapping = urlMapping,
        _timeout = timeout,
        _client = client ?? http.Client();

  @override
  Future<ResourceResult?> load(String path) async {
    final url = _urlMapping[path];
    if (url == null) {
      // 该资源没有配置网络 URL
      return null;
    }

    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return ResourceResult(
          data: response.bodyBytes,
          source: ResourceSource.network,
        );
      } else {
        // HTTP 错误
        return null;
      }
    } catch (e) {
      // 网络错误或超时
      return null;
    }
  }

  @override
  Future<bool> exists(String path) async {
    final url = _urlMapping[path];
    if (url == null) return false;

    try {
      // 使用 HEAD 请求检查资源是否存在（节省带宽）
      final response = await _client
          .head(Uri.parse(url))
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  int get priority => 1; // 最高优先级，网络资源优先

  @override
  String get name => 'NetworkResourceProvider';

  /// 释放资源
  void dispose() {
    _client.close();
  }
}
