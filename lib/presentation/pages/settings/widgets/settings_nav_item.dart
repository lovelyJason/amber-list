import 'package:flutter/material.dart';
import '../../../../core/constants/constants.dart';

/// 设置页导航项（可复用组件）
class SettingsNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const SettingsNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<SettingsNavItem> createState() => _SettingsNavItemState();
}

class _SettingsNavItemState extends State<SettingsNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AmberDimens.spacingSm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AmberColors.primary.withOpacity(0.1)
                : (_isHovered ? AmberColors.cardBackground : Colors.transparent),
            borderRadius: BorderRadius.circular(AmberDimens.radiusSm),
            // 左侧选中指示器
            border: widget.isSelected
                ? const Border(
                    left: BorderSide(
                      color: AmberColors.primary,
                      width: 3,
                    ),
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AmberDimens.spacingMd,
              vertical: AmberDimens.spacingSm,
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 20,
                  color: widget.isSelected
                      ? AmberColors.primary
                      : AmberColors.textSecondary,
                ),
                const SizedBox(width: AmberDimens.spacingSm),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: widget.isSelected
                          ? AmberColors.primary
                          : AmberColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
