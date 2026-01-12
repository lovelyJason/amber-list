import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/constants.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';
import 'sidebar_context_menu.dart';
import 'sidebar_models.dart';

/// 侧边栏树形项渲染器
/// 负责渲染清单和文件夹的树形列表项，支持拖拽排序
class SidebarTreeItems {
  /// 清单项高度
  static const double listItemHeight = 38.0;

  /// 构建树形项（可拖拽排序）
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
    return _DraggableTreeItem(
      node: node,
      allTasks: allTasks,
      navState: navState,
      indent: indent,
      inDrawer: inDrawer,
    );
  }
}

/// 可拖拽的树形项组件
/// 支持：
/// 1. 长按拖拽
/// 2. 拖拽到项目上方/下方插入（显示插入线）
/// 3. 拖拽到文件夹上移入文件夹（高亮边框）
class _DraggableTreeItem extends ConsumerStatefulWidget {
  final SidebarTreeNode node;
  final List<Task> allTasks;
  final AppNavState navState;
  final double indent;
  final bool inDrawer;

  const _DraggableTreeItem({
    required this.node,
    required this.allTasks,
    required this.navState,
    required this.indent,
    required this.inDrawer,
  });

  @override
  ConsumerState<_DraggableTreeItem> createState() => _DraggableTreeItemState();
}

class _DraggableTreeItemState extends ConsumerState<_DraggableTreeItem> {
  /// 拖拽悬停位置：null=无, true=上方, false=下方
  bool? _hoverPosition;

  /// 是否悬停在文件夹上（准备移入）
  bool _hoverOnFolder = false;

  /// 清理悬停状态
  void _clearHoverState() {
    if (mounted) {
      setState(() {
        _hoverPosition = null;
        _hoverOnFolder = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final isFolder = node.data.isFolder;

    // 构建基础内容
    final content = isFolder
        ? _buildFolderContent()
        : _buildListContent();

    // 根据平台选择拖拽方式：
    // - 桌面端（macOS/Windows/Linux）：直接拖拽，鼠标体验更好
    // - 移动端（iOS/Android）：长按拖拽，避免与滚动冲突
    final isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;

    if (isDesktop) {
      return Draggable<TaskList>(
        data: node.data,
        feedback: _buildDragFeedback(),
        childWhenDragging: Opacity(opacity: 0.3, child: content),
        dragAnchorStrategy: pointerDragAnchorStrategy,
        onDragEnd: (_) => _clearHoverState(),
        onDraggableCanceled: (_, __) => _clearHoverState(),
        child: _buildDragTarget(content),
      );
    } else {
      return LongPressDraggable<TaskList>(
        data: node.data,
        feedback: _buildDragFeedback(),
        childWhenDragging: Opacity(opacity: 0.3, child: content),
        onDragEnd: (_) => _clearHoverState(),
        onDraggableCanceled: (_, __) => _clearHoverState(),
        child: _buildDragTarget(content),
      );
    }
  }

  /// 构建拖拽预览
  Widget _buildDragFeedback() {
    return Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: 0.9,
        child: SizedBox(
          width: 180,
          child: Card(
            elevation: 8,
            color: AmberColors.sidebarBackground,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.node.data.isFolder ? Icons.folder : Icons.list,
                    color: widget.node.data.isFolder
                        ? AmberColors.textSecondary
                        : widget.node.data.color,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.node.data.name,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
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

  /// 构建拖拽目标（检测放置位置）
  Widget _buildDragTarget(Widget content) {
    return DragTarget<TaskList>(
      onWillAcceptWithDetails: (details) {
        final dragged = details.data;
        // 不能拖到自己
        if (dragged.id == widget.node.data.id) return false;
        // 不能将文件夹拖入自己的子级（防止循环）
        if (_isDescendant(dragged.id, widget.node.data.id)) return false;
        return true;
      },
      onMove: (details) {
        // 根据鼠标位置判断是插入上方、下方还是移入文件夹
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null) return;

        final localPosition = renderBox.globalToLocal(details.offset);
        final height = renderBox.size.height;

        setState(() {
          if (widget.node.data.isFolder) {
            // 文件夹：上1/4=上方插入，中间1/2=移入，下1/4=下方插入
            if (localPosition.dy < height * 0.25) {
              _hoverPosition = true; // 上方
              _hoverOnFolder = false;
            } else if (localPosition.dy > height * 0.75) {
              _hoverPosition = false; // 下方
              _hoverOnFolder = false;
            } else {
              _hoverPosition = null;
              _hoverOnFolder = true; // 移入文件夹
            }
          } else {
            // 清单：上半部分=上方插入，下半部分=下方插入
            _hoverPosition = localPosition.dy < height / 2;
            _hoverOnFolder = false;
          }
        });
      },
      onLeave: (_) {
        setState(() {
          _hoverPosition = null;
          _hoverOnFolder = false;
        });
      },
      onAcceptWithDetails: (details) {
        final dragged = details.data;

        if (_hoverOnFolder && widget.node.data.isFolder) {
          final targetFolderId = widget.node.data.id;

          // 移入文件夹
          ref.read(taskListProvider.notifier).moveList(
                dragged.id,
                targetFolderId,
              );

          // 自动展开目标文件夹及其所有祖先
          // 使用 Provider 管理状态，不受 Widget rebuild 影响
          ref.read(folderExpandProvider.notifier).expandWithAncestors(
                targetFolderId,
              );
        } else if (_hoverPosition != null) {
          // 排序插入
          ref.read(taskListProvider.notifier).reorderList(
                draggedId: dragged.id,
                targetId: widget.node.data.id,
                insertBefore: _hoverPosition!,
              );
        }

        setState(() {
          _hoverPosition = null;
          _hoverOnFolder = false;
        });
      },
      builder: (context, candidateData, rejectedData) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 上方插入线
            if (_hoverPosition == true) _buildInsertLine(),
            // 主内容（文件夹时可能有高亮边框）
            Container(
              decoration: _hoverOnFolder
                  ? BoxDecoration(
                      border: Border.all(color: AmberColors.primary, width: 2),
                      borderRadius: BorderRadius.circular(6),
                    )
                  : null,
              child: content,
            ),
            // 下方插入线
            if (_hoverPosition == false) _buildInsertLine(),
          ],
        );
      },
    );
  }

  /// 构建插入线指示器
  Widget _buildInsertLine() {
    return Container(
      height: 2,
      margin: EdgeInsets.only(left: widget.indent + 16, right: 16),
      decoration: BoxDecoration(
        color: AmberColors.primary,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  /// 检查 ancestorId 是否是 nodeId 的祖先
  /// 用于防止将文件夹拖入自己的子级形成循环
  bool _isDescendant(String ancestorId, String nodeId) {
    final allLists = ref.read(taskListProvider);
    String? currentId = nodeId;

    while (currentId != null) {
      final current = allLists.firstWhere(
        (l) => l.id == currentId,
        orElse: () => TaskList(
          id: '',
          name: '',
          icon: Icons.list,
          color: Colors.grey,
          sortOrder: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (current.id.isEmpty) break;
      if (current.parentId == ancestorId) return true;
      currentId = current.parentId;
    }
    return false;
  }

  /// 构建文件夹内容
  Widget _buildFolderContent() {
    return _ExpandableFolderTile(
      nodeData: widget.node.data,
      indent: widget.indent,
      onSecondaryTap: (details) => SidebarContextMenu.show(
        context,
        ref,
        details.globalPosition,
        widget.node.data,
      ),
      children: widget.node.children
          .map(
            (child) => SidebarTreeItems.buildTreeItem(
              context,
              ref,
              child,
              widget.allTasks,
              widget.navState,
              indent: widget.indent + 20.0,
              inDrawer: widget.inDrawer,
            ),
          )
          .toList(),
    );
  }

  /// 构建清单内容
  Widget _buildListContent() {
    final list = widget.node.data;
    final taskCount = widget.allTasks
        .where((t) => t.listId == list.id && !t.isCompleted && !t.isDeleted)
        .length;
    final isSelected = widget.navState.currentView == NavView.list &&
        widget.navState.selectedListId == list.id;

    return Padding(
      padding: EdgeInsets.only(left: widget.indent + 8, right: 8),
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
              if (widget.inDrawer) {
                Navigator.of(context).pop();
              }
            },
            child: Container(
              height: SidebarTreeItems.listItemHeight,
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
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
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
///
/// 使用 folderExpandProvider 管理展开状态，解决拖拽后自动展开失效的问题
/// （之前用组件内部状态，Widget rebuild 后状态丢失）
class _ExpandableFolderTile extends ConsumerStatefulWidget {
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
  ConsumerState<_ExpandableFolderTile> createState() =>
      _ExpandableFolderTileState();
}

class _ExpandableFolderTileState extends ConsumerState<_ExpandableFolderTile>
    with SingleTickerProviderStateMixin {
  /// 箭头旋转动画控制器
  late AnimationController _animationController;

  /// 箭头旋转动画（0度到90度）
  late Animation<double> _rotationAnimation;

  /// 缓存上次展开状态，用于检测变化
  bool _lastExpandedState = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0.25).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // 初始化动画状态（从 Provider 读取）
    // 注意：initState 不能用 ref.watch，用 WidgetsBinding 延迟读取
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isExpanded =
          ref.read(folderExpandProvider).contains(widget.nodeData.id);
      if (isExpanded) {
        _animationController.value = 1.0;
      }
      _lastExpandedState = isExpanded;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 切换展开状态
  void _toggleExpanded() {
    ref.read(folderExpandProvider.notifier).toggle(widget.nodeData.id);
  }

  @override
  Widget build(BuildContext context) {
    // 从 Provider 读取展开状态
    final isExpanded =
        ref.watch(folderExpandProvider).contains(widget.nodeData.id);

    // 检测状态变化，驱动动画
    if (isExpanded != _lastExpandedState) {
      _lastExpandedState = isExpanded;
      if (isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }

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
              height: SidebarTreeItems.listItemHeight,
              padding: EdgeInsets.only(left: 12 + widget.indent, right: 8),
              child: Row(
                children: [
                  // 旋转箭头
                  RotationTransition(
                    turns: _rotationAnimation,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AmberColors.textDisabled.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 2),
                  // 文件夹图标
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
        // 子项列表
        if (isExpanded) Column(children: widget.children),
      ],
    );
  }
}
