import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../env/env.dart';
import '../models/amber_cloud_token.dart';
import '../services/activation/hmac_signer.dart';
import '../services/device/device_id_service.dart';

/// ============================================================
/// 琥珀云同步 API 仓库
/// ============================================================
/// 负责与琥珀云服务端通信：
/// - Token 管理（获取、刷新、存储）
/// - 文件操作（上传、下载、删除）
///
/// 认证机制：
/// - 首次获取 Token：使用激活码 + HMAC 签名
/// - 后续 API 调用：使用 Bearer Token
/// ============================================================
class AmberCloudRepository {
  final http.Client _client;
  final String _baseUrl;

  /// Token 本地存储 key
  static const _tokenStorageKey = 'amber_cloud_token';

  /// 当前缓存的 Token（避免每次都读取 SharedPreferences）
  AmberCloudToken? _cachedToken;

  /// 正在进行的刷新操作（用于避免并发刷新）
  Future<AmberCloudApiResult<AmberCloudToken>>? _refreshingFuture;

  AmberCloudRepository({http.Client? client})
      : _client = client ?? http.Client(),
        _baseUrl = Env.activationApiUrl;

  // ============================================================
  // Token 管理
  // ============================================================

  /// 获取新的 Token（使用激活码）
  ///
  /// [activationCode] 激活码
  /// 返回 Token 对，同时缓存到本地
  Future<AmberCloudApiResult<AmberCloudToken>> getToken(
    String activationCode,
  ) async {
    try {
      final url = '$_baseUrl/hupo/sync/token';
      final deviceId = await DeviceIdService().getDeviceId();
      final signHeaders = HmacSigner.generateHeaders(activationCode);

      debugPrint('[AmberCloud] 获取 Token: $url');

      final response = await _client
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              ...signHeaders,
            },
            body: jsonEncode({
              'code': activationCode,
              'deviceId': deviceId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      return _handleTokenResponse(response);
    } on SocketException catch (e) {
      debugPrint('[AmberCloud] 网络异常: $e');
      return AmberCloudApiResult.failure('网络连接失败，请检查网络');
    } on http.ClientException catch (e) {
      debugPrint('[AmberCloud] HTTP 异常: $e');
      return AmberCloudApiResult.failure('网络请求失败');
    } catch (e) {
      debugPrint('[AmberCloud] 获取 Token 失败: $e');
      return AmberCloudApiResult.failure('获取 Token 失败: $e');
    }
  }

  /// 刷新 Access Token
  ///
  /// 使用 Refresh Token 获取新的 Access Token
  Future<AmberCloudApiResult<AmberCloudToken>> refreshToken() async {
    try {
      final token = await _getStoredToken();
      if (token == null) {
        return AmberCloudApiResult.failure('Token 不存在');
      }

      if (token.isRefreshTokenExpired) {
        await clearToken();
        return AmberCloudApiResult.failure(
          'Refresh Token 已过期，请重新登录',
          isAuthError: true,
        );
      }

      final url = '$_baseUrl/hupo/sync/token/refresh';

      debugPrint('[AmberCloud] 刷新 Token: $url');

      final response = await _client
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': token.refreshToken}),
          )
          .timeout(const Duration(seconds: 15));

      return _handleTokenResponse(response);
    } on SocketException catch (e) {
      debugPrint('[AmberCloud] 刷新 Token 网络异常: $e');
      return AmberCloudApiResult.failure('网络连接失败');
    } catch (e) {
      debugPrint('[AmberCloud] 刷新 Token 失败: $e');
      return AmberCloudApiResult.failure('刷新 Token 失败: $e');
    }
  }

  /// 处理 Token 响应
  Future<AmberCloudApiResult<AmberCloudToken>> _handleTokenResponse(
    http.Response response,
  ) async {
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final code = json['code'] as int?;
    final message = json['message'] as String?;

    if (response.statusCode == 200 && code == 0) {
      final data = json['data'] as Map<String, dynamic>?;
      if (data != null) {
        final token = AmberCloudToken(
          accessToken: data['accessToken'] as String,
          accessTokenExpiresAt:
              DateTime.parse(data['accessTokenExpiresAt'] as String),
          refreshToken: data['refreshToken'] as String,
          refreshTokenExpiresAt:
              DateTime.parse(data['refreshTokenExpiresAt'] as String),
          createdAt: DateTime.now(),
        );

        // 缓存 Token
        await _storeToken(token);
        _cachedToken = token;

        debugPrint('[AmberCloud] ✅ Token 获取成功');
        return AmberCloudApiResult.success(token, message: message);
      }
    }

    if (response.statusCode == 401) {
      return AmberCloudApiResult.failure(
        message ?? '认证失败',
        isAuthError: true,
      );
    }

    return AmberCloudApiResult.failure(message ?? 'Token 获取失败');
  }

  /// 获取有效的 Access Token
  ///
  /// 自动处理 Token 刷新逻辑：
  /// - Token 未过期：直接返回
  /// - Access Token 过期：自动刷新
  /// - Refresh Token 过期：返回错误
  ///
  /// 并发安全：使用 _refreshingFuture 避免多个请求同时刷新 Token
  Future<AmberCloudApiResult<String>> getValidAccessToken() async {
    var token = await _getStoredToken();

    if (token == null) {
      return AmberCloudApiResult.failure(
        'Token 不存在，请重新登录',
        isAuthError: true,
      );
    }

    // Refresh Token 过期
    if (token.isRefreshTokenExpired) {
      await clearToken();
      return AmberCloudApiResult.failure(
        'Token 已过期，请重新登录',
        isAuthError: true,
      );
    }

    // Access Token 过期，需要刷新
    if (token.isAccessTokenExpired) {
      debugPrint('[AmberCloud] Access Token 已过期，正在刷新...');

      // 如果已有刷新操作在进行，等待其完成
      if (_refreshingFuture != null) {
        debugPrint('[AmberCloud] 等待其他刷新操作完成...');
        final refreshResult = await _refreshingFuture!;
        if (!refreshResult.success) {
          return AmberCloudApiResult.failure(
            refreshResult.message ?? '刷新 Token 失败',
            isAuthError: refreshResult.isAuthError,
          );
        }
        token = refreshResult.data;
      } else {
        // 发起新的刷新操作
        _refreshingFuture = refreshToken();
        try {
          final refreshResult = await _refreshingFuture!;
          if (!refreshResult.success) {
            return AmberCloudApiResult.failure(
              refreshResult.message ?? '刷新 Token 失败',
              isAuthError: refreshResult.isAuthError,
            );
          }
          token = refreshResult.data;
        } finally {
          _refreshingFuture = null;
        }
      }
    }

    return AmberCloudApiResult.success(token!.accessToken);
  }

  /// 存储 Token 到本地
  Future<void> _storeToken(AmberCloudToken token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenStorageKey, jsonEncode(token.toJson()));
    _cachedToken = token;
  }

  /// 从本地获取 Token
  Future<AmberCloudToken?> _getStoredToken() async {
    if (_cachedToken != null) {
      return _cachedToken;
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_tokenStorageKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return null;
    }

    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      _cachedToken = AmberCloudToken.fromJson(json);
      return _cachedToken;
    } catch (e) {
      debugPrint('[AmberCloud] Token 解析失败: $e');
      return null;
    }
  }

  /// 清除本地 Token
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenStorageKey);
    _cachedToken = null;
    debugPrint('[AmberCloud] Token 已清除');
  }

  /// 检查是否已登录（有有效 Token）
  Future<bool> isLoggedIn() async {
    final token = await _getStoredToken();
    return token != null && !token.isRefreshTokenExpired;
  }

  // ============================================================
  // 文件操作
  // ============================================================

  /// 上传文件
  ///
  /// [filename] 文件名
  /// [content] 文件内容
  Future<AmberCloudApiResult<void>> uploadFile(
    String filename,
    Uint8List content,
  ) async {
    final tokenResult = await getValidAccessToken();
    if (!tokenResult.success) {
      return AmberCloudApiResult.failure(
        tokenResult.message ?? '认证失败',
        isAuthError: tokenResult.isAuthError,
      );
    }

    try {
      final url = '$_baseUrl/hupo/sync/upload';
      final uri = Uri.parse(url);

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer ${tokenResult.data}';
      request.fields['filename'] = filename;
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        content,
        filename: filename,
      ));

      debugPrint('[AmberCloud] 上传文件: $filename, size=${content.length}');

      final streamedResponse =
          await request.send().timeout(const Duration(minutes: 5));
      final response = await http.Response.fromStream(streamedResponse);

      return _handleApiResponse<void>(response, null);
    } catch (e) {
      debugPrint('[AmberCloud] 上传文件失败: $e');
      return AmberCloudApiResult.failure('上传失败: $e');
    }
  }

  /// 下载文件
  ///
  /// [filename] 文件名
  /// 返回文件内容
  Future<AmberCloudApiResult<Uint8List>> downloadFile(String filename) async {
    final tokenResult = await getValidAccessToken();
    if (!tokenResult.success) {
      return AmberCloudApiResult.failure(
        tokenResult.message ?? '认证失败',
        isAuthError: tokenResult.isAuthError,
      );
    }

    try {
      final url =
          '$_baseUrl/hupo/sync/download?filename=${Uri.encodeComponent(filename)}';

      debugPrint('[AmberCloud] 下载文件: $filename');

      final response = await _client
          .get(
            Uri.parse(url),
            headers: {'Authorization': 'Bearer ${tokenResult.data}'},
          )
          .timeout(const Duration(minutes: 5));

      if (response.statusCode == 200) {
        debugPrint(
            '[AmberCloud] ✅ 下载成功: $filename, size=${response.bodyBytes.length}');
        return AmberCloudApiResult.success(response.bodyBytes);
      } else if (response.statusCode == 404) {
        return AmberCloudApiResult.failure('文件不存在', isNotFound: true);
      } else if (response.statusCode == 401) {
        return AmberCloudApiResult.failure('认证失败', isAuthError: true);
      } else {
        return AmberCloudApiResult.failure('下载失败: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[AmberCloud] 下载文件失败: $e');
      return AmberCloudApiResult.failure('下载失败: $e');
    }
  }

  /// 获取文件元数据
  Future<AmberCloudApiResult<Map<String, dynamic>>> getMetadata(
    String filename,
  ) async {
    final tokenResult = await getValidAccessToken();
    if (!tokenResult.success) {
      return AmberCloudApiResult.failure(
        tokenResult.message ?? '认证失败',
        isAuthError: tokenResult.isAuthError,
      );
    }

    try {
      final url =
          '$_baseUrl/hupo/sync/metadata?filename=${Uri.encodeComponent(filename)}';

      final response = await _client
          .get(
            Uri.parse(url),
            headers: {'Authorization': 'Bearer ${tokenResult.data}'},
          )
          .timeout(const Duration(seconds: 15));

      return _handleApiResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[AmberCloud] 获取元数据失败: $e');
      return AmberCloudApiResult.failure('获取元数据失败: $e');
    }
  }

  /// 列出所有文件
  Future<AmberCloudApiResult<List<Map<String, dynamic>>>> listFiles() async {
    final tokenResult = await getValidAccessToken();
    if (!tokenResult.success) {
      return AmberCloudApiResult.failure(
        tokenResult.message ?? '认证失败',
        isAuthError: tokenResult.isAuthError,
      );
    }

    try {
      final url = '$_baseUrl/hupo/sync/files';

      final response = await _client
          .get(
            Uri.parse(url),
            headers: {'Authorization': 'Bearer ${tokenResult.data}'},
          )
          .timeout(const Duration(seconds: 15));

      return _handleApiResponse<List<Map<String, dynamic>>>(
        response,
        (data) => (data as List).cast<Map<String, dynamic>>(),
      );
    } catch (e) {
      debugPrint('[AmberCloud] 列出文件失败: $e');
      return AmberCloudApiResult.failure('列出文件失败: $e');
    }
  }

  /// 删除文件
  Future<AmberCloudApiResult<void>> deleteFile(String filename) async {
    final tokenResult = await getValidAccessToken();
    if (!tokenResult.success) {
      return AmberCloudApiResult.failure(
        tokenResult.message ?? '认证失败',
        isAuthError: tokenResult.isAuthError,
      );
    }

    try {
      final url = '$_baseUrl/hupo/sync/delete';

      final response = await _client
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${tokenResult.data}',
            },
            body: jsonEncode({'filename': filename}),
          )
          .timeout(const Duration(seconds: 15));

      return _handleApiResponse<void>(response, null);
    } catch (e) {
      debugPrint('[AmberCloud] 删除文件失败: $e');
      return AmberCloudApiResult.failure('删除失败: $e');
    }
  }

  /// 处理 API 响应
  AmberCloudApiResult<T> _handleApiResponse<T>(
    http.Response response,
    T Function(dynamic)? dataParser,
  ) {
    if (response.statusCode == 401) {
      return AmberCloudApiResult.failure('认证失败', isAuthError: true);
    }

    if (response.statusCode == 404) {
      return AmberCloudApiResult.failure('资源不存在', isNotFound: true);
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final code = json['code'] as int?;
      final message = json['message'] as String?;

      if (response.statusCode == 200 && code == 0) {
        if (dataParser != null && json['data'] != null) {
          return AmberCloudApiResult.success(
            dataParser(json['data']),
            message: message,
          );
        }
        return AmberCloudApiResult.success(null as T, message: message);
      }

      return AmberCloudApiResult.failure(message ?? '请求失败');
    } catch (e) {
      return AmberCloudApiResult.failure('响应解析失败: $e');
    }
  }

  /// 测试连接
  Future<AmberCloudApiResult<void>> testConnection() async {
    final tokenResult = await getValidAccessToken();
    if (!tokenResult.success) {
      return AmberCloudApiResult.failure(
        tokenResult.message ?? '认证失败',
        isAuthError: tokenResult.isAuthError,
      );
    }

    try {
      final url = '$_baseUrl/hupo/sync/health';

      final response = await _client
          .get(
            Uri.parse(url),
            headers: {'Authorization': 'Bearer ${tokenResult.data}'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return AmberCloudApiResult.success(null);
      }
      return AmberCloudApiResult.failure('连接测试失败: ${response.statusCode}');
    } catch (e) {
      return AmberCloudApiResult.failure('连接失败: $e');
    }
  }

  /// 释放资源
  void dispose() {
    _client.close();
  }
}

/// 琥珀云 API 调用结果
class AmberCloudApiResult<T> {
  final bool success;
  final String? message;
  final T? data;

  /// 是否是认证错误（需要重新登录）
  final bool isAuthError;

  /// 是否是资源不存在
  final bool isNotFound;

  const AmberCloudApiResult({
    required this.success,
    this.message,
    this.data,
    this.isAuthError = false,
    this.isNotFound = false,
  });

  factory AmberCloudApiResult.success(T data, {String? message}) {
    return AmberCloudApiResult(success: true, data: data, message: message);
  }

  factory AmberCloudApiResult.failure(
    String message, {
    bool isAuthError = false,
    bool isNotFound = false,
  }) {
    return AmberCloudApiResult(
      success: false,
      message: message,
      isAuthError: isAuthError,
      isNotFound: isNotFound,
    );
  }
}
