import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 闪念胶囊设置状态
/// 存储快捷键配置和展开模式的持久化状态
class QuickAddSettings {
  /// 主键（如 A、Q、Space 等）
  final String keyLabel;

  /// 是否使用 Ctrl（Windows）/ Control（macOS）
  final bool useCtrl;

  /// 是否使用 Shift
  final bool useShift;

  /// 是否使用 Alt（Windows）/ Option（macOS）
  final bool useAlt;

  /// 是否使用 Meta（Windows）/ Command（macOS）
  final bool useMeta;

  /// 展开模式下上次选中的清单 ID（null 表示收集箱）
  /// 用于持久化用户的清单选择偏好
  final String? lastSelectedListId;

  const QuickAddSettings({
    this.keyLabel = 'A',
    this.useCtrl = true,
    this.useShift = true,
    this.useAlt = false,
    this.useMeta = false,
    this.lastSelectedListId,
  });

  QuickAddSettings copyWith({
    String? keyLabel,
    bool? useCtrl,
    bool? useShift,
    bool? useAlt,
    bool? useMeta,
    String? lastSelectedListId,
    bool clearLastSelectedListId = false,
  }) {
    return QuickAddSettings(
      keyLabel: keyLabel ?? this.keyLabel,
      useCtrl: useCtrl ?? this.useCtrl,
      useShift: useShift ?? this.useShift,
      useAlt: useAlt ?? this.useAlt,
      useMeta: useMeta ?? this.useMeta,
      lastSelectedListId: clearLastSelectedListId
          ? null
          : (lastSelectedListId ?? this.lastSelectedListId),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() => {
        'keyLabel': keyLabel,
        'useCtrl': useCtrl,
        'useShift': useShift,
        'useAlt': useAlt,
        'useMeta': useMeta,
        'lastSelectedListId': lastSelectedListId,
      };

  /// 从 JSON 创建
  factory QuickAddSettings.fromJson(Map<String, dynamic> json) {
    return QuickAddSettings(
      keyLabel: json['keyLabel'] as String? ?? 'A',
      useCtrl: json['useCtrl'] as bool? ?? true,
      useShift: json['useShift'] as bool? ?? true,
      useAlt: json['useAlt'] as bool? ?? false,
      useMeta: json['useMeta'] as bool? ?? false,
      lastSelectedListId: json['lastSelectedListId'] as String?,
    );
  }

  /// 从设置构建 HotKey 对象
  HotKey toHotKey() {
    final modifiers = <HotKeyModifier>[];
    if (useCtrl) modifiers.add(HotKeyModifier.control);
    if (useShift) modifiers.add(HotKeyModifier.shift);
    if (useAlt) modifiers.add(HotKeyModifier.alt);
    if (useMeta) modifiers.add(HotKeyModifier.meta);

    return HotKey(
      key: _labelToPhysicalKey(keyLabel),
      modifiers: modifiers,
      scope: HotKeyScope.system,
    );
  }

  /// 将按键标签转换为 PhysicalKeyboardKey
  PhysicalKeyboardKey _labelToPhysicalKey(String label) {
    final upperLabel = label.toUpperCase();

    // 字母键
    if (upperLabel.length == 1 && upperLabel.codeUnitAt(0) >= 65 && upperLabel.codeUnitAt(0) <= 90) {
      final keyName = 'key$upperLabel';
      final key = PhysicalKeyboardKey.findKeyByCode(_letterKeyCode(upperLabel));
      return key ?? PhysicalKeyboardKey.keyA;
    }

    // 数字键
    if (upperLabel.length == 1 && upperLabel.codeUnitAt(0) >= 48 && upperLabel.codeUnitAt(0) <= 57) {
      return _digitKey(upperLabel);
    }

    // 特殊键
    switch (upperLabel) {
      case 'SPACE':
        return PhysicalKeyboardKey.space;
      case 'ENTER':
        return PhysicalKeyboardKey.enter;
      case 'TAB':
        return PhysicalKeyboardKey.tab;
      case 'ESCAPE':
      case 'ESC':
        return PhysicalKeyboardKey.escape;
      default:
        return PhysicalKeyboardKey.keyA;
    }
  }

  /// 获取字母键的 USB HID 码
  int _letterKeyCode(String letter) {
    // USB HID 码：A=0x00070004, B=0x00070005, ...
    final offset = letter.codeUnitAt(0) - 65; // A=0, B=1, ...
    return 0x00070004 + offset;
  }

  /// 获取数字键
  PhysicalKeyboardKey _digitKey(String digit) {
    switch (digit) {
      case '0':
        return PhysicalKeyboardKey.digit0;
      case '1':
        return PhysicalKeyboardKey.digit1;
      case '2':
        return PhysicalKeyboardKey.digit2;
      case '3':
        return PhysicalKeyboardKey.digit3;
      case '4':
        return PhysicalKeyboardKey.digit4;
      case '5':
        return PhysicalKeyboardKey.digit5;
      case '6':
        return PhysicalKeyboardKey.digit6;
      case '7':
        return PhysicalKeyboardKey.digit7;
      case '8':
        return PhysicalKeyboardKey.digit8;
      case '9':
        return PhysicalKeyboardKey.digit9;
      default:
        return PhysicalKeyboardKey.digit0;
    }
  }

  /// 获取格式化的快捷键显示文字
  String get displayText {
    final parts = <String>[];

    if (Platform.isMacOS) {
      // macOS 风格显示
      if (useCtrl) parts.add('⌃');
      if (useAlt) parts.add('⌥');
      if (useShift) parts.add('⇧');
      if (useMeta) parts.add('⌘');
    } else {
      // Windows 风格显示
      if (useCtrl) parts.add('Ctrl');
      if (useAlt) parts.add('Alt');
      if (useShift) parts.add('Shift');
      if (useMeta) parts.add('Win');
    }

    parts.add(keyLabel.toUpperCase());

    return Platform.isMacOS ? parts.join('') : parts.join(' + ');
  }
}

/// 闪念胶囊设置 Notifier
/// 负责管理快捷键设置状态并持久化到 SharedPreferences
class QuickAddSettingsNotifier extends StateNotifier<QuickAddSettings> {
  QuickAddSettingsNotifier() : super(const QuickAddSettings()) {
    _loadSettings();
  }

  /// SharedPreferences key
  static const _configKey = 'quick_add_settings';

  /// 是否已完成加载
  bool _isLoaded = false;

  /// 是否已完成加载
  bool get isLoaded => _isLoaded;

  /// 等待设置加载完成
  /// 用于初始化时确保设置已从 SharedPreferences 加载
  Future<QuickAddSettings> waitForLoad() async {
    if (_isLoaded) return state;

    // 最多等待 500ms
    for (int i = 0; i < 50; i++) {
      await Future.delayed(const Duration(milliseconds: 10));
      if (_isLoaded) return state;
    }
    debugPrint('[QuickAddSettings] 等待加载超时，使用默认设置');
    return state;
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_configKey);

      if (jsonStr != null && jsonStr.isNotEmpty) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = QuickAddSettings.fromJson(json);
        // debugPrint('[QuickAddSettings] 已加载快捷键设置: ${state.displayText}');
      }
    } catch (e) {
      debugPrint('[QuickAddSettings] 加载设置失败: $e');
    } finally {
      _isLoaded = true;
    }
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_configKey, jsonEncode(state.toJson()));
      debugPrint('[QuickAddSettings] 已保存快捷键设置: ${state.displayText}');
    } catch (e) {
      debugPrint('[QuickAddSettings] 保存设置失败: $e');
    }
  }

  /// 更新完整设置
  Future<void> updateSettings(QuickAddSettings settings) async {
    state = settings;
    await _saveSettings();
  }

  /// 设置主键
  Future<void> setKeyLabel(String keyLabel) async {
    state = state.copyWith(keyLabel: keyLabel);
    await _saveSettings();
  }

  /// 设置 Ctrl 修饰键
  Future<void> setUseCtrl(bool value) async {
    state = state.copyWith(useCtrl: value);
    await _saveSettings();
  }

  /// 设置 Shift 修饰键
  Future<void> setUseShift(bool value) async {
    state = state.copyWith(useShift: value);
    await _saveSettings();
  }

  /// 设置 Alt 修饰键
  Future<void> setUseAlt(bool value) async {
    state = state.copyWith(useAlt: value);
    await _saveSettings();
  }

  /// 设置 Meta 修饰键
  Future<void> setUseMeta(bool value) async {
    state = state.copyWith(useMeta: value);
    await _saveSettings();
  }

  /// 设置上次选中的清单 ID（展开模式持久化）
  /// [listId] 清单 ID，null 表示收集箱
  Future<void> setLastSelectedListId(String? listId) async {
    if (listId == null) {
      state = state.copyWith(clearLastSelectedListId: true);
    } else {
      state = state.copyWith(lastSelectedListId: listId);
    }
    await _saveSettings();
    debugPrint('[QuickAddSettings] 已保存上次选中清单: ${listId ?? "收集箱"}');
  }
}

/// 闪念胶囊设置 Provider
final quickAddSettingsProvider =
    StateNotifierProvider<QuickAddSettingsNotifier, QuickAddSettings>((ref) {
  return QuickAddSettingsNotifier();
});
