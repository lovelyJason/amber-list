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

  /// Medium Widget 皮肤类型
  final WidgetSkinType mediumWidgetSkin;

  /// Large Widget 皮肤类型
  final WidgetSkinType largeWidgetSkin;

  /// 点击任务文字是否也能完成任务
  /// true: 点击复选框或文字都能切换任务状态
  /// false: 只有点击复选框才能切换（点击文字打开 App）
  final bool tapTextToComplete;

  const WidgetSettings({
    this.smallWidgetSkin = WidgetSkinType.amber,
    this.mediumWidgetSkin = WidgetSkinType.amber,
    this.largeWidgetSkin = WidgetSkinType.amber,
    this.tapTextToComplete = true, // 默认开启，与当前 iOS 行为一致
  });

  WidgetSettings copyWith({
    WidgetSkinType? smallWidgetSkin,
    WidgetSkinType? mediumWidgetSkin,
    WidgetSkinType? largeWidgetSkin,
    bool? tapTextToComplete,
  }) {
    return WidgetSettings(
      smallWidgetSkin: smallWidgetSkin ?? this.smallWidgetSkin,
      mediumWidgetSkin: mediumWidgetSkin ?? this.mediumWidgetSkin,
      largeWidgetSkin: largeWidgetSkin ?? this.largeWidgetSkin,
      tapTextToComplete: tapTextToComplete ?? this.tapTextToComplete,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() => {
        'smallWidgetSkin': smallWidgetSkin.index,
        'mediumWidgetSkin': mediumWidgetSkin.index,
        'largeWidgetSkin': largeWidgetSkin.index,
        'tapTextToComplete': tapTextToComplete,
      };

  /// 从 JSON 创建
  factory WidgetSettings.fromJson(Map<String, dynamic> json) {
    return WidgetSettings(
      smallWidgetSkin: WidgetSkinType.values[
          (json['smallWidgetSkin'] as int?) ?? WidgetSkinType.amber.index],
      mediumWidgetSkin: WidgetSkinType.values[
          (json['mediumWidgetSkin'] as int?) ?? WidgetSkinType.amber.index],
      largeWidgetSkin: WidgetSkinType.values[
          (json['largeWidgetSkin'] as int?) ?? WidgetSkinType.amber.index],
      tapTextToComplete: (json['tapTextToComplete'] as bool?) ?? true,
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

      // 同步所有尺寸皮肤设置到原生 Widget
      final service = HomeWidgetService();
      await service.updateSmallWidgetSkin(state.smallWidgetSkin);
      await service.updateMediumWidgetSkin(state.mediumWidgetSkin);
      await service.updateLargeWidgetSkin(state.largeWidgetSkin);
      await service.updateTapTextToComplete(state.tapTextToComplete);

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

  /// 设置 Medium Widget 皮肤
  void setMediumWidgetSkin(WidgetSkinType skin) {
    if (state.mediumWidgetSkin == skin) return;

    state = state.copyWith(mediumWidgetSkin: skin);
    _saveSettings();
    debugPrint('[WidgetSettings] Medium Widget 皮肤已切换为: ${skin.name}');
  }

  /// 设置 Large Widget 皮肤
  void setLargeWidgetSkin(WidgetSkinType skin) {
    if (state.largeWidgetSkin == skin) return;

    state = state.copyWith(largeWidgetSkin: skin);
    _saveSettings();
    debugPrint('[WidgetSettings] Large Widget 皮肤已切换为: ${skin.name}');
  }

  /// 统一设置所有尺寸 Widget 的皮肤
  void setAllWidgetSkin(WidgetSkinType skin) {
    if (state.smallWidgetSkin == skin &&
        state.mediumWidgetSkin == skin &&
        state.largeWidgetSkin == skin) {
      return;
    }

    state = state.copyWith(
      smallWidgetSkin: skin,
      mediumWidgetSkin: skin,
      largeWidgetSkin: skin,
    );
    _saveSettings();
    debugPrint('[WidgetSettings] 所有 Widget 皮肤已切换为: ${skin.name}');
  }

  /// 设置"点击文字完成任务"开关
  ///
  /// [enabled] true: 点击文字也能切换任务状态；false: 只有点击复选框才能切换
  void setTapTextToComplete(bool enabled) {
    if (state.tapTextToComplete == enabled) return;

    state = state.copyWith(tapTextToComplete: enabled);
    _saveSettings();
    debugPrint('[WidgetSettings] 点击文字完成任务已切换为: $enabled');
  }
}

/// 小组件设置 Provider
final widgetSettingsProvider =
    StateNotifierProvider<WidgetSettingsNotifier, WidgetSettings>((ref) {
  return WidgetSettingsNotifier();
});
