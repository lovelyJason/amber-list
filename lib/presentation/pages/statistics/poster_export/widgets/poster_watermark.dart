import 'package:flutter/material.dart';

import '../../../../../core/constants/constants.dart';

/// 海报底部水印组件
///
/// 显示琥珀清单 Logo 和品牌名
/// 水印颜色自适应，支持浅色和深色背景
class PosterWatermark extends StatelessWidget {
  /// 文字颜色（默认半透明白色）
  final Color? textColor;

  /// 是否使用深色文字（用于浅色背景）
  final bool useDarkText;

  const PosterWatermark({
    super.key,
    this.textColor,
    this.useDarkText = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = textColor ??
        (useDarkText
            ? AmberColors.textSecondary
            : Colors.white.withValues(alpha: 0.8));

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo 图标
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AmberColors.primary, AmberColors.primaryDark],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Center(
            child: Text(
              '琥',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // 应用名称
        Text(
          '琥珀清单',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: color,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}
