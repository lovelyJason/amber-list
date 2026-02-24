import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/activation_code.dart';

/// ============================================================
/// 激活码本地存储服务
/// ============================================================
/// 负责激活码相关数据的本地持久化存储：
/// - 激活码和激活信息都存储在 SharedPreferences
/// - 不使用钥匙串，避免苹果开发者账号依赖
/// ============================================================
class ActivationService {
  // SharedPreferences keys
  static const _activationInfoKey = 'amber_list_activation_info';
  static const _lastVerifyAtKey = 'amber_list_last_verify_at';
  static const _activationCodeKey = 'amber_list_activation_code';

  // ============================================================
  // 激活码读写
  // ============================================================

  /// 获取已激活的激活码
  static Future<String?> getActivationCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_activationCodeKey);
    } catch (e) {
      debugPrint('[ActivationService] 获取激活码失败: $e');
      return null;
    }
  }

  /// 保存激活码
  static Future<void> saveActivationCode(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activationCodeKey, code);
      // debugPrint('[ActivationService] ✅ 激活码保存成功');
    } catch (e) {
      debugPrint('[ActivationService] ❌ 激活码保存失败: $e');
      rethrow;
    }
  }

  /// 删除激活码
  static Future<void> deleteActivationCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activationCodeKey);
      debugPrint('[ActivationService] 激活码已删除');
    } catch (e) {
      debugPrint('[ActivationService] 删除激活码失败: $e');
    }
  }

  // ============================================================
  // 激活信息读写（状态、时间等）
  // ============================================================

  /// 保存激活信息
  static Future<void> saveActivationInfo(ActivationCode activationCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 保存激活码
      await saveActivationCode(activationCode.code);

      // 保存激活信息到 SharedPreferences
      final jsonStr = jsonEncode(activationCode.toJson());
      await prefs.setString(_activationInfoKey, jsonStr);

      // 更新最后验证时间
      await _updateLastVerifyAt();

      // debugPrint('[ActivationService] ✅ 激活信息保存成功');
    } catch (e) {
      debugPrint('[ActivationService] ❌ 激活信息保存失败: $e');
      rethrow;
    }
  }

  /// 获取激活信息
  static Future<ActivationCode?> getActivationInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_activationInfoKey);

      if (jsonStr == null || jsonStr.isEmpty) {
        return null;
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return ActivationCode.fromJson(json);
    } catch (e) {
      debugPrint('[ActivationService] 获取激活信息失败: $e');
      return null;
    }
  }

  // ============================================================
  // 本地状态检查
  // ============================================================

  /// 本地激活状态检查（不联网）
  static Future<bool> isActivatedLocal() async {
    try {
      final code = await getActivationCode();
      if (code == null || code.isEmpty) return false;

      final info = await getActivationInfo();
      if (info == null) return false;

      // 检查状态
      if (info.status != ActivationCodeStatus.activated) return false;

      // 检查是否过期
      if (info.expiresAt != null && DateTime.now().isAfter(info.expiresAt!)) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[ActivationService] 本地激活状态检查失败: $e');
      return false;
    }
  }

  /// 更新最后验证时间
  static Future<void> _updateLastVerifyAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastVerifyAtKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('[ActivationService] 更新最后验证时间失败: $e');
    }
  }

  // ============================================================
  // 清除所有数据
  // ============================================================

  /// 清除所有激活信息
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 清除所有激活相关数据
      await prefs.remove(_activationInfoKey);
      await prefs.remove(_lastVerifyAtKey);
      await prefs.remove(_activationCodeKey);

      debugPrint('[ActivationService] ✅ 所有激活信息已清除');
    } catch (e) {
      debugPrint('[ActivationService] 清除激活信息失败: $e');
    }
  }
}
