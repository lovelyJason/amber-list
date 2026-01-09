import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';

/// 琥珀清单主题配置
class AmberTheme {
  AmberTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // 颜色方案
      colorScheme: ColorScheme.light(
        primary: AmberColors.primary,
        primaryContainer: AmberColors.primaryLight,
        secondary: AmberColors.primaryDark,
        surface: AmberColors.cardBackground,
        error: AmberColors.warning,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AmberColors.textPrimary,
        onError: Colors.white,
      ),

      // 脚手架背景
      scaffoldBackgroundColor: AmberColors.background,

      // 卡片主题
      cardTheme: CardThemeData(
        color: AmberColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
          side: BorderSide(color: AmberColors.divider, width: 1),
        ),
      ),

      // 分割线主题
      dividerTheme: const DividerThemeData(
        color: AmberColors.divider,
        thickness: 1,
        space: 1,
      ),

      // 图标主题
      iconTheme: const IconThemeData(
        color: AmberColors.textSecondary,
        size: AmberDimens.iconSizeMd,
      ),

      // 文本主题
      textTheme: const TextTheme(
        // 大标题
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AmberColors.textPrimary,
        ),
        // 中标题
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AmberColors.textPrimary,
        ),
        // 小标题
        headlineSmall: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AmberColors.textPrimary,
        ),
        // 正文大
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AmberColors.textPrimary,
        ),
        // 正文中
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AmberColors.textPrimary,
        ),
        // 正文小
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: AmberColors.textSecondary,
        ),
        // 标签
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AmberColors.textPrimary,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AmberColors.textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AmberColors.textDisabled,
        ),
      ),

      // 输入框主题
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AmberColors.cardBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AmberDimens.spacingMd,
          vertical: AmberDimens.spacingSm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
          borderSide: const BorderSide(color: AmberColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
          borderSide: const BorderSide(color: AmberColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
          borderSide: const BorderSide(color: AmberColors.primary, width: 2),
        ),
        hintStyle: const TextStyle(color: AmberColors.textDisabled),
      ),

      // 按钮主题
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AmberColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AmberDimens.spacingMd,
            vertical: AmberDimens.spacingSm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AmberColors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AmberDimens.spacingMd,
            vertical: AmberDimens.spacingSm,
          ),
        ),
      ),

      // 复选框主题
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AmberColors.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: AmberColors.divider, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AmberDimens.radiusSm),
        ),
      ),

      // 列表磁贴主题
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AmberDimens.spacingMd,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
        ),
        selectedTileColor: AmberColors.primaryLight,
        selectedColor: AmberColors.primary,
      ),

      // 浮动按钮主题
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AmberColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),

      // 弹窗主题
      dialogTheme: DialogThemeData(
        backgroundColor: AmberColors.cardBackground,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AmberDimens.radiusLg),
        ),
      ),

      // 日期选择器主题
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AmberColors.cardBackground,
        headerBackgroundColor: AmberColors.primary,
        headerForegroundColor: Colors.white,
        // 调小头部日期文字（默认太大）
        headerHeadlineStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        dayStyle: const TextStyle(fontSize: 14),
        yearStyle: const TextStyle(fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AmberDimens.radiusLg),
        ),
      ),

      // 菜单主题
      popupMenuTheme: PopupMenuThemeData(
        color: AmberColors.cardBackground,
        surfaceTintColor: Colors.transparent, // 移除 M3 默认的表面色调
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.2), // 更柔和的阴影
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFF0F0F0), width: 1), // 细微边框
        ),
        textStyle: const TextStyle(
          color: AmberColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        // 调整 item 高度? PopupMenuThemeData 不直接支持 itemPadding, 但可以通过 style 调整
      ),
    );
  }
}
