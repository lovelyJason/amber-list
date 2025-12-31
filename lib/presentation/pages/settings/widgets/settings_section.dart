import 'package:flutter/material.dart';
import '../../../../core/constants/constants.dart';

/// 设置区域容器（带标题）
class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AmberDimens.spacingSm,
            vertical: AmberDimens.spacingSm,
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AmberColors.textDisabled,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AmberColors.cardBackground,
            borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
            border: Border.all(color: AmberColors.divider),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}
