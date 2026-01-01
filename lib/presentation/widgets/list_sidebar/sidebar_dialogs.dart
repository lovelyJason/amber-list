import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/constants.dart';
import '../../../core/utils/sound_service.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';

/// 侧边栏对话框集合
/// 包含创建/重命名/删除清单和文件夹等操作的对话框
class SidebarDialogs {
  /// 显示创建清单/文件夹对话框
  static void showCreateDialog(
    BuildContext context,
    WidgetRef ref, {
    required bool isFolder,
    required List<TaskList> allLists,
    String? parentId,
  }) {
    final controller = TextEditingController();
    Color selectedColor = AmberColors.primary;
    String? selectedParentId = parentId;

    // 筛选出所有文件夹供选择
    final folders = allLists.where((l) => l.isFolder).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isFolder ? '新建文件夹' : '新建清单'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: isFolder ? '文件夹名称' : '清单名称',
                  labelText: '名称',
                ),
              ),
              const SizedBox(height: AmberDimens.spacingMd),

              // 父级与位置选择 (Dropdown)
              if (folders.isNotEmpty) ...[
                const Text(
                  '位置',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: selectedParentId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('根目录 (Root)'),
                    ),
                    ...folders.map(
                      (f) => DropdownMenuItem(
                        value: f.id,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.folder_open,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(f.name),
                          ],
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() => selectedParentId = val);
                  },
                ),
                const SizedBox(height: AmberDimens.spacingMd),
              ],

              // 颜色选择 (仅清单需要)
              if (!isFolder) ...[
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
                  if (isFolder) {
                    ref.read(taskListProvider.notifier).createFolder(
                          controller.text.trim(),
                          parentId: selectedParentId,
                        );
                  } else {
                    ref.read(taskListProvider.notifier).addList(
                          controller.text.trim(),
                          selectedColor,
                          parentId: selectedParentId,
                        );
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示重命名对话框
  static void showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    TaskList list,
  ) {
    final controller = TextEditingController(text: list.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(list.isFolder ? '重命名文件夹' : '重命名清单'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '名称'),
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
                    .read(taskListProvider.notifier)
                    .renameList(list.id, controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 显示解散文件夹确认对话框
  static void showDisbandConfirm(
    BuildContext context,
    WidgetRef ref,
    TaskList folder,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解散文件夹?'),
        content: const Text('文件夹将被删除，其中的清单将移至上一级目录。此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              ref.read(taskListProvider.notifier).disbandFolder(folder.id);
              Navigator.pop(context);
            },
            child: const Text('解散'),
          ),
        ],
      ),
    );
  }

  /// 显示删除清单确认对话框
  static void showDeleteConfirm(
    BuildContext context,
    WidgetRef ref,
    TaskList list,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除清单?'),
        content: const Text('清单及其中的任务将被永久删除。此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              ref.read(soundServiceProvider).playDelete();
              ref.read(taskListProvider.notifier).deleteList(list.id);
              Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 显示清单标签管理对话框
  static void showListTagsDialog(
    BuildContext context,
    WidgetRef ref,
    TaskList list,
  ) {
    final allTags = ref.read(tagsProvider);
    final selectedTags = List<String>.from(list.tags);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('管理标签'),
            content: SizedBox(
              width: 300,
              child: allTags.isEmpty
                  ? const Center(child: Text('暂无标签，请先在侧边栏添加标签'))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allTags.map((tag) {
                        final isSelectedByName = selectedTags.contains(tag.name);
                        final tagColor = tag.color;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelectedByName) {
                                selectedTags.remove(tag.name);
                              } else {
                                selectedTags.add(tag.name);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isSelectedByName
                                  ? tagColor.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isSelectedByName
                                    ? tagColor.withOpacity(0.3)
                                    : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              tag.name,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelectedByName
                                    ? tagColor
                                    : AmberColors.textSecondary,
                                fontWeight: isSelectedByName
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  ref
                      .read(taskListProvider.notifier)
                      .updateList(list.copyWith(tags: selectedTags));
                  Navigator.pop(context);
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 显示移动清单对话框
  static void showMoveListDialog(
    BuildContext context,
    WidgetRef ref,
    TaskList list,
  ) {
    final allLists = ref.read(taskListProvider);
    final folders =
        allLists.where((l) => l.isFolder && l.id != list.id).toList();
    String? selectedParentId = list.parentId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('移动到'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('选择目标文件夹：'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                value: selectedParentId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('根目录 (Root)'),
                  ),
                  ...folders.map(
                    (f) => DropdownMenuItem(value: f.id, child: Text(f.name)),
                  ),
                ],
                onChanged: (val) {
                  setState(() => selectedParentId = val);
                },
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
                ref
                    .read(taskListProvider.notifier)
                    .moveList(list.id, selectedParentId);
                Navigator.pop(context);
              },
              child: const Text('移动'),
            ),
          ],
        ),
      ),
    );
  }
}
