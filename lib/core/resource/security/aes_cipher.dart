import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';

/// AES-256-CBC 加解密工具
///
/// 用于资源文件的加密保护，特点：
/// - 使用 AES-256-CBC 算法，安全性高
/// - 支持任意二进制数据加解密
/// - 密钥通过混淆方式存储，增加逆向难度
///
/// 安全说明：
/// - 此方案可防止普通用户直接提取资源
/// - 无法阻止专业逆向工程师（密钥最终在本地）
/// - 核心目的是增加资源盗用的成本
class AesCipher {
  /// AES 加密器
  late final Encrypter _encrypter;

  /// 初始化向量
  late final IV _iv;

  /// 私有构造函数
  AesCipher._({required Key key, required IV iv}) {
    _encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    _iv = iv;
  }

  /// 创建默认加密器（使用内置密钥）
  ///
  /// 密钥通过简单混淆存储，增加逆向难度
  /// 注意：这不是绝对安全，但足以阻止普通用户
  factory AesCipher.withDefaultKey() {
    // 密钥混淆：将密钥拆分存储，运行时拼接
    // 32 字节密钥 for AES-256
    final keyParts = [
      [0x41, 0x6D, 0x62, 0x65, 0x72, 0x4C, 0x69, 0x73], // "AmberLis"
      [0x74, 0x53, 0x65, 0x63, 0x75, 0x72, 0x65, 0x4B], // "tSecureK"
      [0x65, 0x79, 0x32, 0x30, 0x32, 0x36, 0x21, 0x40], // "ey2026!@"
      [0x23, 0x24, 0x25, 0x5E, 0x26, 0x2A, 0x28, 0x29], // "#\$%^&*()"
    ];

    // IV 混淆：16 字节
    final ivParts = [
      [0x41, 0x6D, 0x62, 0x65, 0x72, 0x49, 0x56, 0x32], // "AmberIV2"
      [0x30, 0x32, 0x36, 0x53, 0x65, 0x63, 0x21, 0x40], // "026Sec!@"
    ];

    // 运行时拼接密钥
    final keyBytes = <int>[];
    for (final part in keyParts) {
      keyBytes.addAll(part);
    }

    final ivBytes = <int>[];
    for (final part in ivParts) {
      ivBytes.addAll(part);
    }

    return AesCipher._(
      key: Key(Uint8List.fromList(keyBytes)),
      iv: IV(Uint8List.fromList(ivBytes)),
    );
  }

  /// 使用自定义密钥创建加密器
  ///
  /// [keyString] 32 字符的密钥字符串
  /// [ivString] 16 字符的 IV 字符串
  factory AesCipher.withCustomKey({
    required String keyString,
    required String ivString,
  }) {
    if (keyString.length != 32) {
      throw ArgumentError('密钥必须是 32 字符（AES-256）');
    }
    if (ivString.length != 16) {
      throw ArgumentError('IV 必须是 16 字符');
    }

    return AesCipher._(
      key: Key.fromUtf8(keyString),
      iv: IV.fromUtf8(ivString),
    );
  }

  /// 加密数据
  ///
  /// [data] 原始二进制数据
  /// 返回加密后的数据（包含 magic header）
  Uint8List encrypt(Uint8List data) {
    final encrypted = _encrypter.encryptBytes(data, iv: _iv);

    // 添加 magic header 用于识别加密文件
    // "AMBR" + version(1 byte) + reserved(3 bytes) = 8 bytes header
    final header = Uint8List.fromList([
      0x41, 0x4D, 0x42, 0x52, // "AMBR"
      0x01, // version 1
      0x00, 0x00, 0x00, // reserved
    ]);

    // 合并 header 和加密数据
    final result = Uint8List(header.length + encrypted.bytes.length);
    result.setAll(0, header);
    result.setAll(header.length, encrypted.bytes);

    return result;
  }

  /// 解密数据
  ///
  /// [encryptedData] 加密后的二进制数据（含 magic header）
  /// 返回解密后的原始数据，如果数据无效返回 null
  Uint8List? decrypt(Uint8List encryptedData) {
    // 检查最小长度（8 bytes header + 至少 16 bytes 数据）
    if (encryptedData.length < 24) {
      return null;
    }

    // 验证 magic header
    if (encryptedData[0] != 0x41 ||
        encryptedData[1] != 0x4D ||
        encryptedData[2] != 0x42 ||
        encryptedData[3] != 0x52) {
      // 不是加密文件，返回 null
      return null;
    }

    // 检查版本
    final version = encryptedData[4];
    if (version != 0x01) {
      // 不支持的版本
      return null;
    }

    try {
      // 提取加密数据（跳过 8 bytes header）
      final cipherData = encryptedData.sublist(8);
      final encrypted = Encrypted(cipherData);

      // 解密
      final decrypted = _encrypter.decryptBytes(encrypted, iv: _iv);
      return Uint8List.fromList(decrypted);
    } catch (e) {
      // 解密失败
      return null;
    }
  }

  /// 检查数据是否为加密格式
  ///
  /// [data] 待检查的数据
  /// 通过 magic header 判断是否为本工具加密的数据
  static bool isEncrypted(Uint8List data) {
    if (data.length < 8) return false;
    return data[0] == 0x41 && // 'A'
        data[1] == 0x4D && // 'M'
        data[2] == 0x42 && // 'B'
        data[3] == 0x52; // 'R'
  }
}
