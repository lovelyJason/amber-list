import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 用户个人信息状态
/// 包含头像等个人化设置
class UserProfile {
  /// 用户自定义头像路径（本地文件路径）
  /// 如果为 null，则使用默认的 Logo
  final String? avatarPath;

  /// 用户昵称（预留）
  final String? nickname;

  const UserProfile({
    this.avatarPath,
    this.nickname,
  });

  /// 是否已设置自定义头像
  bool get hasCustomAvatar => avatarPath != null && avatarPath!.isNotEmpty;

  UserProfile copyWith({
    String? avatarPath,
    String? nickname,
    bool clearAvatar = false,
  }) {
    return UserProfile(
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
      nickname: nickname ?? this.nickname,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() => {
        'avatarPath': avatarPath,
        'nickname': nickname,
      };

  /// 从 JSON 创建
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      avatarPath: json['avatarPath'] as String?,
      nickname: json['nickname'] as String?,
    );
  }
}

/// 用户个人信息 Notifier
/// 负责管理用户头像等个人信息，并持久化到 SharedPreferences
class UserProfileNotifier extends StateNotifier<UserProfile> {
  UserProfileNotifier() : super(const UserProfile()) {
    _loadProfile();
  }

  /// SharedPreferences key
  static const _configKey = 'user_profile';

  /// 头像文件存储目录名
  static const _avatarDirName = 'avatars';

  /// 加载用户信息
  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_configKey);

      if (jsonStr != null && jsonStr.isNotEmpty) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        final profile = UserProfile.fromJson(json);

        // 验证头像文件是否存在
        if (profile.avatarPath != null) {
          final file = File(profile.avatarPath!);
          if (await file.exists()) {
            state = profile;
          } else {
            // 文件不存在，清除路径
            state = profile.copyWith(clearAvatar: true);
            _saveProfile();
          }
        } else {
          state = profile;
        }

        debugPrint('[UserProfile] 已加载用户信息');
      }
    } catch (e) {
      debugPrint('[UserProfile] 加载用户信息失败: $e');
    }
  }

  /// 保存用户信息
  Future<void> _saveProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_configKey, jsonEncode(state.toJson()));
      debugPrint('[UserProfile] 已保存用户信息');
    } catch (e) {
      debugPrint('[UserProfile] 保存用户信息失败: $e');
    }
  }

  /// 获取头像存储目录
  Future<Directory> _getAvatarDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory('${appDir.path}/$_avatarDirName');
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }
    return avatarDir;
  }

  /// 设置头像
  /// [sourceFile] 用户选择的图片文件
  /// 返回保存后的文件路径
  Future<String?> setAvatar(File sourceFile) async {
    try {
      // 获取头像存储目录
      final avatarDir = await _getAvatarDir();

      // 生成新的文件名（使用时间戳避免缓存问题）
      final extension = sourceFile.path.split('.').last.toLowerCase();
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final targetPath = '${avatarDir.path}/$fileName';

      // 删除旧头像文件（如果存在）
      if (state.avatarPath != null) {
        final oldFile = File(state.avatarPath!);
        if (await oldFile.exists()) {
          await oldFile.delete();
          debugPrint('[UserProfile] 已删除旧头像: ${state.avatarPath}');
        }
      }

      // 复制新头像到应用目录
      await sourceFile.copy(targetPath);
      debugPrint('[UserProfile] 已保存新头像: $targetPath');

      // 更新状态
      state = state.copyWith(avatarPath: targetPath);
      await _saveProfile();

      return targetPath;
    } catch (e) {
      debugPrint('[UserProfile] 设置头像失败: $e');
      return null;
    }
  }

  /// 清除头像（恢复默认 Logo）
  Future<void> clearAvatar() async {
    try {
      // 删除头像文件
      if (state.avatarPath != null) {
        final file = File(state.avatarPath!);
        if (await file.exists()) {
          await file.delete();
          debugPrint('[UserProfile] 已删除头像文件');
        }
      }

      // 更新状态
      state = state.copyWith(clearAvatar: true);
      await _saveProfile();
    } catch (e) {
      debugPrint('[UserProfile] 清除头像失败: $e');
    }
  }

  /// 设置昵称
  void setNickname(String? nickname) {
    state = state.copyWith(nickname: nickname);
    _saveProfile();
  }
}

/// 用户个人信息 Provider
final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  return UserProfileNotifier();
});
