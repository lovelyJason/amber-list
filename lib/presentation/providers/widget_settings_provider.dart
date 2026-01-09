import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/widget_skins.dart';
import '../../core/services/home_widget_service.dart';

/// 小组件设置状态
///
/// 存储用户对各尺寸小组件的皮肤/样式偏好
class WidgetSettings {
  /// Small Widget 皮肤类型
  final WidgetSkinType smallWidgetSkin;

  const WidgetSettings({
    this.smallWidgetSkin = WidgetSkinType.white,
  });

  WidgetSettings copyWith({
    WidgetSkinType? smallWidgetSkin,
  }) {
    return WidgetSettings(
      smallWidgetSkin: smallWidgetSkin ?? this.smallWidgetSkin,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() => {
        'smallWidgetSkin': smallWidgetSkin.index,
      };

  /// 从 JSON 创建
  factory WidgetSettings.fromJson(Map<String, dynamic> json) {
    return WidgetSettings(
      smallWidgetSkin: WidgetSkinType.values[
          (json['smallWidgetSkin'] as int?) ?? WidgetSkinType.white.index],
    );
  }
}

/// 小组件设置 Notifier
///
/// 负责管理小组件设置状态并持久化到 SharedPreferences
class WidgetSettingsNotifier extends StateNotifier<WidgetSettings> {
  WidgetSettingsNotifier() : super(const WidgetSettings()) {
    _loadSettings();
  }

  /// SharedPreferences key
  static const _configKey = 'widget_settings';

  /// 加载完成标志 Completer
  /// 用于确保外部代码可以等待设置加载完成
  final Completer<WidgetSettings> _loadCompleter = Completer<WidgetSettings>();

  /// 设置变更回调（用于通知 HomeWidgetService 刷新 Widget）
  VoidCallback? onSettingsChanged;

  /// 等待设置加载完成
  /// 返回加载完成后的设置值
  Future<WidgetSettings> waitForLoad() => _loadCompleter.future;

  /// 加载设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_configKey);

      if (jsonStr != null && jsonStr.isNotEmpty) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = WidgetSettings.fromJson(json);
        debugPrint('[WidgetSettings] 已加载小组件设置: ${state.smallWidgetSkin.name}');
      }

      // 标记加载完成
      if (!_loadCompleter.isCompleted) {
        _loadCompleter.complete(state);
      }
    } catch (e) {
      debugPrint('[WidgetSettings] 加载设置失败: $e');
      // 加载失败时也标记完成，使用默认值
      if (!_loadCompleter.isCompleted) {
        _loadCompleter.complete(state);
      }
    }
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_configKey, jsonEncode(state.toJson()));
      debugPrint('[WidgetSettings] 已保存小组件设置');

      // 同步皮肤设置到原生 Widget
      await HomeWidgetService().updateSmallWidgetSkin(state.smallWidgetSkin);

      // 触发回调通知 Widget 刷新
      onSettingsChanged?.call();
    } catch (e) {
      debugPrint('[WidgetSettings] 保存设置失败: $e');
    }
  }

  /// 设置 Small Widget 皮肤
  void setSmallWidgetSkin(WidgetSkinType skin) {
    if (state.smallWidgetSkin == skin) return;

    state = state.copyWith(smallWidgetSkin: skin);
    _saveSettings();
    debugPrint('[WidgetSettings] Small Widget 皮肤已切换为: ${skin.name}');
  }
}

/// 小组件设置 Provider
final widgetSettingsProvider =
    StateNotifierProvider<WidgetSettingsNotifier, WidgetSettings>((ref) {
  return WidgetSettingsNotifier();
});
