import 'package:flutter/material.dart';

/// Small Widget 皮肤类型枚举
///
/// 定义了 5 种预设皮肤，每种皮肤包含：
/// - 背景渐变色（start, center, end 三色渐变）
/// - 文字颜色（根据背景自动计算对比度最佳的颜色）
enum WidgetSkinType {
  /// 琥珀橙（默认）- 活力的琥珀清单品牌色
  amber,

  /// 纯净白 - 简约白色背景
  white,

  /// 深空灰 - 深色主题
  dark,

  /// 薄荷绿 - 清新自然风格
  mint,

  /// 樱花粉 - 温柔少女风格
  pink,

  /// 撞色 01
  contrast01,

  /// 撞色 02
  contrast02,

  /// 撞色 03
  contrast03,

  /// 撞色 04
  contrast04,

  /// 撞色 05
  contrast05,
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

  /// 背景图片资源路径（撞色皮肤专用）
  /// 普通渐变皮肤为 null，撞色皮肤指向 assets/skins/ 下的图片
  final String? backgroundImagePath;

  /// 是否为撞色皮肤（有背景图的皮肤）
  bool get isContrastSkin => backgroundImagePath != null;

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
    this.backgroundImagePath,
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
    // 琥珀橙（默认）- 活力品牌色
    WidgetSkinType.amber: const WidgetSkinConfig(
      type: WidgetSkinType.amber,
      displayName: '琥珀橙',
      startColor: Color(0xFFFFE0B2),  // 温暖浅橙
      centerColor: Color(0xFFFFB74D), // 活力橙
      endColor: Color(0xFFFFA726),    // 深琥珀橙
      textColor: Color(0xFF4E342E),   // 深棕色文字
      secondaryTextColor: Color(0xFF6D4C41), // 中棕色
      iconColor: Color(0xFF4E342E),
      checkboxColor: Color(0xFF5D4037),
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

    // 樱花粉（淡雅版）
    WidgetSkinType.pink: const WidgetSkinConfig(
      type: WidgetSkinType.pink,
      displayName: '樱花粉',
      startColor: Color(0xFFFCE4EC),  // 淡粉白
      centerColor: Color(0xFFF8BBD9), // 浅樱花粉
      endColor: Color(0xFFF48FB1),    // 中等樱花粉
      textColor: Color(0xFF4A0D2B), // 更深的紫红色，提高可读性
      secondaryTextColor: Color(0xFF6D1B42), // 深玫红色
      iconColor: Color(0xFF4A0D2B),
      checkboxColor: Color(0xFF6D1B42),
    ),

    // 撞色 01 - 蓝紫渐变（水墨风格背景图）
    WidgetSkinType.contrast01: const WidgetSkinConfig(
      type: WidgetSkinType.contrast01,
      displayName: '撞色01',
      startColor: Color(0xFF4527A0),
      centerColor: Color(0xFF7C4DFF),
      endColor: Color(0xFF651FFF),
      textColor: Colors.white,
      secondaryTextColor: Colors.white70,
      iconColor: Colors.white,
      checkboxColor: Colors.white,
      backgroundImagePath: 'assets/skins/contrast_01.png',
    ),

    // 撞色 02 - 红粉渐变（水墨风格背景图）
    WidgetSkinType.contrast02: const WidgetSkinConfig(
      type: WidgetSkinType.contrast02,
      displayName: '撞色02',
      startColor: Color(0xFFC62828),
      centerColor: Color(0xFFEF5350),
      endColor: Color(0xFFE57373),
      textColor: Colors.white,
      secondaryTextColor: Colors.white70,
      iconColor: Colors.white,
      checkboxColor: Colors.white,
      backgroundImagePath: 'assets/skins/contrast_02.png',
    ),

    // 撞色 03 - 绿黄渐变（水墨风格背景图）
    WidgetSkinType.contrast03: const WidgetSkinConfig(
      type: WidgetSkinType.contrast03,
      displayName: '撞色03',
      startColor: Color(0xFF2E7D32),
      centerColor: Color(0xFF66BB6A),
      endColor: Color(0xFF43A047),
      textColor: Colors.white,
      secondaryTextColor: Colors.white70,
      iconColor: Colors.white,
      checkboxColor: Colors.white,
      backgroundImagePath: 'assets/skins/contrast_03.png',
    ),

    // 撞色 04 - 橙紫撞色（水墨风格背景图）
    WidgetSkinType.contrast04: const WidgetSkinConfig(
      type: WidgetSkinType.contrast04,
      displayName: '撞色04',
      startColor: Color(0xFFEF6C00),
      centerColor: Color(0xFFAB47BC),
      endColor: Color(0xFF8E24AA),
      textColor: Colors.white,
      secondaryTextColor: Colors.white70,
      iconColor: Colors.white,
      checkboxColor: Colors.white,
      backgroundImagePath: 'assets/skins/contrast_04.png',
    ),

    // 撞色 05 - 青蓝渐变（水墨风格背景图）
    WidgetSkinType.contrast05: const WidgetSkinConfig(
      type: WidgetSkinType.contrast05,
      displayName: '撞色05',
      startColor: Color(0xFF00838F),
      centerColor: Color(0xFF00ACC1),
      endColor: Color(0xFF0097A7),
      textColor: Colors.white,
      secondaryTextColor: Colors.white70,
      iconColor: Colors.white,
      checkboxColor: Colors.white,
      backgroundImagePath: 'assets/skins/contrast_05.png',
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
      case WidgetSkinType.contrast01:
        return 'widget_skin_contrast_01'; // Not actually used for setting bg resource directly if we use updateWidget
      case WidgetSkinType.contrast02:
        return 'widget_skin_contrast_02';
      case WidgetSkinType.contrast03:
        return 'widget_skin_contrast_03';
      case WidgetSkinType.contrast04:
        return 'widget_skin_contrast_04';
      case WidgetSkinType.contrast05:
        return 'widget_skin_contrast_05';
    }
  }
}
