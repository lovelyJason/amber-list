import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../../../env/env.dart';

/// ============================================================
/// HMAC 签名工具
/// ============================================================
/// 用于生成激活码验证接口的签名
/// 签名算法：HMAC-SHA256
/// 签名内容：timestamp + code + secretKey
/// ============================================================
class HmacSigner {
  /// 生成 HMAC-SHA256 签名
  ///
  /// [timestamp] 时间戳（毫秒）
  /// [code] 激活码
  /// 返回十六进制签名字符串
  static String sign(String timestamp, String code) {
    final secretKey = Env.hmacSecretKey;
    final message = '$timestamp$code$secretKey';

    // 创建 HMAC-SHA256 实例
    final hmac = Hmac(sha256, utf8.encode(secretKey));

    // 计算签名
    final digest = hmac.convert(utf8.encode(message));

    // 返回十六进制字符串
    return digest.toString();
  }

  /// 生成带签名的请求头
  ///
  /// [code] 激活码
  /// 返回包含 X-Timestamp 和 X-Signature 的 Map
  static Map<String, String> generateHeaders(String code) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final signature = sign(timestamp, code);

    return {
      'X-Timestamp': timestamp,
      'X-Signature': signature,
    };
  }
}
