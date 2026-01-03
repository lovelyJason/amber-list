import 'package:envied/envied.dart';

part 'env.g.dart';

/// 密钥存储类型枚举
enum SecretStorageType {
  /// 系统钥匙串存储（macOS Keychain / Windows Credential Manager）
  /// 更安全，推荐用于生产环境
  keychain,

  /// SharedPreferences 存储
  /// 方便调试，但安全性较低
  sharedPreferences,
}

/// 编译时环境配置
///
/// 使用 envied 在编译时将 .env 文件的值注入到代码中
/// 比运行时加载更安全，且有类型检查
///
/// 使用方法：
/// ```dart
/// if (Env.secretStorageType == SecretStorageType.keychain) {
///   // 使用钥匙串存储
/// }
/// ```
@Envied(path: '.env')
abstract class Env {
  /// 密钥存储方式的原始字符串值
  /// 可选值：keychain, shared_preferences
  @EnviedField(varName: 'SECRET_STORAGE_TYPE')
  static const String _secretStorageTypeRaw = _Env._secretStorageTypeRaw;

  /// 密钥存储方式（类型安全的枚举）
  static SecretStorageType get secretStorageType {
    switch (_secretStorageTypeRaw.toLowerCase()) {
      case 'shared_preferences':
        return SecretStorageType.sharedPreferences;
      case 'keychain':
      default:
        return SecretStorageType.keychain;
    }
  }

  /// 是否使用系统钥匙串存储
  static bool get useKeychain =>
      secretStorageType == SecretStorageType.keychain;

  /// 是否使用 SharedPreferences 存储
  static bool get useSharedPreferences =>
      secretStorageType == SecretStorageType.sharedPreferences;
}
