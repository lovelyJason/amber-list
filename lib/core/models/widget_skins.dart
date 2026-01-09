import 'package:flutter/material.dart';

/// Small Widget 皮肤类型枚举
///
/// 定义了 5 种预设皮肤，每种皮肤包含：
/// - 背景渐变色（start, center, end 三色渐变）
/// - 文字颜色（根据背景自动计算对比度最佳的颜色）
enum WidgetSkinType {
  /// 琥珀金（默认）- 经典的琥珀清单品牌色
  amber,

  /// 纯净白 - 简约白色背景
  white,

  /// 深空灰 - 深色主题
  dark,

  /// 薄荷绿 - 清新自然风格
  mint,

  /// 樱花粉 - 温柔少女风格
  pink,
}

/// Widget 皮肤配置类
///
/// 存储单个皮肤的所有视觉属性
class WidgetSkinConfig {
  /// 皮肤类型
  final WidgetSkinType type;

  /// 皮肤显示名称（中文）
  final String displayName;

  /// 渐变起始色
  final Color startColor;

  /// 渐变中间色
  final Color centerColor;

  /// 渐变结束色
  final Color endColor;

  /// 主文字颜色（任务标题）
  final Color textColor;

  /// 次要文字颜色（时间、页码等）
  final Color secondaryTextColor;

  /// 图标颜色
  final Color iconColor;

  /// 复选框颜色
  final Color checkboxColor;

  /// 预览用的 Flutter 渐变
  LinearGradient get previewGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [startColor, centerColor, endColor],
      );

  const WidgetSkinConfig({
    required this.type,
    required this.displayName,
    required this.startColor,
    required this.centerColor,
    required this.endColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.iconColor,
    required this.checkboxColor,
  });
}

/// Widget 皮肤配置表
///
/// 所有预设皮肤的配置数据
/// 颜色值与 Android drawable XML 保持一致
class WidgetSkins {
  WidgetSkins._();

  /// 获取指定类型的皮肤配置
  static WidgetSkinConfig getConfig(WidgetSkinType type) {
    return _configs[type]!;
  }

  /// 获取所有皮肤配置列表
  static List<WidgetSkinConfig> get allConfigs => _configs.values.toList();

  /// 皮肤配置映射表
  static final Map<WidgetSkinType, WidgetSkinConfig> _configs = {
    // 琥珀金（默认）
    WidgetSkinType.amber: const WidgetSkinConfig(
      type: WidgetSkinType.amber,
      displayName: '琥珀金',
      startColor: Color(0xFFE8D494),
      centerColor: Color(0xFFDDBE6F),
      endColor: Color(0xFFD9B560),
      textColor: Color(0xFF5C3D1E), // 深棕色，对比度高
      secondaryTextColor: Color(0xFF8B6914), // 中棕色
      iconColor: Color(0xFF5C3D1E),
      checkboxColor: Color(0xFF5C3D1E),
    ),

    // 纯净白
    WidgetSkinType.white: const WidgetSkinConfig(
      type: WidgetSkinType.white,
      displayName: '纯净白',
      startColor: Color(0xFFFAFAFA),
      centerColor: Color(0xFFF5F5F5),
      endColor: Color(0xFFEEEEEE),
      textColor: Color(0xFF212121), // 深灰，高对比度
      secondaryTextColor: Color(0xFF757575),
      iconColor: Color(0xFF424242),
      checkboxColor: Color(0xFF616161),
    ),

    // 深空灰
    WidgetSkinType.dark: const WidgetSkinConfig(
      type: WidgetSkinType.dark,
      displayName: '深空灰',
      startColor: Color(0xFF424242),
      centerColor: Color(0xFF303030),
      endColor: Color(0xFF212121),
      textColor: Color(0xFFE0E0E0), // 浅灰，暗色背景下高对比度
      secondaryTextColor: Color(0xFF9E9E9E),
      iconColor: Color(0xFFBDBDBD),
      checkboxColor: Color(0xFFBDBDBD),
    ),

    // 薄荷绿
    WidgetSkinType.mint: const WidgetSkinConfig(
      type: WidgetSkinType.mint,
      displayName: '薄荷绿',
      startColor: Color(0xFFB2DFDB),
      centerColor: Color(0xFF80CBC4),
      endColor: Color(0xFF4DB6AC),
      textColor: Color(0xFF1B3B38), // 更深的青黑色，提高可读性
      secondaryTextColor: Color(0xFF2E5752), // 深青色
      iconColor: Color(0xFF1B3B38),
      checkboxColor: Color(0xFF2E5752),
    ),

    // 樱花粉
    WidgetSkinType.pink: const WidgetSkinConfig(
      type: WidgetSkinType.pink,
      displayName: '樱花粉',
      startColor: Color(0xFFF8BBD9),
      centerColor: Color(0xFFF48FB1),
      endColor: Color(0xFFF06292),
      textColor: Color(0xFF4A0D2B), // 更深的紫红色，提高可读性
      secondaryTextColor: Color(0xFF6D1B42), // 深玫红色
      iconColor: Color(0xFF4A0D2B),
      checkboxColor: Color(0xFF6D1B42),
    ),
  };

  /// 根据皮肤类型获取 Android drawable 名称
  /// 用于 RemoteViews.setInt(id, "setBackgroundResource", R.drawable.xxx)
  static String getAndroidDrawableName(WidgetSkinType type) {
    switch (type) {
      case WidgetSkinType.amber:
        return 'widget_small_background'; // 默认，保持原有名称
      case WidgetSkinType.white:
        return 'widget_small_bg_white';
      case WidgetSkinType.dark:
        return 'widget_small_bg_dark';
      case WidgetSkinType.mint:
        return 'widget_small_bg_mint';
      case WidgetSkinType.pink:
        return 'widget_small_bg_pink';
    }
  }
}
