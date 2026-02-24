import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// 设备ID服务
///
/// 获取硬件级别的设备唯一标识符，用于激活码设备绑定。
///
/// 设计原则：
/// 1. 唯一性：每个物理设备生成唯一ID
/// 2. 持久性：卸载/重装应用后ID不变（硬件级别）
/// 3. 隐私保护：对原始硬件信息进行哈希处理
///
/// 各平台实现：
/// - macOS: IOPlatformUUID（系统硬件UUID）
/// - Windows: MachineGuid（注册表机器标识）
/// - Android: ANDROID_ID + 硬件指纹
/// - iOS: identifierForVendor（同开发者应用共享）
class DeviceIdService {
  /// 单例实例
  static final DeviceIdService _instance = DeviceIdService._internal();
  factory DeviceIdService() => _instance;
  DeviceIdService._internal();

  /// 设备信息插件
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// 缓存的设备ID（避免重复计算）
  String? _cachedDeviceId;

  /// SharedPreferences key for fallback device ID
  static const _fallbackDeviceIdKey = 'amber_device_fallback_id';

  /// 获取设备唯一标识符
  ///
  /// 返回格式：`AMBER-{platform}-{hash}`
  /// 示例：`AMBER-macos-a1b2c3d4e5f6`
  ///
  /// 如果之前使用了降级ID（fallback），会自动尝试重新获取硬件ID。
  Future<String> getDeviceId() async {
    // 使用缓存（但如果是 fallback ID 则尝试重新获取）
    if (_cachedDeviceId != null) {
      // 检查是否为降级ID，如果是则尝试升级到硬件ID
      if (_cachedDeviceId!.contains('fallback') || _cachedDeviceId!.contains('temp')) {
        debugPrint('[DeviceIdService] 检测到降级ID: $_cachedDeviceId，尝试重新获取硬件ID...');
        final hardwareId = await _tryGetHardwareId();
        if (hardwareId != null) {
          debugPrint('[DeviceIdService] ✅ 成功获取硬件ID，替换降级ID');
          // 清除旧的降级ID
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(_fallbackDeviceIdKey);
          } catch (_) {}
          _cachedDeviceId = hardwareId;
          return _cachedDeviceId!;
        }
      }
      // debugPrint('[DeviceIdService] 使用缓存的设备ID: $_cachedDeviceId');
      return _cachedDeviceId!;
    }
    // debugPrint('[DeviceIdService] 开始获取设备ID...');

    try {
      String rawId;
      String platform;

      if (Platform.isMacOS) {
        rawId = await _getMacOSDeviceId();
        platform = 'macos';
      } else if (Platform.isWindows) {
        rawId = await _getWindowsDeviceId();
        platform = 'windows';
      } else if (Platform.isAndroid) {
        rawId = await _getAndroidDeviceId();
        platform = 'android';
      } else if (Platform.isIOS) {
        rawId = await _getIOSDeviceId();
        platform = 'ios';
      } else if (Platform.isLinux) {
        rawId = await _getLinuxDeviceId();
        platform = 'linux';
      } else {
        // 其他平台使用持久化存储的降级ID
        rawId = await _getOrCreateFallbackDeviceId();
        platform = 'unknown';
      }

      // 对原始ID进行SHA256哈希，保护隐私
      final hash = sha256.convert(utf8.encode(rawId)).toString();
      // 取前12位作为短ID，足够唯一且易读
      final shortHash = hash.substring(0, 12);

      _cachedDeviceId = 'AMBER-$platform-$shortHash';

      debugPrint('[DeviceIdService] 设备ID: $_cachedDeviceId');
      return _cachedDeviceId!;
    } catch (e) {
      debugPrint('[DeviceIdService] 获取设备ID失败: $e');
      // 降级方案：从本地存储读取，如果没有则生成并持久化保存
      _cachedDeviceId = await _getOrCreateFallbackDeviceId();
      return _cachedDeviceId!;
    }
  }

  /// 尝试获取硬件级别的设备ID（不使用降级方案）
  ///
  /// 返回格式化后的设备ID，如果获取失败则返回 null
  Future<String?> _tryGetHardwareId() async {
    try {
      String? rawId;
      String? platform;

      if (Platform.isMacOS) {
        final macInfo = await _deviceInfo.macOsInfo;
        final systemGuid = macInfo.systemGUID;
        debugPrint('[DeviceIdService] 重新获取 macOS systemGUID: "$systemGuid"');
        if (systemGuid != null && systemGuid.isNotEmpty) {
          rawId = systemGuid;
          platform = 'macos';
        }
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        final deviceId = windowsInfo.deviceId;
        if (deviceId.isNotEmpty) {
          rawId = deviceId;
          platform = 'windows';
        }
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        final components = [
          androidInfo.id,
          androidInfo.fingerprint,
          androidInfo.hardware,
          androidInfo.brand,
          androidInfo.model,
        ];
        rawId = components.join('-');
        platform = 'android';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        final vendorId = iosInfo.identifierForVendor;
        if (vendorId != null && vendorId.isNotEmpty) {
          rawId = vendorId;
          platform = 'ios';
        }
      } else if (Platform.isLinux) {
        final linuxInfo = await _deviceInfo.linuxInfo;
        final machineId = linuxInfo.machineId;
        if (machineId != null && machineId.isNotEmpty) {
          rawId = machineId;
          platform = 'linux';
        }
      }

      if (rawId == null || platform == null) {
        return null;
      }

      // 对原始ID进行SHA256哈希
      final hash = sha256.convert(utf8.encode(rawId)).toString();
      final shortHash = hash.substring(0, 12);
      return 'AMBER-$platform-$shortHash';
    } catch (e) {
      debugPrint('[DeviceIdService] 尝试获取硬件ID失败: $e');
      return null;
    }
  }

  /// 获取或创建降级设备ID
  ///
  /// 使用 SharedPreferences 持久化存储，确保卸载重装后仍然是同一个ID。
  /// 这样即使硬件ID获取失败，也不会每次生成不同的设备ID。
  Future<String> _getOrCreateFallbackDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? fallbackId = prefs.getString(_fallbackDeviceIdKey);

      if (fallbackId == null || fallbackId.isEmpty) {
        // 生成新的降级ID并保存
        fallbackId = 'AMBER-fallback-${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString(_fallbackDeviceIdKey, fallbackId);
        debugPrint('[DeviceIdService] 生成并保存降级ID: $fallbackId');
      } else {
        debugPrint('[DeviceIdService] 使用已保存的降级ID: $fallbackId');
      }

      return fallbackId;
    } catch (e) {
      // SharedPreferences 也失败了，使用内存中的时间戳（最后手段）
      debugPrint('[DeviceIdService] SharedPreferences 失败: $e');
      return 'AMBER-temp-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// 清除已保存的降级设备ID（用于重新获取硬件ID）
  ///
  /// 调用此方法后，下次 getDeviceId() 会重新尝试获取硬件级别的设备ID。
  /// 如果之前因为插件未安装等原因使用了降级ID，可以通过此方法修复。
  Future<void> clearFallbackDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_fallbackDeviceIdKey);
      _cachedDeviceId = null;
      debugPrint('[DeviceIdService] ✅ 已清除降级设备ID，下次将重新获取');
    } catch (e) {
      debugPrint('[DeviceIdService] 清除降级设备ID失败: $e');
    }
  }

  /// 检查当前设备ID是否为降级ID
  bool get isFallbackId =>
      _cachedDeviceId?.contains('fallback') == true ||
      _cachedDeviceId?.contains('temp') == true;

  /// 获取 macOS 设备ID
  ///
  /// 使用 IOPlatformUUID，这是 Mac 的硬件UUID，永久不变。
  /// 即使重装系统也不会改变（除非更换主板）。
  Future<String> _getMacOSDeviceId() async {
    final macInfo = await _deviceInfo.macOsInfo;
    // systemGUID 就是 IOPlatformUUID
    final systemGuid = macInfo.systemGUID;
    debugPrint('[DeviceIdService] macOS systemGUID: "$systemGuid" (isNull: ${systemGuid == null}, isEmpty: ${systemGuid?.isEmpty})');
    if (systemGuid != null && systemGuid.isNotEmpty) {
      return systemGuid;
    }
    // 降级方案：使用持久化存储的ID（不再使用易变的 kernelVersion）
    debugPrint('[DeviceIdService] macOS systemGUID 为空，使用降级方案');
    return await _getOrCreateFallbackDeviceId();
  }

  /// 获取 Windows 设备ID
  ///
  /// 使用 MachineGuid（注册表中的机器标识）。
  /// 路径：HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Cryptography\MachineGuid
  /// 重装系统会改变，但日常使用是稳定的。
  Future<String> _getWindowsDeviceId() async {
    final windowsInfo = await _deviceInfo.windowsInfo;
    // deviceId 是 Windows 的设备ID
    final deviceId = windowsInfo.deviceId;
    if (deviceId.isNotEmpty) {
      return deviceId;
    }
    // 降级方案：使用持久化存储的ID（不再使用易变的计算机名/用户名）
    return await _getOrCreateFallbackDeviceId();
  }

  /// 获取 Android 设备ID
  ///
  /// 使用 ANDROID_ID + 硬件指纹组合。
  /// ANDROID_ID 在恢复出厂设置后会改变，但日常使用稳定。
  Future<String> _getAndroidDeviceId() async {
    final androidInfo = await _deviceInfo.androidInfo;
    // 组合多个硬件信息以提高唯一性
    final components = [
      androidInfo.id, // ANDROID_ID
      androidInfo.fingerprint, // 硬件指纹
      androidInfo.hardware, // 硬件名称
      androidInfo.brand, // 品牌
      androidInfo.model, // 型号
    ];
    return components.join('-');
  }

  /// 获取 iOS 设备ID
  ///
  /// 使用 identifierForVendor。
  /// 同一开发者的应用共享此ID，卸载该开发者所有应用后会重置。
  Future<String> _getIOSDeviceId() async {
    final iosInfo = await _deviceInfo.iosInfo;
    final vendorId = iosInfo.identifierForVendor;
    if (vendorId != null && vendorId.isNotEmpty) {
      return vendorId;
    }
    // 降级方案：使用持久化存储的ID（不再使用易变的系统版本）
    return await _getOrCreateFallbackDeviceId();
  }

  /// 获取 Linux 设备ID
  ///
  /// 使用 machine-id（/etc/machine-id 或 /var/lib/dbus/machine-id）。
  Future<String> _getLinuxDeviceId() async {
    final linuxInfo = await _deviceInfo.linuxInfo;
    final machineId = linuxInfo.machineId;
    if (machineId != null && machineId.isNotEmpty) {
      return machineId;
    }
    // 降级方案：使用持久化存储的ID（不再使用易变的主机名）
    return await _getOrCreateFallbackDeviceId();
  }

  /// 清除缓存（用于测试）
  @visibleForTesting
  void clearCache() {
    _cachedDeviceId = null;
  }

  /// 获取设备详细信息（用于调试/显示）
  Future<Map<String, String>> getDeviceInfo() async {
    final info = <String, String>{};

    try {
      if (Platform.isMacOS) {
        final macInfo = await _deviceInfo.macOsInfo;
        info['platform'] = 'macOS';
        info['model'] = macInfo.model;
        info['osVersion'] = macInfo.osRelease;
        info['hostName'] = macInfo.hostName;
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        info['platform'] = 'Windows';
        info['computerName'] = windowsInfo.computerName;
        info['osVersion'] = '${windowsInfo.majorVersion}.${windowsInfo.minorVersion}';
        info['productName'] = windowsInfo.productName;
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        info['platform'] = 'Android';
        info['brand'] = androidInfo.brand;
        info['model'] = androidInfo.model;
        info['osVersion'] = androidInfo.version.release;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        info['platform'] = 'iOS';
        info['model'] = iosInfo.model;
        info['osVersion'] = iosInfo.systemVersion;
        info['name'] = iosInfo.name;
      }
    } catch (e) {
      info['error'] = e.toString();
    }

    return info;
  }
}
