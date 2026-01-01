import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/constants/constants.dart';
import '../../../core/utils/trash_animation_service.dart';
import '../../../core/utils/ui_utils.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';
import 'sidebar_dialogs.dart';
import 'sidebar_section_title.dart';
import 'sidebar_smart_lists.dart';
import 'sidebar_tags.dart';
import 'sidebar_tree_builder.dart';
import 'sidebar_tree_items.dart';

export 'sidebar_models.dart';

/// 清单侧边栏
/// 主入口组件，组合所有子模块
///
/// 支持两种模式：
/// - 桌面端：固定宽度220px，作为侧边栏
/// - 移动端：自适应宽度，嵌入抽屉中
class ListSidebar extends ConsumerStatefulWidget {
  /// 是否嵌入抽屉中（移动端模式）
  /// 为true时宽度自适应，为false时使用固定宽度
  final bool inDrawer;

  const ListSidebar({super.key, this.inDrawer = false});

  @override
  ConsumerState<ListSidebar> createState() => _ListSidebarState();
}

class _ListSidebarState extends ConsumerState<ListSidebar> {
  /// 标签显示模式：0=显示, 1=有内容时显示
  int _tagFilterMode = 0;

  /// 清单分组的 hover 状态
  bool _isListsHovered = false;

  @override
  Widget build(BuildContext context) {
    final taskLists = ref.watch(taskListProvider);
    final navState = ref.watch(appNavProvider);
    final tasks = ref.watch(taskProvider);
    final tags = ref.watch(tagsProvider);

    // 构建树形结构
    final tree = SidebarTreeBuilder.buildTree(taskLists);

    return Container(
      // 抽屉模式下自适应宽度，桌面端固定宽度
      width: widget.inDrawer ? null : AmberDimens.listSidebarWidth,
      color: AmberColors.sidebarBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部标题栏（抽屉模式下隐藏，因为 DrawerListSidebar 已有头部）
          if (!widget.inDrawer) ...[
            _buildHeader(context, taskLists),
            const Divider(height: 1),
          ],
          // 清单列表
          Expanded(
            child: ScrollConfiguration(
              behavior:
                  ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: AmberDimens.spacingSm,
                ),
                children: [
                  // 智能清单
                  _buildSmartLists(navState),
                  const SizedBox(height: AmberDimens.spacingMd),

                  // 清单分组
                  _buildListsSection(taskLists, tree, tasks, navState),
                  const SizedBox(height: AmberDimens.spacingMd),

                  // 标签分组
                  _buildTagsSection(tasks, tags),
                  const SizedBox(height: AmberDimens.spacingMd),
                  const Divider(height: 1),
                  const SizedBox(height: AmberDimens.spacingMd),

                  // 已完成 & 垃圾桶
                  _buildBottomLists(navState),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建头部标题栏
  Widget _buildHeader(BuildContext context, List<TaskList> taskLists) {
    return DragToMoveArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AmberDimens.spacingMd,
          vertical: 8,
        ),
        child: Row(
          children: [
            const Text(
              '琥珀清单',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AmberColors.textPrimary,
              ),
            ),
            const Spacer(),
            // 新建按钮菜单
            InstantPopupMenuButton<String>(
              icon: const Icon(Icons.add, size: 20),
              tooltip: '新建',
              splashRadius: 18,
              offset: const Offset(0, 30),
              onSelected: (value) {
                if (value == 'list') {
                  SidebarDialogs.showCreateDialog(
                    context,
                    ref,
                    isFolder: false,
                    allLists: taskLists,
                  );
                } else if (value == 'folder') {
                  SidebarDialogs.showCreateDialog(
                    context,
                    ref,
                    isFolder: true,
                    allLists: taskLists,
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'list',
                  child: Row(
                    children: [
                      Icon(Icons.list_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('新建清单'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'folder',
                  child: Row(
                    children: [
                      Icon(Icons.folder_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('新建文件夹'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建智能清单（收集箱、今天、最近7天）
  Widget _buildSmartLists(AppNavState navState) {
    return Column(
      children: [
        SidebarSmartLists.buildSmartListItem(
          context,
          ref,
          icon: navState.currentView == NavView.inbox
              ? FluentIcons.mail_inbox_24_filled
              : FluentIcons.mail_inbox_24_regular,
          title: '收集箱',
          view: NavView.inbox,
          isSelected: navState.currentView == NavView.inbox,
          inDrawer: widget.inDrawer,
        ),
        SidebarSmartLists.buildSmartListItem(
          context,
          ref,
          customIcon:
              SidebarSmartLists.buildTodayIcon(navState.currentView == NavView.today),
          title: '今天',
          view: NavView.today,
          isSelected: navState.currentView == NavView.today,
          inDrawer: widget.inDrawer,
        ),
        SidebarSmartLists.buildSmartListItem(
          context,
          ref,
          customIcon: SidebarSmartLists.buildUpcomingIcon(
              navState.currentView == NavView.upcoming),
          title: '最近7天',
          view: NavView.upcoming,
          isSelected: navState.currentView == NavView.upcoming,
          inDrawer: widget.inDrawer,
        ),
      ],
    );
  }

  /// 构建清单分组
  Widget _buildListsSection(
    List<TaskList> taskLists,
    List tree,
    List<Task> tasks,
    AppNavState navState,
  ) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isListsHovered = true),
      onExit: (_) => setState(() => _isListsHovered = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 清单分组标题 (可作为根目录接收区)
          DragTarget<TaskList>(
            onWillAccept: (dragged) =>
                dragged != null && dragged.parentId != null,
            onAccept: (dragged) {
              ref.read(taskListProvider.notifier).moveList(dragged.id, null);
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
                child: SidebarSectionTitle(
                  title: '清单',
                  isHovered: _isListsHovered,
                  onAddList: () => SidebarDialogs.showCreateDialog(
                    context,
                    ref,
                    isFolder: false,
                    allLists: taskLists,
                  ),
                  onAddFolder: () => SidebarDialogs.showCreateDialog(
                    context,
                    ref,
                    isFolder: true,
                    allLists: taskLists,
                  ),
                ),
              );
            },
          ),
          // 递归渲染树形列表
          ...tree.map(
            (node) => SidebarTreeItems.buildTreeItem(
              context,
              ref,
              node,
              tasks,
              navState,
              indent: 0,
              inDrawer: widget.inDrawer,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建标签分组
  Widget _buildTagsSection(List<Task> tasks, List<Tag> tags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SidebarTags.buildTagsHeader(
          context,
          ref,
          tagFilterMode: _tagFilterMode,
          onFilterModeChanged: (value) {
            setState(() => _tagFilterMode = value);
          },
          onAddTag: () => SidebarTags.showAddTagDialog(context, ref),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AmberDimens.spacingMd,
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) {
              // 统计该标签下的未完成任务数
              final count = tasks
                  .where(
                    (t) =>
                        t.tags.contains(tag.name) &&
                        !t.isCompleted &&
                        !t.isDeleted,
                  )
                  .length;

              if (_tagFilterMode == 1 && count == 0) {
                return const SizedBox.shrink();
              }

              return SidebarTags.buildInlineTagItem(
                context,
                ref,
                tag,
                count,
                onTap: () {
                  // TODO: 按标签筛选
                },
                onSecondaryTapDown: (details) {
                  SidebarTags.showTagContextMenu(
                    context,
                    ref,
                    details.globalPosition,
                    tag,
                  );
                },
              );
            }).toList(),
          ),
        ),
        if (tags.isEmpty && _tagFilterMode == 0)
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AmberDimens.spacingMd,
            ),
            child: Text(
              '暂无标签',
              style: TextStyle(
                color: AmberColors.textDisabled,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  /// 构建底部清单（已完成、垃圾桶）
  Widget _buildBottomLists(AppNavState navState) {
    // 在下一帧更新垃圾桶位置（用于删除动画）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTrashIconPosition();
    });

    return Column(
      children: [
        SidebarSmartLists.buildSmartListItem(
          context,
          ref,
          icon: navState.currentView == NavView.completed
              ? FluentIcons.checkmark_circle_24_filled
              : FluentIcons.checkmark_circle_24_regular,
          title: '已完成',
          view: NavView.completed,
          isSelected: navState.currentView == NavView.completed,
          inDrawer: widget.inDrawer,
        ),
        SidebarSmartLists.buildSmartListItem(
          context,
          ref,
          itemKey: SidebarSmartLists.trashIconKey,
          icon: navState.currentView == NavView.trash
              ? FluentIcons.delete_24_filled
              : FluentIcons.delete_24_regular,
          title: '垃圾桶',
          view: NavView.trash,
          isSelected: navState.currentView == NavView.trash,
          inDrawer: widget.inDrawer,
        ),
      ],
    );
  }

  /// 更新垃圾桶图标位置（用于删除动画的终点）
  void _updateTrashIconPosition() {
    final key = SidebarSmartLists.trashIconKey;
    if (key.currentContext != null) {
      final RenderBox box = key.currentContext!.findRenderObject() as RenderBox;
      final position = box.localToGlobal(Offset.zero);
      final size = box.size;
      // 计算图标中心位置（图标在 ListTile 左侧）
      final centerPosition = Offset(
        position.dx + 40, // ListTile leading 图标大概在左边 40px 位置
        position.dy + size.height / 2,
      );
      TrashAnimationService.instance.setTrashIconPosition(centerPosition);
    }
  }
}
