import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart'; // Add this import
import 'dart:io';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../pages/sticky_note/sticky_note_registry.dart';

import 'common/toast/toast_manager.dart';
import 'common/toast/toast_types.dart'; 
import '../../core/constants/constants.dart';
import '../../data/models/models.dart';
import '../providers/providers.dart';
import '../../core/utils/sound_service.dart';
import '../../core/utils/ui_utils.dart'; // Add import

/// 清单侧边栏
class ListSidebar extends ConsumerStatefulWidget {
  const ListSidebar({super.key});

  @override
  ConsumerState<ListSidebar> createState() => _ListSidebarState();
}

class _ListSidebarState extends ConsumerState<ListSidebar>
    with SingleTickerProviderStateMixin {
  // 标签显示模式：0=显示, 1=有内容时显示
  int _tagFilterMode = 0;
  
  // Hover state for the entire Lists section
  bool _isListsHovered = false;
  
  // 动画控制器
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(); // 循环旋转
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskLists = ref.watch(taskListProvider);
    final navState = ref.watch(appNavProvider);
    final tasks = ref.watch(taskProvider);
    final tags = ref.watch(tagsProvider);

    // 构建树形结构
    final tree = _buildTree(taskLists);

    return Container(
      width: AmberDimens.listSidebarWidth,
      color: AmberColors.sidebarBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部
          DragToMoveArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AmberDimens.spacingMd,
                vertical: 8, // Reduce vertical padding
              ),
              child: Row(
                children: [
                  // 琥珀清单文字标题
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
                    offset: const Offset(0, 30), // 偏移修正
                    onSelected: (value) {
                      if (value == 'list') {
                        _showCreateDialog(
                          context,
                          ref,
                          isFolder: false,
                          allLists: taskLists,
                        );
                      } else if (value == 'folder') {
                        _showCreateDialog(
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
          ),
          const Divider(height: 1),
          // 清单列表
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: ListView(
              padding: const EdgeInsets.symmetric(
                vertical: AmberDimens.spacingSm,
              ),
              children: [
                // 智能清单
                _buildSmartListItem(
                  context,
                  ref,
                  icon: navState.currentView == NavView.inbox
                      ? FluentIcons.mail_inbox_24_filled
                      : FluentIcons.mail_inbox_24_regular,
                  title: '收集箱',
                  view: NavView.inbox,
                  isSelected: navState.currentView == NavView.inbox,
                ),
                _buildSmartListItem(
                  context,
                  ref,
                  customIcon: _buildTodayIcon(
                    navState.currentView == NavView.today,
                  ),
                  title: '今天',
                  view: NavView.today,
                  isSelected: navState.currentView == NavView.today,
                ),
                _buildSmartListItem(
                  context,
                  ref,
                  customIcon: _buildUpcomingIcon(
                    navState.currentView == NavView.upcoming,
                  ),
                  title: '最近7天',
                  view: NavView.upcoming,
                  isSelected: navState.currentView == NavView.upcoming,
                ),
                const SizedBox(height: AmberDimens.spacingMd),

                  // Lists Section Group (Header + Items) wrapped in MouseRegion
                  MouseRegion(
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
                            ref
                                .read(taskListProvider.notifier)
                                .moveList(dragged.id, null);
                          },
                          builder: (context, candidateData, rejectedData) {
                            final isHovered = candidateData.isNotEmpty;
                            return Container(
                              decoration: BoxDecoration(
                                border: isHovered
                                    ? Border.all(
                                        color: AmberColors.primary,
                                        width: 2,
                                      )
                                    : null,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: _SectionTitle(
                                title: '清单',
                                isHovered: _isListsHovered,
                                onAddList: () => _showCreateDialog(
                                  context,
                                  ref,
                                  isFolder: false,
                                  allLists: taskLists,
                                ),
                                onAddFolder: () => _showCreateDialog(
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
                          (node) => _buildTreeItem(
                            context,
                            ref,
                            node,
                            tasks,
                            navState,
                            indent: 0,
                          ),
                        ),
                      ],
                  ),
                ),

                const SizedBox(height: AmberDimens.spacingMd),
                // 标签分组
                // 标签分组
                _buildTagsHeader(context),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AmberDimens.spacingMd,
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.map((tag) {
                      // Count tasks with this tag
                        // FIX: Task tags store Names, not IDs
                      final count = tasks
                          .where(
                            (t) =>
                                  t.tags.contains(tag.name) &&
                                !t.isCompleted &&
                                !t.isDeleted,
                          )
                          .length;
                      
                        // Debug print to investigate missing "555"
                        // debugPrint('Tag: ${tag.name}, Id: ${tag.id}, Count: $count, Mode: $_tagFilterMode');

                      if (_tagFilterMode == 1 && count == 0) {
                        return const SizedBox.shrink();
                      }

                      return _buildInlineTagItem(
                        context,
                          ref, // Pass ref for updates
                          tag, // Pass full Tag object
                        count,
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


                const SizedBox(height: AmberDimens.spacingMd),
                const Divider(height: 1),
                const SizedBox(height: AmberDimens.spacingMd),

                // 已完成 & 垃圾桶
                _buildSmartListItem(
                  context,
                  ref,
                  icon: navState.currentView == NavView.completed
                      ? FluentIcons.checkmark_circle_24_filled
                      : FluentIcons.checkmark_circle_24_regular,
                  title: '已完成',
                  view: NavView.completed,
                  isSelected: navState.currentView == NavView.completed,
                ),
                _buildSmartListItem(
                  context,
                  ref,
                  icon: navState.currentView == NavView.trash
                      ? FluentIcons.delete_24_filled
                      : FluentIcons.delete_24_regular,
                  title: '垃圾桶',
                  view: NavView.trash,
                  isSelected: navState.currentView == NavView.trash,
                ),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== Tree Building Logic =====

  List<SidebarTreeNode> _buildTree(List<TaskList> allLists) {
    final Map<String, List<TaskList>> childrenMap = {};
    final List<TaskList> rootLists = [];

    // 分组
    for (var list in allLists) {
      if (list.parentId == null) {
        rootLists.add(list);
      } else {
        childrenMap.putIfAbsent(list.parentId!, () => []).add(list);
      }
    }

    // 递归构建
    List<SidebarTreeNode> buildNodes(List<TaskList> lists) {
      return lists.map((list) {
        final children = childrenMap[list.id] ?? [];
        // Sort children by sortOrder
        children.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return SidebarTreeNode(data: list, children: buildNodes(children));
      }).toList();
    }

    // Sort logic is already in provider, but ensure roots are sorted too if needed
    // Provider sorts all by sortOrder, but when building tree we respect that order naturally?
    // Actually the provider list is flat sorted. We re-sort here just in case.
    rootLists.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return buildNodes(rootLists);
  }

  // ===== Tree Rendering =====


  Widget _buildTreeItem(
    BuildContext context,
    WidgetRef ref,
    SidebarTreeNode node,
    List<Task> allTasks,
    AppNavState navState, {
    required double indent,
  }) {
    // 只有非根节点(或所有节点)都支持右键菜单 + 拖拽
    // Move GestureDetector inside specific build methods to avoid wrapping children
    final child = node.data.isFolder
          ? _buildFolderItem(context, ref, node, allTasks, navState, indent)
          : _buildListItem(
              context,
              ref,
              list: node.data,
              taskCount: allTasks
                  .where((t) => t.listId == node.data.id && !t.isCompleted)
                  .length,
              isSelected:
                  navState.currentView == NavView.list &&
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

  Widget _buildFolderItem(
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
        if (dragged.id == node.data.id) return false; // Cannot drop on self
        if (dragged.parentId == node.data.id)
          return false; // Already in this folder
        // Simple cycle check: if we drop folder A into folder B, make sure B is not inside A
        // We defer rigorous check to provider or trust user for now
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
                // dense: true,
                // visualDensity: VisualDensity(vertical: -4),
                // minVerticalPadding: 0,
                horizontalTitleGap: 0,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            child: ExpansionTile(
              key: PageStorageKey('folder_${node.data.id}'), // 保持展开状态
              controlAffinity: ListTileControlAffinity.leading, // 箭头在左侧
              title: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onSecondaryTapDown: (details) => _showContextMenu(
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
              initiallyExpanded: true, // 默认展开
              collapsedIconColor: AmberColors.textSecondary, // 箭头颜色
              iconColor: AmberColors.textSecondary,
              children: node.children
                  .map(
                    (child) => _buildTreeItem(
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

  Widget _buildListItem(
    BuildContext context,
    WidgetRef ref, {
    required TaskList list,
    required int taskCount,
    required bool isSelected,
    double indent = 0,
  }) {
    // 稍微调整缩进以匹配 ExpansionTile 的内容
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
              _showContextMenu(context, ref, details.globalPosition, list),
          child: ListTile(
            dense: true,
            // visualDensity: const VisualDensity(vertical: -4), // Restore standard
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

  // ===== Dialogs =====

  void _showCreateDialog(
    BuildContext context,
    WidgetRef ref, {
    required bool isFolder,
    required List<TaskList> allLists,
    String? parentId,
  }) {
    final controller = TextEditingController();
    Color selectedColor = AmberColors.primary;
    String? selectedParentId = parentId; // 选中的父文件夹ID (默认值为传入的parentId)

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
                    ref
                        .read(taskListProvider.notifier)
                        .createFolder(
                          controller.text.trim(),
                          parentId: selectedParentId,
                        );
                  } else {
                    ref
                        .read(taskListProvider.notifier)
                        .addList(
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


  Widget _buildSmartListItem(
    BuildContext context,
    WidgetRef ref, {
    IconData? icon,
    Widget? customIcon,
    required String title,
    required NavView view,
    required bool isSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AmberColors.primary.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: ListTile(
          dense: true,
          // visualDensity: const VisualDensity(vertical: -4), // Restore standard
          selected: isSelected,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading:
              customIcon ??
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? AmberColors.primary
                    : AmberColors.textPrimary,
              ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: AmberColors.textPrimary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          onTap: () {
            ref.read(appNavProvider.notifier).setView(view);
          },
        ),
      ),
    );
  }

  Widget _buildTodayIcon(bool isSelected) {
    final now = DateTime.now();
    final day = now.day.toString();
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          isSelected
              ? FluentIcons.calendar_ltr_24_filled
              : FluentIcons.calendar_ltr_24_regular,
          size: 20,
          color: isSelected ? AmberColors.primary : AmberColors.textPrimary,
        ),
        Positioned(
          top: 6,
          child: Text(
            day,
            style: TextStyle(
              fontSize: day.length > 1 ? 8 : 9,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AmberColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingIcon(bool isSelected) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          isSelected
              ? FluentIcons.calendar_work_week_24_filled
              : FluentIcons.calendar_work_week_24_regular,
          size: 20,
          color: isSelected ? AmberColors.primary : AmberColors.textPrimary,
        ),
        Positioned(
          top: 6,
          child: Text(
            '7',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AmberColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTagsHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AmberDimens.spacingMd,
        AmberDimens.spacingSm,
        AmberDimens.spacingXs, // 右侧减少padding以容纳按钮
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
              onPressed: () {
                _showAddTagDialog(context, ref);
              },
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
              onSelected: (value) {
                setState(() {
                  _tagFilterMode = value;
                });
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 1,
                  height: 32,
                  child: Row(
                    children: [
                      if (_tagFilterMode == 1)
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
                      if (_tagFilterMode == 0)
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





  Widget _buildInlineTagItem(
    BuildContext context,
    WidgetRef ref,
    Tag tag,
    int count,
  ) {
    return InkWell(
      onTap: () {
        // TODO: 按标签筛选
      },
      onSecondaryTapDown: (details) {
        _showTagContextMenu(context, ref, details.globalPosition, tag);
      },
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

  void _showTagContextMenu(
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
            // Delay to allow menu to close
            Future.delayed(
              const Duration(seconds: 0),
              () => _showEditTagDialog(context, ref, tag),
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
              const Duration(seconds: 0),
              () => _showDeleteTagDialog(context, ref, tag),
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

  void _showEditTagDialog(BuildContext context, WidgetRef ref, Tag tag) {
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
                  ref
                      .read(tagsProvider.notifier)
                      .updateTag(
                        tag.copyWith(
                          name: controller.text.trim(),
                          color: selectedColor,
                        ),
                        tag.name, // Pass old name for cascading updates
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

  void _showDeleteTagDialog(BuildContext context, WidgetRef ref, Tag tag) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除标签？'),
        content: Text('确认要删除标签“${tag.name}”吗？此操作将从所有通过该标签关联的任务中移除它。'),
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

  // ===== Context Menus =====

  void _showContextMenu(
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
      // constraints: const BoxConstraints(minWidth: 160, maxWidth: 220), // Optional
      items: <PopupMenuEntry<String>>[
        if (list.isFolder) ...[
          PopupMenuItem<String>(
            value: 'add_list',
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onTap: () {
              Future.delayed(Duration.zero, () {
                _showCreateDialog(
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
                _showCreateDialog(
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

        PopupMenuItem<String>(
          value: 'edit',
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onTap: () {
            Future.delayed(Duration.zero, () {
              _showRenameDialog(context, ref, list);
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
              _showListTagsDialog(context, ref, list);
            });
          },
          child: const Row(
            children: [
              Icon(
                Icons.label_outline,
                size: 16, // Use Icons.label_outline or FluentIcons
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
              _showMoveListDialog(context, ref, list);
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
        if (!list.isFolder)
          PopupMenuItem<String>(
            value: 'open_note',
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onTap: () {
              Future.delayed(Duration.zero, () {
                _showStickyNoteWindow(context, ref, list);
              });
            },
            child: const Row(
              children: [
                Icon(
                  Icons.note_alt_outlined, // Or sticky note icon
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

        if (list.isFolder)
          PopupMenuItem<String>(
            value: 'disband',
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onTap: () {
              Future.delayed(Duration.zero, () {
                _showDisbandConfirm(context, ref, list);
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
                _showDeleteConfirm(context, ref, list);
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

  void _showAddTagDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    Color selectedColor = AmberColors.listColors[0]; // Default color

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
                          ), // Selected ring
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

  void _showRenameDialog(BuildContext context, WidgetRef ref, TaskList list) {
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

  void _showDisbandConfirm(
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

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, TaskList list) {
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


  // ===== New Dialogs =====

  void _showListTagsDialog(BuildContext context, WidgetRef ref, TaskList list) {
    // 简单的标签选择对话框，支持多选
    final allTags = ref.read(tagsProvider);
    final selectedTags = List<String>.from(list.tags); // Copy

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

                        // Note: Task tags are stored as names in Task model currently in implementation plan?
                        // Wait, Task model uses `tags` as simple strings (names).
                        // List model `tags` is also List<String>.
                        // But `Tag` entity has `id` and `name`.
                        // Let's assume we store Tag Names for consistency with Tasks for now,
                        // OR IDs if we want better ref.
                        // Task `tags` stores JSON array of strings (names).
                        // TaskList `tags` stores JSON array of strings (names, probably).
                        // Let's check consistency. The Task implementation stores Names.
                        // So here we store Names.
                        final isSelectedByName = selectedTags.contains(
                          tag.name,
                        );

                        final tagColor = tag.color; // Tag.color is Color
                        // Also for lists? Assuming Tag definition is shared.
                        // ListSidebar reads `Tag` model which has `color` (int/Color).
                        // Note: Tag model in `data/models/tag.dart` uses `Color`.

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

  void _showMoveListDialog(BuildContext context, WidgetRef ref, TaskList list) {
    final allLists = ref.read(taskListProvider);
    final folders = allLists
        .where((l) => l.isFolder && l.id != list.id)
        .toList();
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
                value: selectedParentId, // Assuming logic handles verification
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

  void _showStickyNoteWindow(
    BuildContext context,
    WidgetRef ref,
    TaskList list,
  ) async {
    // Check if sticky note is already open
    if (ref.read(stickyNoteRegistryProvider.notifier).isOpen(list.id)) {
      final windowId = ref
          .read(stickyNoteRegistryProvider.notifier)
          .getWindowId(list.id);
      if (windowId != null) {
        debugPrint(
          '[FixDebug] Found registry entry: ListID=${list.id} -> WindowID=$windowId',
        );

        // 1. Check OS reported windows
        final subWindowIds = await DesktopMultiWindow.getAllSubWindowIds();
        debugPrint('[FixDebug] OS Reported SubWindow IDs: $subWindowIds');
        
        bool isAlive = false;
        try {
          debugPrint('[FixDebug] Attempting to PING window $windowId...');
          final response = await DesktopMultiWindow.invokeMethod(
            windowId,
            'ping',
            null,
          ).timeout(const Duration(milliseconds: 500));
          debugPrint('[FixDebug] PING Response: $response');
          if (response == 'pong') {
            isAlive = true;
          }
        } catch (e) {
          debugPrint('[FixDebug] PING Failed/Timed out: $e');
          isAlive = false;
        }

        debugPrint('[FixDebug] Liveness Verdict: isAlive=$isAlive');

        if (!isAlive) {
          debugPrint('[FixDebug] Unregistering dead window $windowId');
          ref.read(stickyNoteRegistryProvider.notifier).unregister(list.id);
        } else {
          debugPrint('[FixDebug] Window is alive. Focusing...');
          if (context.mounted) {
            ToastManager().show(context, '当前已打开便签', type: ToastType.warning);
          }
          try {
            await DesktopMultiWindow.invokeMethod(windowId, 'focus', null);
          } catch (e) {
            debugPrint('[FixDebug] Focus failed: $e');
          }
          return;
        }
      }
    }

    // 获取当前列表的任务快照
    final allTasks = ref.read(taskProvider);
    final listTasks = allTasks.where((t) => t.listId == list.id).toList();

    final activeTasks = listTasks
        .where((t) => !t.isCompleted)
        .map((t) => {'id': t.id, 'title': t.title, 'isCompleted': false})
        .toList();

    final completedTasks = listTasks
        .where((t) => t.isCompleted)
        .map((t) => {'id': t.id, 'title': t.title, 'isCompleted': true})
        .toList();

    // 构建结构化数据
    final data = {
      'id': list.id,
      'type': 'sticky_note',
      'title': list.name,
      'themeColor': '0xFFFFF7D1',
      'active': activeTasks,
      'completed': completedTasks,
    };

    // 创建独立窗口
    final window = await DesktopMultiWindow.createWindow(jsonEncode(data));

    // Register window
    ref
        .read(stickyNoteRegistryProvider.notifier)
        .register(list.id, window.windowId);

    // 设置窗口大小和位置
    // 默认位置：屏幕中心稍微偏移
    // Platform-specific window size
    final size = Platform.isMacOS ? const Size(320, 360) : const Size(600, 700);

    window
      ..setFrame(const Offset(0, 0) & size)
      ..center()
      ..setTitle('便签: ${list.name}')
      ..show();
      
    // 提示用户
    if (context.mounted) {
      // Optional: Show toast or just let the window appear
    }
  }
}

/// 树节点模型
class SidebarTreeNode {
  final TaskList data;
  final List<SidebarTreeNode> children;

  SidebarTreeNode({required this.data, this.children = const []});
}
class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isHovered;
  final VoidCallback onAddList;
  final VoidCallback onAddFolder;

  const _SectionTitle({
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
