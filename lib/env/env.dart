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

/// 便签窗口渲染模式位标志
/// 使用位运算控制各平台是否使用原生渲染
class StickyNoteNativeFlags {
  /// Bit 0: macOS 使用原生 AppKit 渲染
  static const int macOS = 1 << 0; // 1

  /// Bit 1: Windows 使用原生 Win32/GDI+ 渲染
  static const int windows = 1 << 1; // 2

  /// 所有平台都使用原生渲染
  static const int all = macOS | windows; // 3

  /// 所有平台都使用 Flutter 渲染
  static const int none = 0;
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

  /// 应用更新检查 API 地址
  /// 可以是 GitHub Raw、CDN、自建服务器等
  @EnviedField(varName: 'APP_UPDATE_URL')
  static const String appUpdateUrl = _Env.appUpdateUrl;

  /// 激活码验证 API 地址
  @EnviedField(varName: 'ACTIVATION_API_URL')
  static const String activationApiUrl = _Env.activationApiUrl;

  /// HMAC 签名密钥
  /// 用于激活码验证接口的签名
  @EnviedField(varName: 'HUPO_HMAC_SECRET_KEY', obfuscate: true)
  static String hmacSecretKey = _Env.hmacSecretKey;

  // ============================================================
  // 便签窗口渲染模式配置
  // ============================================================

  /// 便签原生渲染模式位标志（原始整数值）
  ///
  /// 位标志含义：
  /// - Bit 0 (值1): macOS 使用原生 AppKit 渲染
  /// - Bit 1 (值2): Windows 使用原生 Win32/GDI+ 渲染
  ///
  /// 常用组合：
  /// - 0: 所有平台使用 Flutter 渲染
  /// - 1: 仅 macOS 使用原生（推荐，Windows GDI+ 效果一般）
  /// - 2: 仅 Windows 使用原生
  /// - 3: 所有平台使用原生渲染
  @EnviedField(varName: 'STICKY_NOTE_NATIVE_MODE', defaultValue: '1')
  static const String _stickyNoteNativeModeRaw = _Env._stickyNoteNativeModeRaw;

  /// 便签原生渲染模式位标志（解析后的整数）
  static int get stickyNoteNativeMode {
    return int.tryParse(_stickyNoteNativeModeRaw) ?? 1;
  }

  /// 检查当前平台是否应使用原生便签渲染
  ///
  /// 根据 STICKY_NOTE_NATIVE_MODE 环境变量和当前运行平台判断
  /// 返回 true 表示使用原生渲染，false 表示使用 Flutter 渲染
  static bool get shouldUseNativeStickyNote {
    // 延迟导入，避免在 env.dart 中引入 dart:io 依赖
    // 实际判断逻辑在调用侧处理
    return true; // 占位，实际判断在 StickyNoteRenderMode
  }

  /// macOS 是否使用原生便签
  static bool get macOSUseNativeStickyNote {
    return (stickyNoteNativeMode & StickyNoteNativeFlags.macOS) != 0;
  }

  /// Windows 是否使用原生便签
  static bool get windowsUseNativeStickyNote {
    return (stickyNoteNativeMode & StickyNoteNativeFlags.windows) != 0;
  }
}
