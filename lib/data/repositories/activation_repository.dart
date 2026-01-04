import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../env/env.dart';
import '../models/activation_code.dart';
import '../services/activation/hmac_signer.dart';

/// ============================================================
/// API 调用结果
/// ============================================================
class ApiResult<T> {
  final bool success;
  final String? message;
  final T? data;

  const ApiResult({
    required this.success,
    this.message,
    this.data,
  });

  factory ApiResult.success(T data, {String? message}) {
    return ApiResult(success: true, data: data, message: message);
  }

  factory ApiResult.failure(String message) {
    return ApiResult(success: false, message: message);
  }
}

/// ============================================================
/// 激活码网络请求仓库
/// ============================================================
/// 负责与后端激活码接口通信
/// 使用 HMAC 签名进行认证
/// ============================================================
class ActivationRepository {
  final http.Client _client;
  final String _baseUrl;

  ActivationRepository({http.Client? client})
      : _client = client ?? http.Client(),
        _baseUrl = Env.activationApiUrl;

  /// 校验激活码
  ///
  /// [code] 激活码
  /// 返回校验结果
  Future<ApiResult<ActivationCode>> verify(String code) async {
    try {
      final url = '$_baseUrl/hupo/activation-code/verify';

      // 生成签名请求头
      final signHeaders = HmacSigner.generateHeaders(code);

      debugPrint('[ActivationRepository] 发起校验请求: $url');

      final response = await _client
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              ...signHeaders,
            },
            body: jsonEncode({'code': code}),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('[ActivationRepository] 响应状态码: ${response.statusCode}');

      // 解析响应
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final responseCode = json['code'] as int?;
      final message = json['message'] as String?;

      if (response.statusCode == 200 && responseCode == 0) {
        // 成功
        final data = json['data'] as Map<String, dynamic>?;
        if (data != null) {
          final activationCode = ActivationCode.fromJson(data);
          debugPrint('[ActivationRepository] ✅ 校验成功: ${activationCode.code}');
          return ApiResult.success(activationCode, message: message);
        } else {
          return ApiResult.failure(message ?? '响应数据为空');
        }
      } else if (response.statusCode == 401) {
        // 签名错误
        return ApiResult.failure(message ?? '签名验证失败，请检查设备时间');
      } else if (response.statusCode == 429) {
        // 限流
        return ApiResult.failure('请求过于频繁，请稍后再试');
      } else {
        // 其他错误
        return ApiResult.failure(message ?? '校验失败');
      }
    } on SocketException catch (e) {
      debugPrint('[ActivationRepository] 网络异常: $e');
      return ApiResult.failure('网络连接失败，请检查网络');
    } on http.ClientException catch (e) {
      debugPrint('[ActivationRepository] HTTP 异常: $e');
      return ApiResult.failure('网络请求失败');
    } on FormatException catch (e) {
      debugPrint('[ActivationRepository] 响应格式错误: $e');
      return ApiResult.failure('服务器响应格式错误');
    } catch (e) {
      debugPrint('[ActivationRepository] 未知异常: $e');
      return ApiResult.failure('激活失败: $e');
    }
  }

  /// 释放资源
  void dispose() {
    _client.close();
  }
}
