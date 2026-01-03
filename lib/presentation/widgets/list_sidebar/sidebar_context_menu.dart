import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/constants.dart';
import '../../../core/utils/ui_utils.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';
import 'sidebar_dialogs.dart';
import 'sidebar_sticky_note.dart';

/// 侧边栏右键菜单
/// 处理清单和文件夹的右键上下文菜单
class SidebarContextMenu {
  /// 显示清单/文件夹右键菜单
  static void show(
    BuildContext context,
    WidgetRef ref,
    Offset position,
    TaskList list,
  ) {
    showInstantMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        MediaQuery.of(context).size.width - position.dx,
        MediaQuery.of(context).size.height - position.dy,
      ),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: <PopupMenuEntry<String>>[
        // 文件夹特有选项
        if (list.isFolder) ...[
          PopupMenuItem<String>(
            value: 'add_list',
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onTap: () {
              Future.delayed(Duration.zero, () {
                SidebarDialogs.showCreateDialog(
                  context,
                  ref,
                  isFolder: false,
                  allLists: ref.read(taskListProvider),
                  parentId: list.id,
                );
              });
            },
            child: const Row(
              children: [
                Icon(Icons.add, size: 16, color: AmberColors.textPrimary),
                SizedBox(width: 8),
                Text(
                  '添加清单',
                  style: TextStyle(
                    fontSize: 13,
                    color: AmberColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'add_folder',
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onTap: () {
              Future.delayed(Duration.zero, () {
                SidebarDialogs.showCreateDialog(
                  context,
                  ref,
                  isFolder: true,
                  allLists: ref.read(taskListProvider),
                  parentId: list.id,
                );
              });
            },
            child: const Row(
              children: [
                Icon(
                  Icons.create_new_folder_outlined,
                  size: 16,
                  color: AmberColors.textPrimary,
                ),
                SizedBox(width: 8),
                Text(
                  '添加文件夹',
                  style: TextStyle(
                    fontSize: 13,
                    color: AmberColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),
        ],

        // 通用选项
        PopupMenuItem<String>(
          value: 'edit',
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onTap: () {
            Future.delayed(Duration.zero, () {
              SidebarDialogs.showRenameDialog(context, ref, list);
            });
          },
          child: const Row(
            children: [
              Icon(
                Icons.edit_outlined,
                size: 16,
                color: AmberColors.textPrimary,
              ),
              SizedBox(width: 8),
              Text(
                '编辑',
                style: TextStyle(fontSize: 13, color: AmberColors.textPrimary),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'pin',
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onTap: () {
            ref.read(taskListProvider.notifier).pinList(list.id);
          },
          child: const Row(
            children: [
              Icon(
                Icons.push_pin_outlined,
                size: 16,
                color: AmberColors.textPrimary,
              ),
              SizedBox(width: 8),
              Text(
                '置顶',
                style: TextStyle(fontSize: 13, color: AmberColors.textPrimary),
              ),
            ],
          ),
        ),

        PopupMenuItem<String>(
          value: 'tags',
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onTap: () {
            Future.delayed(Duration.zero, () {
              SidebarDialogs.showListTagsDialog(context, ref, list);
            });
          },
          child: const Row(
            children: [
              Icon(
                Icons.label_outline,
                size: 16,
                color: AmberColors.textPrimary,
              ),
              SizedBox(width: 8),
              Text(
                '标签',
                style: TextStyle(fontSize: 13, color: AmberColors.textPrimary),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'move_to',
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onTap: () {
            Future.delayed(Duration.zero, () {
              SidebarDialogs.showMoveListDialog(context, ref, list);
            });
          },
          child: const Row(
            children: [
              Icon(
                Icons.drive_file_move_outline,
                size: 16,
                color: AmberColors.textPrimary,
              ),
              SizedBox(width: 8),
              Text(
                '移动到...',
                style: TextStyle(fontSize: 13, color: AmberColors.textPrimary),
              ),
            ],
          ),
        ),

        // 清单特有选项：打开便签
        if (!list.isFolder)
          PopupMenuItem<String>(
            value: 'open_note',
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onTap: () {
              Future.delayed(Duration.zero, () {
                SidebarStickyNote.showWindow(context, ref, list);
              });
            },
            child: const Row(
              children: [
                Icon(
                  Icons.note_alt_outlined,
                  size: 16,
                  color: AmberColors.textPrimary,
                ),
                SizedBox(width: 8),
                Text(
                  '打开便签',
                  style: TextStyle(
                    fontSize: 13,
                    color: AmberColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

        const PopupMenuDivider(height: 1),

        // 删除/解散选项
        if (list.isFolder)
          PopupMenuItem<String>(
            value: 'disband',
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onTap: () {
              Future.delayed(Duration.zero, () {
                SidebarDialogs.showDisbandConfirm(context, ref, list);
              });
            },
            child: const Row(
              children: [
                Icon(Icons.folder_off_outlined, size: 16, color: Colors.red),
                SizedBox(width: 8),
                Text('解散', style: TextStyle(color: Colors.red, fontSize: 13)),
              ],
            ),
          )
        else
          PopupMenuItem<String>(
            value: 'delete',
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onTap: () {
              Future.delayed(Duration.zero, () {
                SidebarDialogs.showDeleteConfirm(context, ref, list);
              });
            },
            child: const Row(
              children: [
                Icon(Icons.delete_outline, size: 16, color: Colors.red),
                SizedBox(width: 8),
                Text('删除', style: TextStyle(color: Colors.red, fontSize: 13)),
              ],
            ),
          ),
      ],
    );
  }
}
