import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/constants.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';

/// 侧边栏标签相关组件
/// 包含标签头部、标签项、标签对话框等
class SidebarTags {
  /// 构建标签头部
  static Widget buildTagsHeader(
    BuildContext context,
    WidgetRef ref, {
    required int tagFilterMode,
    required ValueChanged<int> onFilterModeChanged,
    required VoidCallback onAddTag,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AmberDimens.spacingMd,
        AmberDimens.spacingSm,
        AmberDimens.spacingXs,
        AmberDimens.spacingSm,
      ),
      child: Row(
        children: [
          const Text(
            '标签',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AmberColors.textDisabled,
            ),
          ),
          const Spacer(),
          // 添加标签按钮
          SizedBox(
            width: 24,
            height: 24,
            child: IconButton(
              onPressed: onAddTag,
              icon: const Icon(FluentIcons.add_12_regular, size: 16),
              padding: EdgeInsets.zero,
              tooltip: '添加标签',
              style: IconButton.styleFrom(
                foregroundColor: AmberColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // 更多选项按钮
          SizedBox(
            width: 24,
            height: 24,
            child: PopupMenuButton<int>(
              padding: EdgeInsets.zero,
              icon: const Icon(
                FluentIcons.more_horizontal_16_regular,
                size: 16,
                color: AmberColors.textSecondary,
              ),
              tooltip: '标签选项',
              onSelected: onFilterModeChanged,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 1,
                  height: 32,
                  child: Row(
                    children: [
                      if (tagFilterMode == 1)
                        const Icon(FluentIcons.checkmark_12_regular, size: 14)
                      else
                        const SizedBox(width: 14),
                      const SizedBox(width: 8),
                      const Text('有内容时显示', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 0,
                  height: 32,
                  child: Row(
                    children: [
                      if (tagFilterMode == 0)
                        const Icon(FluentIcons.checkmark_12_regular, size: 14)
                      else
                        const SizedBox(width: 14),
                      const SizedBox(width: 8),
                      const Text('显示', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建内联标签项
  static Widget buildInlineTagItem(
    BuildContext context,
    WidgetRef ref,
    Tag tag,
    int count, {
    required VoidCallback onTap,
    required void Function(TapDownDetails) onSecondaryTapDown,
  }) {
    return InkWell(
      onTap: onTap,
      onSecondaryTapDown: onSecondaryTapDown,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: tag.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: tag.color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tag.name,
              style: const TextStyle(
                fontSize: 12,
                color: AmberColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  color: AmberColors.textDisabled,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 显示添加标签对话框
  static void showAddTagDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    Color selectedColor = AmberColors.listColors[0];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('添加标签'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '标签名称',
                    hintText: '例如：工作、生活',
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '颜色',
                  style: TextStyle(
                    fontSize: 14,
                    color: AmberColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: AmberColors.listColors.map((color) {
                    final isSelected = selectedColor.value == color.value;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedColor = color;
                        });
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AmberColors.textPrimary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Center(
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    ref
                        .read(tagsProvider.notifier)
                        .addTag(controller.text.trim(), selectedColor);
                    Navigator.pop(context);
                  }
                },
                child: const Text('添加'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 显示编辑标签对话框
  static void showEditTagDialog(BuildContext context, WidgetRef ref, Tag tag) {
    final controller = TextEditingController(text: tag.name);
    Color selectedColor = tag.color;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('编辑标签'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: '名称'),
              ),
              const SizedBox(height: AmberDimens.spacingMd),
              const Text(
                '颜色',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: AmberDimens.spacingSm,
                children: AmberColors.listColors.map((color) {
                  return GestureDetector(
                    onTap: () => setState(() => selectedColor = color),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selectedColor == color
                            ? Border.all(
                                color: AmberColors.textPrimary,
                                width: 2,
                              )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  ref.read(tagsProvider.notifier).updateTag(
                        tag.copyWith(
                          name: controller.text.trim(),
                          color: selectedColor,
                        ),
                        tag.name,
                      );
                  Navigator.pop(context);
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示删除标签确认对话框
  static void showDeleteTagDialog(BuildContext context, WidgetRef ref, Tag tag) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除标签？'),
        content: Text('确认要删除标签"${tag.name}"吗？此操作将从所有通过该标签关联的任务中移除它。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(tagsProvider.notifier).deleteTag(tag.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 显示标签右键菜单
  static void showTagContextMenu(
    BuildContext context,
    WidgetRef ref,
    Offset position,
    Tag tag,
  ) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          height: 32,
          onTap: () {
            Future.delayed(
              Duration.zero,
              () => showEditTagDialog(context, ref, tag),
            );
          },
          child: const Row(
            children: [
              Icon(Icons.edit_outlined, size: 16),
              SizedBox(width: 8),
              Text('编辑', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          height: 32,
          onTap: () {
            Future.delayed(
              Duration.zero,
              () => showDeleteTagDialog(context, ref, tag),
            );
          },
          child: const Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text('删除', style: TextStyle(fontSize: 13, color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }
}
