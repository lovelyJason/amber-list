import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/constants.dart';
import '../../../core/utils/ui_utils.dart';

/// 侧边栏分组标题组件
/// 用于显示"清单"等分组标题，支持 hover 显示添加按钮
class SidebarSectionTitle extends StatelessWidget {
  /// 标题文本
  final String title;

  /// 是否处于 hover 状态
  final bool isHovered;

  /// 点击添加清单回调
  final VoidCallback onAddList;

  /// 点击添加文件夹回调
  final VoidCallback onAddFolder;

  const SidebarSectionTitle({
    super.key,
    required this.title,
    required this.isHovered,
    required this.onAddList,
    required this.onAddFolder,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AmberDimens.spacingMd,
        vertical: AmberDimens.spacingSm,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 20),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AmberColors.textDisabled,
              ),
            ),
            const Spacer(),
            Opacity(
              opacity: isHovered ? 1.0 : 0.0,
              child: SizedBox(
                width: 20,
                height: 20,
                child: InstantPopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    FluentIcons.add_12_regular,
                    size: 14,
                    color: AmberColors.textSecondary,
                  ),
                  tooltip: '新建',
                  splashRadius: 10,
                  offset: const Offset(0, 30),
                  onSelected: (value) {
                    if (value == 'list') {
                      onAddList();
                    } else if (value == 'folder') {
                      onAddFolder();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'list',
                      height: 32,
                      child: Row(
                        children: [
                          Icon(Icons.list_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('新建清单', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'folder',
                      height: 32,
                      child: Row(
                        children: [
                          Icon(Icons.folder_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('新建文件夹', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
