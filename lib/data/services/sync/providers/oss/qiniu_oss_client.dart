import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:qiniu_flutter_sdk/qiniu_flutter_sdk.dart';

import '../sync_storage_provider.dart';
import 'oss_provider.dart';

/// ============================================================
/// 七牛云 OSS 客户端（增强版）
/// ============================================================
/// 实现 IOssClient 接口，封装七牛云的完整文件操作能力
///
/// ## 为什么在客户端生成 Token？
///
/// 七牛官方文档说"客户端 SDK 不含 token 生成"，这是针对 Web/移动端的安全建议，
/// 因为 Web 端的 JavaScript 代码容易被反编译，SecretKey 会暴露。
///
/// 但琥珀清单是**桌面应用（自托管模式）**，情况完全不同：
/// 1. 用户自己输入 AK/SK，存储在系统 Keychain（macOS）或 Credential Manager（Windows）
/// 2. 除非用户自己泄露，否则没人知道密钥
/// 3. 类似 OSS Browser、Cyberduck 等官方/知名客户端都是这么做的
///
/// 因此，我们在客户端实现了完整的 Token 生成逻辑，基于官方 SDK 做了增强：
/// - 上传 Token 生成（putPolicy + HMAC-SHA1 签名）
/// - 私有下载 URL 签名
/// - 管理凭证生成（RS API 鉴权）
///
/// ## API 调用方式
///
/// | 操作     | API                    | 认证方式        |
/// |---------|------------------------|----------------|
/// | 上传文件 | qiniu_flutter_sdk      | Upload Token   |
/// | 下载文件 | HTTP GET + 签名 URL    | 私有链接签名    |
/// | 检查文件 | RS API `/stat`         | QBox Token     |
/// | 删除文件 | RS API `/delete`       | QBox Token     |
/// | 列出文件 | RSF API `/list`        | QBox Token     |
///
/// ## 托管模式说明
///
/// 本实现仅适用于"自托管模式"（用户自己的 AK/SK）。
/// "托管模式"（琥珀云）需要服务端签发临时凭证，后续版本实现。
///
/// @see docs/sync/多云端同步架构.md 完整设计文档
/// ============================================================

/// 七牛云区域配置
/// 不同区域的 API Host 不同，必须匹配否则会认证失败
class QiniuRegion extends OssRegion {
  /// RS API Host（用于 stat、delete 等操作）
  final String rsHost;

  /// RSF API Host（用于 list 操作）
  final String rsfHost;

  const QiniuRegion._({
    required super.code,
    required super.displayName,
    required super.uploadHost,
    required super.downloadHostSuffix,
    required this.rsHost,
    required this.rsfHost,
  });

  /// 华东-浙江（z0）- 默认区域
  static const z0 = QiniuRegion._(
    code: 'z0',
    displayName: '华东-浙江',
    uploadHost: 'https://upload.qiniup.com',
    downloadHostSuffix: '.z0.glb.clouddn.com',
    rsHost: 'https://rs.qbox.me',
    rsfHost: 'https://rsf.qbox.me',
  );

  /// 华东-浙江2（cn-east-2）
  static const cnEast2 = QiniuRegion._(
    code: 'cn-east-2',
    displayName: '华东-浙江2',
    uploadHost: 'https://upload-cn-east-2.qiniup.com',
    downloadHostSuffix: '.cn-east-2.qiniucs.com',
    rsHost: 'https://rs-cn-east-2.qiniuapi.com',
    rsfHost: 'https://rsf-cn-east-2.qiniuapi.com',
  );

  /// 华北-河北（z1）
  static const z1 = QiniuRegion._(
    code: 'z1',
    displayName: '华北-河北',
    uploadHost: 'https://upload-z1.qiniup.com',
    downloadHostSuffix: '.z1.glb.clouddn.com',
    rsHost: 'https://rs-z1.qbox.me',
    rsfHost: 'https://rsf-z1.qbox.me',
  );

  /// 华南-广东（z2）
  static const z2 = QiniuRegion._(
    code: 'z2',
    displayName: '华南-广东',
    uploadHost: 'https://upload-z2.qiniup.com',
    downloadHostSuffix: '.z2.glb.clouddn.com',
    rsHost: 'https://rs-z2.qbox.me',
    rsfHost: 'https://rsf-z2.qbox.me',
  );

  /// 北美-洛杉矶（na0）
  static const na0 = QiniuRegion._(
    code: 'na0',
    displayName: '北美-洛杉矶',
    uploadHost: 'https://upload-na0.qiniup.com',
    downloadHostSuffix: '.na0.glb.clouddn.com',
    rsHost: 'https://rs-na0.qbox.me',
    rsfHost: 'https://rsf-na0.qbox.me',
  );

  /// 亚太-新加坡（as0）
  static const as0 = QiniuRegion._(
    code: 'as0',
    displayName: '亚太-新加坡',
    uploadHost: 'https://upload-as0.qiniup.com',
    downloadHostSuffix: '.as0.glb.clouddn.com',
    rsHost: 'https://rs-as0.qbox.me',
    rsfHost: 'https://rsf-as0.qbox.me',
  );

  /// 所有可用区域
  static const List<QiniuRegion> allRegions = [z0, cnEast2, z1, z2, na0, as0];

  /// 根据代码获取区域
  static QiniuRegion? fromCode(String code) {
    for (final region in allRegions) {
      if (region.code == code) return region;
    }
    return null;
  }
}

/// 七牛云 OSS 客户端实现
class QiniuOssClient implements IOssClient {
  final String accessKey;
  final String secretKey;
  final String bucket;
  final QiniuRegion region;
  final String? customDomain;

  late final Storage _storage;
  final http.Client _httpClient = http.Client();

  QiniuOssClient({
    required this.accessKey,
    required this.secretKey,
    required this.bucket,
    required this.region,
    this.customDomain,
  }) {
    _storage = Storage();
  }

  @override
  OssVendor get vendor => OssVendor.qiniu;

  /// 生成上传 Token
  /// [key] 文件 key（可选，覆盖上传时需要指定）
  String _generateUploadToken(String? key) {
    // 构造上传策略
    final deadline = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    final putPolicy = <String, dynamic>{
      'scope': key != null ? '$bucket:$key' : bucket,
      'deadline': deadline,
      'insertOnly': 0, // 允许覆盖
    };

    // 对策略进行 Base64 编码
    final putPolicyJson = jsonEncode(putPolicy);
    final encodedPutPolicy = _urlSafeBase64Encode(utf8.encode(putPolicyJson));

    // 计算签名
    final sign = _hmacSha1Sign(encodedPutPolicy);
    final encodedSign = _urlSafeBase64Encode(sign);

    return '$accessKey:$encodedSign:$encodedPutPolicy';
  }

  /// 生成私有下载 URL
  /// 注意：URL 中包含时间戳参数 _t 用于绕过 CDN 缓存，确保每次请求获取最新内容
  ///
  /// 七牛云私有链接签名规则：
  /// 1. `token` 必须是 URL 的最后一个参数
  /// 2. `token` 之前的所有参数都必须参与签名计算
  /// 3. 签名格式：HMAC-SHA1(完整URL含所有非token参数)
  String _generatePrivateDownloadUrl(String key) {
    // 使用自定义域名或默认域名
    final domain = customDomain ?? 'http://$bucket${region.downloadHostSuffix}';
    final baseUrl = '$domain/$key';

    // 添加过期时间（1小时）
    final deadline = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    // 添加时间戳参数绕过 CDN 缓存（必须参与签名计算！）
    final cacheBuster = DateTime.now().millisecondsSinceEpoch;
    final urlWithParams = '$baseUrl?e=$deadline&_t=$cacheBuster';

    // 计算签名（包含所有参数：e 和 _t）
    final sign = _hmacSha1Sign(urlWithParams);
    final encodedSign = _urlSafeBase64Encode(sign);
    final token = '$accessKey:$encodedSign';

    // token 必须放在最后
    return '$urlWithParams&token=$token';
  }

  /// 生成管理凭证（用于 RS/RSF API）
  ///
  /// 七牛管理凭证签名格式（历史版本，仍在使用）：
  /// ```
  /// <PathWithQuery>\n
  /// [<Body>]
  /// ```
  ///
  /// 注意：七牛云实际使用的是旧版签名格式，而不是文档中描述的新版格式。
  /// 旧版格式只需要 path + 换行符 + body，不需要 Method 和 Host。
  ///
  /// @param path 请求路径（含 query，如 /list?bucket=xxx）
  /// @param body 请求体（可选）
  String _generateManagementToken(String path, String? body) {
    final signingStr = '$path\n${body ?? ''}';
    final sign = _hmacSha1Sign(signingStr);
    final encodedSign = _urlSafeBase64Encode(sign);
    return '$accessKey:$encodedSign';
  }

  /// HMAC-SHA1 签名
  List<int> _hmacSha1Sign(String data) {
    final key = utf8.encode(secretKey);
    final hmac = Hmac(sha1, key);
    return hmac.convert(utf8.encode(data)).bytes;
  }

  /// URL 安全的 Base64 编码
  String _urlSafeBase64Encode(List<int> data) {
    return base64Encode(data).replaceAll('+', '-').replaceAll('/', '_');
  }

  /// URL 安全的 Base64 编码（字符串版本）
  String _urlSafeBase64EncodeStr(String str) {
    return _urlSafeBase64Encode(utf8.encode(str));
  }

  @override
  Future<SyncResult<void>> testConnection() async {
    try {
      // 尝试列出 bucket 中的文件来验证凭证
      // 注意：
      // 1. 必须使用对应区域的 RSF Host，否则认证失败
      // 2. bucket 参数使用原始值，不需要 Base64 编码！
      final path = '/list?bucket=$bucket&limit=1';
      final token = _generateManagementToken(path, null);
      final fullUrl = '${region.rsfHost}$path';

      final response = await _httpClient.get(
        Uri.parse(fullUrl),
        headers: {'Authorization': 'QBox $token'},
      );

      if (response.statusCode == 200) {
        return const SyncResult.success(null);
      } else if (response.statusCode == 401) {
        return SyncResult.failure(
          'AK/SK 错误或权限不足: ${response.body}',
          SyncErrorType.authFailed,
        );
      } else if (response.statusCode == 631) {
        return const SyncResult.failure(
          'Bucket 不存在',
          SyncErrorType.invalidConfig,
        );
      } else {
        return SyncResult.failure(
          '连接失败: ${response.statusCode} ${response.body}',
          SyncErrorType.serverError,
        );
      }
    } catch (e) {
      return SyncResult.failure('网络错误: $e', SyncErrorType.networkError);
    }
  }

  @override
  Future<SyncResult<void>> uploadFile(String localPath, String remoteKey) async {
    try {
      final token = _generateUploadToken(remoteKey);
      final file = File(localPath);

      if (!await file.exists()) {
        return const SyncResult.failure('本地文件不存在', SyncErrorType.notFound);
      }

      final putController = PutController();

      await _storage.putFile(
        file,
        token,
        options: PutOptions(
          key: remoteKey,
          controller: putController,
        ),
      );

      return const SyncResult.success(null);
    } catch (e) {
      return SyncResult.failure('上传失败: $e', SyncErrorType.unknown);
    }
  }

  @override
  Future<SyncResult<void>> uploadBytes(List<int> data, String remoteKey) async {
    try {
      final token = _generateUploadToken(remoteKey);

      await _storage.putBytes(
        Uint8List.fromList(data),
        token,
        options: PutOptions(key: remoteKey),
      );

      return const SyncResult.success(null);
    } catch (e) {
      return SyncResult.failure('上传失败: $e', SyncErrorType.unknown);
    }
  }

  @override
  Future<SyncResult<bool>> downloadFile(String remoteKey, String localPath) async {
    try {
      // 先检查文件是否存在
      final existsResult = await fileExists(remoteKey);
      if (!existsResult.success) {
        return SyncResult.failure(existsResult.error!, existsResult.errorType);
      }
      if (existsResult.data == false) {
        return const SyncResult.success(false);
      }

      // 生成私有下载链接
      final downloadUrl = _generatePrivateDownloadUrl(remoteKey);
      final response = await _httpClient.get(Uri.parse(downloadUrl));

      if (response.statusCode == 200) {
        final file = File(localPath);
        await file.writeAsBytes(response.bodyBytes);
        return const SyncResult.success(true);
      } else if (response.statusCode == 404) {
        return const SyncResult.success(false);
      } else {
        return SyncResult.failure(
          '下载失败: ${response.statusCode}',
          SyncErrorType.serverError,
        );
      }
    } catch (e) {
      return SyncResult.failure('下载失败: $e', SyncErrorType.networkError);
    }
  }

  @override
  Future<SyncResult<List<int>?>> downloadBytes(String remoteKey) async {
    try {
      // 先检查文件是否存在
      final existsResult = await fileExists(remoteKey);
      if (!existsResult.success) {
        return SyncResult.failure(existsResult.error!, existsResult.errorType);
      }
      if (existsResult.data == false) {
        return const SyncResult.success(null);
      }

      // 生成私有下载链接
      final downloadUrl = _generatePrivateDownloadUrl(remoteKey);
      final response = await _httpClient.get(Uri.parse(downloadUrl));

      if (response.statusCode == 200) {
        return SyncResult.success(response.bodyBytes);
      } else if (response.statusCode == 404) {
        return const SyncResult.success(null);
      } else {
        return SyncResult.failure(
          '下载失败: ${response.statusCode}',
          SyncErrorType.serverError,
        );
      }
    } catch (e) {
      return SyncResult.failure('下载失败: $e', SyncErrorType.networkError);
    }
  }

  @override
  Future<SyncResult<bool>> fileExists(String remoteKey) async {
    try {
      // 使用 stat API 检查文件是否存在
      final entry = '$bucket:$remoteKey';
      final encodedEntry = _urlSafeBase64EncodeStr(entry);
      final path = '/stat/$encodedEntry';
      final token = _generateManagementToken(path, null);

      final response = await _httpClient.get(
        Uri.parse('${region.rsHost}$path'),
        headers: {'Authorization': 'QBox $token'},
      );

      if (response.statusCode == 200) {
        return const SyncResult.success(true);
      } else if (response.statusCode == 612) {
        // 612: 文件不存在
        return const SyncResult.success(false);
      } else {
        return SyncResult.failure(
          '检查文件存在失败: ${response.statusCode}',
          SyncErrorType.serverError,
        );
      }
    } catch (e) {
      return SyncResult.failure('检查文件存在失败: $e', SyncErrorType.networkError);
    }
  }

  @override
  Future<SyncResult<void>> deleteFile(String remoteKey) async {
    try {
      final entry = '$bucket:$remoteKey';
      final encodedEntry = _urlSafeBase64EncodeStr(entry);
      final path = '/delete/$encodedEntry';
      final token = _generateManagementToken(path, null);

      final response = await _httpClient.post(
        Uri.parse('${region.rsHost}$path'),
        headers: {'Authorization': 'QBox $token'},
      );

      if (response.statusCode == 200 || response.statusCode == 612) {
        // 200: 删除成功, 612: 文件不存在（也算成功）
        return const SyncResult.success(null);
      } else {
        return SyncResult.failure(
          '删除失败: ${response.statusCode}',
          SyncErrorType.serverError,
        );
      }
    } catch (e) {
      return SyncResult.failure('删除失败: $e', SyncErrorType.networkError);
    }
  }

  @override
  Future<SyncResult<List<String>>> listFiles(String prefix) async {
    try {
      // 注意：bucket 和 prefix 参数使用原始值，不需要 Base64 编码！
      // 但 prefix 如果包含特殊字符需要 URL 编码
      final encodedPrefix = Uri.encodeComponent(prefix);
      final path = '/list?bucket=$bucket&prefix=$encodedPrefix&limit=1000';
      final token = _generateManagementToken(path, null);

      final response = await _httpClient.get(
        Uri.parse('${region.rsfHost}$path'),
        headers: {'Authorization': 'QBox $token'},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final items = json['items'] as List<dynamic>? ?? [];
        final files = items.map((item) => item['key'] as String).toList();
        return SyncResult.success(files);
      } else {
        return SyncResult.failure(
          '列出文件失败: ${response.statusCode}',
          SyncErrorType.serverError,
        );
      }
    } catch (e) {
      return SyncResult.failure('列出文件失败: $e', SyncErrorType.networkError);
    }
  }

  @override
  void dispose() {
    _httpClient.close();
  }
}
