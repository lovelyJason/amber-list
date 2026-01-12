import 'package:flutter/services.dart';

import '../security/aes_cipher.dart';
import 'resource_provider.dart';

/// 加密资源提供者
///
/// 从 Flutter assets 加载 AES 加密的资源文件，并自动解密
/// 用于保护敏感资源（图片、音效、皮肤等）
///
/// 工作流程：
/// 1. 构建时：使用加密脚本将 assets/ 下的资源加密到 assets_enc/
/// 2. 运行时：从 assets_enc/ 加载加密文件，自动解密后返回
///
/// 文件格式：
/// - 加密文件以 .enc 为后缀
/// - 文件头部包含 "AMBR" magic header
/// - 使用 AES-256-CBC 加密
class EncryptedResourceProvider implements ResourceProvider {
  /// AES 加解密工具
  final AesCipher _cipher;

  /// 加密资源基础路径
  final String _basePath;

  /// 创建加密资源提供者
  ///
  /// [cipher] AES 加解密工具，如果不传则使用默认密钥
  /// [basePath] 加密资源基础路径，默认为 'assets_enc/'
  EncryptedResourceProvider({
    AesCipher? cipher,
    String basePath = 'assets_enc/',
  })  : _cipher = cipher ?? AesCipher.withDefaultKey(),
        _basePath = basePath;

  @override
  Future<ResourceResult?> load(String path) async {
    try {
      // 加密文件路径：原路径 + .enc 后缀
      final encryptedPath = '$_basePath$path.enc';

      // 加载加密数据
      final encryptedData = await rootBundle.load(encryptedPath);
      final encryptedBytes = encryptedData.buffer.asUint8List();

      // 解密
      final decryptedData = _cipher.decrypt(encryptedBytes);
      if (decryptedData == null) {
        // 解密失败（可能不是加密文件或密钥错误）
        return null;
      }

      return ResourceResult(
        data: decryptedData,
        source: ResourceSource.encrypted,
      );
    } catch (e) {
      // 加密文件不存在或加载失败
      return null;
    }
  }

  @override
  Future<bool> exists(String path) async {
    try {
      final encryptedPath = '$_basePath$path.enc';
      await rootBundle.load(encryptedPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  int get priority => 10; // 高优先级，优先使用加密资源

  @override
  String get name => 'EncryptedResourceProvider';
}
