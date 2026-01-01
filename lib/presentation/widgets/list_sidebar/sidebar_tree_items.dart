import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/constants.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';
import 'sidebar_context_menu.dart';
import 'sidebar_models.dart';

/// 侧边栏树形项渲染器
/// 负责渲染清单和文件夹的树形列表项
class SidebarTreeItems {
  /// 构建树形项（可拖拽）
  static Widget buildTreeItem(
    BuildContext context,
    WidgetRef ref,
    SidebarTreeNode node,
    List<Task> allTasks,
    AppNavState navState, {
    required double indent,
  }) {
    final child = node.data.isFolder
        ? _buildFolderItem(context, ref, node, allTasks, navState, indent)
        : _buildListItem(
            context,
            ref,
            list: node.data,
            taskCount: allTasks
                .where((t) => t.listId == node.data.id && !t.isCompleted)
                .length,
            isSelected: navState.currentView == NavView.list &&
                navState.selectedListId == node.data.id,
            indent: indent,
          );

    return LongPressDraggable<TaskList>(
      data: node.data,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.8,
          child: SizedBox(
            width: 200,
            child: Card(
              child: ListTile(
                leading: Icon(
                  node.data.isFolder ? Icons.folder : Icons.list,
                  color: AmberColors.primary,
                ),
                title: Text(node.data.name),
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.5, child: child),
      child: child,
    );
  }

  /// 构建文件夹项（可展开，可接收拖拽）
  static Widget _buildFolderItem(
    BuildContext context,
    WidgetRef ref,
    SidebarTreeNode node,
    List<Task> allTasks,
    AppNavState navState,
    double indent,
  ) {
    return DragTarget<TaskList>(
      onWillAccept: (dragged) {
        if (dragged == null) return false;
        if (dragged.id == node.data.id) return false; // 不能拖到自己
        if (dragged.parentId == node.data.id) return false; // 已在此文件夹
        return true;
      },
      onAccept: (dragged) {
        ref.read(taskListProvider.notifier).moveList(dragged.id, node.data.id);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            border: isHovered
                ? Border.all(color: AmberColors.primary, width: 2)
                : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              hoverColor: Colors.transparent,
              listTileTheme: const ListTileThemeData(
                horizontalTitleGap: 0,
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            child: ExpansionTile(
              key: PageStorageKey('folder_${node.data.id}'),
              controlAffinity: ListTileControlAffinity.leading,
              title: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onSecondaryTapDown: (details) => SidebarContextMenu.show(
                  context,
                  ref,
                  details.globalPosition,
                  node.data,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_outlined,
                      size: 20,
                      color: AmberColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        node.data.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: AmberColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              leading: null,
              childrenPadding: EdgeInsets.zero,
              tilePadding: EdgeInsets.only(left: 8 + indent, right: 16),
              initiallyExpanded: true,
              collapsedIconColor: AmberColors.textSecondary,
              iconColor: AmberColors.textSecondary,
              children: node.children
                  .map(
                    (child) => buildTreeItem(
                      context,
                      ref,
                      child,
                      allTasks,
                      navState,
                      indent: indent + 16.0,
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  /// 构建清单项
  static Widget _buildListItem(
    BuildContext context,
    WidgetRef ref, {
    required TaskList list,
    required int taskCount,
    required bool isSelected,
    double indent = 0,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: indent + 8, right: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AmberColors.primary.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: GestureDetector(
          onSecondaryTapDown: (details) =>
              SidebarContextMenu.show(context, ref, details.globalPosition, list),
          child: ListTile(
            dense: true,
            selected: isSelected,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: list.color,
                shape: BoxShape.circle,
              ),
            ),
            title: Text(
              list.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: AmberColors.textPrimary,
              ),
            ),
            trailing: taskCount > 0
                ? Text(
                    '$taskCount',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AmberColors.textDisabled,
                    ),
                  )
                : null,
            onTap: () {
              ref
                  .read(appNavProvider.notifier)
                  .setView(NavView.list, listId: list.id);
            },
          ),
        ),
      ),
    );
  }
}
