import 'package:flutter/material.dart';
import '../../../../core/constants/constants.dart';

/// 设置项组件
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AmberColors.primary),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: AmberColors.textSecondary,
        ),
      ),
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }
}
