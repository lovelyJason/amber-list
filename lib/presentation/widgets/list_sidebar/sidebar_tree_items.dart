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
  ///
  /// [inDrawer] 为 true 时，点击后会自动关闭抽屉
  static Widget buildTreeItem(
    BuildContext context,
    WidgetRef ref,
    SidebarTreeNode node,
    List<Task> allTasks,
    AppNavState navState, {
    required double indent,
    bool inDrawer = false,
  }) {
    final child = node.data.isFolder
        ? _buildFolderItem(context, ref, node, allTasks, navState, indent, inDrawer)
        : _buildListItem(
            context,
            ref,
            list: node.data,
            // 统计未完成且不在垃圾桶中的任务数量
            taskCount: allTasks
                .where((t) => t.listId == node.data.id && !t.isCompleted && !t.isDeleted)
                .length,
            isSelected: navState.currentView == NavView.list &&
                navState.selectedListId == node.data.id,
            indent: indent,
            inDrawer: inDrawer,
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
    bool inDrawer,
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
              // 压缩 ExpansionTile 内部 ListTile 的高度
              listTileTheme: const ListTileThemeData(
                dense: true,
                visualDensity: VisualDensity(vertical: -4), // 最紧凑
                horizontalTitleGap: 4, // 箭头和标题之间的间距
                minVerticalPadding: 0,
                contentPadding: EdgeInsets.zero,
              ),
              // 控制默认展开箭头的大小
              iconTheme: const IconThemeData(
                size: 18, // 箭头大小
              ),
            ),
            child: _ExpandableFolderTile(
              nodeData: node.data,
              indent: indent,
              onSecondaryTap: (details) => SidebarContextMenu.show(
                context,
                ref,
                details.globalPosition,
                node.data,
              ),
              children: node.children
                  .map(
                    (child) => buildTreeItem(
                      context,
                      ref,
                      child,
                      allTasks,
                      navState,
                      indent: indent + 20.0,
                      inDrawer: inDrawer,
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  /// 清单项高度（可灵活调整），32px - 当前值，比较紧凑
  /// 28px - 更紧凑
  /// 36px - 稍微宽松点
  /// 40px - 常规高度
  static const double _listItemHeight = 38.0;

  /// 构建清单项
  /// 使用自定义布局代替 ListTile，实现精确的高度控制
  static Widget _buildListItem(
    BuildContext context,
    WidgetRef ref, {
    required TaskList list,
    required int taskCount,
    required bool isSelected,
    double indent = 0,
    bool inDrawer = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: indent + 8, right: 8),
      child: GestureDetector(
        onSecondaryTapDown: (details) =>
            SidebarContextMenu.show(context, ref, details.globalPosition, list),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              ref
                  .read(appNavProvider.notifier)
                  .setView(NavView.list, listId: list.id);
              // 抽屉模式下点击后关闭抽屉
              if (inDrawer) {
                Navigator.of(context).pop();
              }
            },
            child: Container(
              height: _listItemHeight, // 精确控制高度
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AmberColors.primary.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  // 颜色圆点
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: list.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 清单名称
                  Expanded(
                    child: Text(
                      list.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: AmberColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 任务数量
                  if (taskCount > 0)
                    Text(
                      '$taskCount',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AmberColors.textDisabled,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 自定义可展开文件夹组件
/// 实现收起时箭头朝右(>)，展开时箭头朝下(v)的效果
class _ExpandableFolderTile extends StatefulWidget {
  final TaskList nodeData;
  final double indent;
  final void Function(TapDownDetails) onSecondaryTap;
  final List<Widget> children;

  const _ExpandableFolderTile({
    required this.nodeData,
    required this.indent,
    required this.onSecondaryTap,
    required this.children,
  });

  @override
  State<_ExpandableFolderTile> createState() => _ExpandableFolderTileState();
}

class _ExpandableFolderTileState extends State<_ExpandableFolderTile>
    with SingleTickerProviderStateMixin {
  /// 是否展开（默认收起）
  bool _isExpanded = false;

  /// 箭头旋转动画控制器
  late AnimationController _animationController;

  /// 箭头旋转动画（0度到90度）
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    // 从 0 到 0.25 turns (90度)
    _rotationAnimation = Tween<double>(begin: 0, end: 0.25).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    // 初始展开状态
    if (_isExpanded) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 文件夹标题行
        GestureDetector(
          onSecondaryTapDown: widget.onSecondaryTap,
          child: InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: SidebarTreeItems._listItemHeight,
              padding: EdgeInsets.only(left: 12 + widget.indent, right: 8),
              child: Row(
                children: [
                  // 旋转箭头：收起朝右(>)，展开朝下(v)
                  RotationTransition(
                    turns: _rotationAnimation,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AmberColors.textDisabled.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 2),
                  // 文件夹图标（简洁空心风格）
                  const Icon(
                    Icons.folder_open_outlined,
                    size: 18,
                    color: AmberColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  // 文件夹名称
                  Expanded(
                    child: Text(
                      widget.nodeData.name,
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
          ),
        ),
        // 子项列表（无动画，直接显示/隐藏）
        if (_isExpanded) Column(children: widget.children),
      ],
    );
  }
}
