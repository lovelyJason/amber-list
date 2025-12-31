import 'package:flutter/material.dart';
import '../../../../core/constants/constants.dart';
import '../settings_tab_config.dart';
import 'settings_nav_item.dart';

/// 设置页左侧导航栏
class SettingsTabNavigator extends StatelessWidget {
  final List<SettingsTabConfig> tabs;
  final int currentIndex;
  final ValueChanged<int> onTabChanged;

  const SettingsTabNavigator({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      color: AmberColors.sidebarBackground,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: AmberDimens.spacingSm),
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final tab = tabs[index];
          return SettingsNavItem(
            icon: tab.type.icon,
            label: tab.type.displayName,
            isSelected: currentIndex == index,
            onTap: () => onTabChanged(index),
          );
        },
      ),
    );
  }
}
