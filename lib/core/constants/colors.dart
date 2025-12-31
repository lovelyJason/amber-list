import 'package:flutter/material.dart';

/// 琥珀清单配色系统
class AmberColors {
  AmberColors._();

  // ===== 主色调（琥珀色系）=====
  /// 主色 - 琥珀金
  static const Color primary = Color(0xFFF5A623);

  /// 主色深 - hover/选中状态
  static const Color primaryDark = Color(0xFFD4891C);

  /// 主色浅 - 卡片背景/选中行高亮
  static const Color primaryLight = Color(0xFFFFF3E0);

  /// 主色透明 - 半透明蒙层/悬浮效果
  static const Color primaryTransparent = Color(0x26F5A623);

  // ===== 辅助色 =====
  /// 成功/完成
  static const Color success = Color(0xFF4CAF50);

  /// 警告/高优先级
  static const Color warning = Color(0xFFFF5722);

  /// 信息/标签
  static const Color info = Color(0xFF2196F3);

  // ===== 中性色 =====
  /// 主内容区背景
  static const Color background = Color(0xFFFAFAFA);

  /// 侧边栏背景
  static const Color sidebarBackground = Color(0xFFF5F5F5);

  /// 窄侧边栏背景
  static const Color narrowSidebarBackground = Color(0xFFEEEEEE);

  /// 卡片/弹窗背景
  static const Color cardBackground = Color(0xFFFFFFFF);

  /// 边框/分割线
  static const Color divider = Color(0xFFE0E0E0);

  /// 主要文字
  static const Color textPrimary = Color(0xFF333333);

  /// 次要文字（描述、时间）
  static const Color textSecondary = Color(0xFF666666);

  /// 禁用/占位文字
  static const Color textDisabled = Color(0xFF999999);

  /// 完成任务文字
  static const Color textCompleted = Color(0xFFBDBDBD);

  // ===== 优先级颜色 =====
  static const Color priorityHigh = Color(0xFFFF5722);
  static const Color priorityMedium = Color(0xFFFFA726);
  static const Color priorityLow = Color(0xFF42A5F5);
  static const Color priorityNone = Color(0xFF9E9E9E);

  // ===== 清单默认颜色 =====
  static const List<Color> listColors = [
    Color(0xFFF5A623), // 琥珀
    Color(0xFFE91E63), // 粉红
    Color(0xFF9C27B0), // 紫色
    Color(0xFF3F51B5), // 靛蓝
    Color(0xFF2196F3), // 蓝色
    Color(0xFF00BCD4), // 青色
    Color(0xFF4CAF50), // 绿色
    Color(0xFF8BC34A), // 浅绿
    Color(0xFFFF9800), // 橙色
    Color(0xFF795548), // 棕色
  ];
}
