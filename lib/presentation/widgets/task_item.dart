import 'dart:convert';
import 'dart:io';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../pages/sticky_note/sticky_note_registry.dart';
import 'adaptive/detail_bottom_sheet.dart';
import 'common/toast/toast_manager.dart';
import 'common/toast/toast_types.dart';
import '../../core/constants/constants.dart';
import '../../core/services/native_sticky_note_service.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/trash_animation_service.dart';
import '../../data/models/models.dart';
import '../providers/providers.dart';
import '../../core/utils/sound_service.dart';
import '../../core/utils/ui_utils.dart';

/// 任务列表项
class TaskItem extends ConsumerWidget {
  final Task task;
  final VoidCallback? onTap;

  /// 尾部自定义组件，例如日历视图中的时间标记
  final Widget? trailing;

  /// 外部控制的选中状态
  /// 如果不为 null，则覆盖默认的 appNavProvider.selectedTaskId 判断
  /// 用于弹窗等独立上下文中的选中高亮
  final bool? isSelected;

  const TaskItem({
    super.key,
    required this.task,
    this.onTap,
    this.trailing,
    this.isSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(appNavProvider);
    // 优先使用外部传入的 isSelected，否则使用全局导航状态判断
    final isItemSelected = isSelected ?? (navState.selectedTaskId == task.id);

    // 移动端：使用 Slidable 包裹，支持左滑操作
    // 桌面端：直接返回卡片
    final isMobile = Platform.isAndroid || Platform.isIOS;
    if (isMobile) {
      // 移动端特殊的布局结构：
      // Margin (Padding) -> Container (Shadow/Border/Radius) -> ClipRRect -> Slidable -> Card (White Bg, Rectangular)
      // 这样做的目的是：
      // 1. Shadow/Border/Radius 由外层 Container 统一绘制，形成"卡片"容器。
      // 2. ClipRRect 确保内部的内容（包括侧滑出来的按钮）都遵循这个圆角。
      // 3. 内部的 TaskCard 设为直角且无边框，这样滑动时，WhiteCard 和 ActionButton 的边缘是平齐的竖线，
      //    消除了"左边圆角右边方角"的视觉割裂感，实现类似微信的"卡片内滑动"效果。
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AmberDimens.spacingMd,
          vertical: 4,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent, // 容器本身透明，背景色由子元素决定
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isItemSelected ? AmberColors.primary : const Color(0xFFEEEEEE),
              width: 1,
            ),
            boxShadow: [
              if (!task.isCompleted)
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Slidable(
              key: ValueKey(task.id),
              // 右侧滑出的操作按钮（左滑触发）
              // 使用 DrawerMotion：按钮从右侧抽屉式滑出，覆盖在内容上方
              // 内容完全不动，按钮盖住文字
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                extentRatio: 0.4,
                children: _buildSlideActions(context, ref),
              ),
              // 这里的卡片不需要 margin (由外层 Padding 控制)
              // 不需要 shadow/border/radius (由外层 Container 控制)
              // 这样它就是一个纯白色的矩形块，滑动时边缘平整
              // 使用 Builder 确保能正确获取 Slidable.of(context)
              child: Builder(
                builder: (slidableContext) {
                  return _buildMobileTaskCard(
                    slidableContext,
                    ref,
                    isItemSelected,
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    // 桌面端直接构建带 Margin 的卡片
    return _buildTaskCard(context, ref, isItemSelected);
  }

  /// 构建滑动操作按钮列表
  /// 根据任务状态（普通/已完成/已删除）返回不同的操作按钮
  /// 仿微信风格：无圆角、方正贴边、高饱和度颜色、纯文字无图标
  List<Widget> _buildSlideActions(BuildContext context, WidgetRef ref) {
    // 微信风格颜色定义
    const wechatGreen = Color(0xFF07C160); // 微信绿
    const wechatOrange = Color(0xFFFA9D3B); // 微信橙
    const wechatRed = Color(0xFFFA5151); // 微信红

    // 构建纯文字按钮（使用 CustomSlidableAction，文字水平垂直居中）
    Widget buildActionButton({
      required String label,
      required Color backgroundColor,
      required VoidCallback onTap,
    }) {
      return CustomSlidableAction(
        onPressed: (_) => onTap(),
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        padding: EdgeInsets.zero,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    // 垃圾桶中的任务：还原 + 彻底删除
    if (task.isDeleted) {
      return [
        buildActionButton(
          label: '还原',
          backgroundColor: wechatOrange,
          onTap: () {
            ref.read(taskProvider.notifier).restoreTask(task.id);
          },
        ),
        buildActionButton(
          label: '删除',
          backgroundColor: wechatRed,
          onTap: () {
            _handlePermanentDelete(context, ref);
          },
        ),
      ];
    }

    // 已完成的任务：取消完成 + 删除
    if (task.isCompleted) {
      return [
        buildActionButton(
          label: '取消完成',
          backgroundColor: wechatOrange,
          onTap: () {
            ref.read(soundServiceProvider).playAdd();
            ref.read(taskProvider.notifier).toggleTaskComplete(task.id);
          },
        ),
        buildActionButton(
          label: '删除',
          backgroundColor: wechatRed,
          onTap: () {
            _handleDelete(context, ref);
          },
        ),
      ];
    }

    // 普通任务：完成 + 删除
    return [
      buildActionButton(
        label: '完成',
        backgroundColor: wechatGreen,
        onTap: () {
          ref.read(soundServiceProvider).playCompletion();
          ref.read(taskProvider.notifier).toggleTaskComplete(task.id);
        },
      ),
      buildActionButton(
        label: '删除',
        backgroundColor: wechatRed,
        onTap: () {
          _handleDelete(context, ref);
        },
      ),
    ];
  }

  /// 处理普通删除（移入垃圾桶）
  /// 先弹出二次确认框，确认后才执行删除
  /// 如果任务有番茄记录会弹出特殊提示
  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    // 先弹出二次确认框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除任务「${task.title}」吗？\n任务将被移入垃圾桶。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final success = await ref.read(taskProvider.notifier).deleteTask(task.id);
    if (success) {
      ref.read(soundServiceProvider).playDelete();
    } else {
      // 有番茄记录冲突，弹窗提示
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('无法删除'),
            content: const Text(
              '该任务有关联的番茄时钟记录。\n\n'
              '请先前往番茄时钟页面删除相关记录，或选择"强制删除"移入垃圾桶。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  ref.read(taskProvider.notifier).forceDeleteTask(task.id);
                  ref.read(soundServiceProvider).playDelete();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text(
                  '强制删除',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  /// 处理彻底删除（从垃圾桶永久删除）
  /// 弹出二次确认框，确认后才执行删除
  /// 如果任务有番茄记录会弹出特殊提示
  Future<void> _handlePermanentDelete(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // 先检查是否有关联的番茄记录
    final hasPomodoroRecords = await ref
        .read(taskProvider.notifier)
        .hasTaskPomodoroRecords(task.id);

    if (!context.mounted) return;

    if (hasPomodoroRecords) {
      // 有番茄记录，需要特殊提示
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('无法删除'),
          content: const Text(
            '该任务有关联的番茄时钟记录。\n\n'
            '请先前往番茄时钟页面删除相关记录，或选择"强制删除"同时删除任务和番茄记录。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(taskProvider.notifier)
                    .forceDeleteTaskWithPomodoros(task.id);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('强制删除', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      // 无关联记录，弹出二次确认框
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认彻底删除'),
          content: Text('确定要彻底删除任务「${task.title}」吗？\n此操作不可恢复！'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('彻底删除', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        ref.read(taskProvider.notifier).permanentlyDeleteTask(task.id);
      }
    }
  }

  /// 移动端专用：构建任务卡片
  /// 微信风格：勾选框随滑动移出屏幕，文字保持原位被按钮遮盖
  Widget _buildMobileTaskCard(
    BuildContext context,
    WidgetRef ref,
    bool isSelected,
  ) {
    final navState = ref.watch(appNavProvider);
    // 勾选框宽度 + 右边距
    const checkboxWidth = 24.0;
    const checkboxMargin = AmberDimens.spacingMd; // 16.0
    const checkboxTotalWidth = checkboxWidth + checkboxMargin;

    // 获取 Slidable 的动画控制器（context 必须是 Slidable 子树中的）
    final slidableController = Slidable.of(context);

    return Container(
      color: Colors.white,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () {
            // 检查是否在 Slidable 内部且处于打开状态
            if (slidableController != null) {
              if (slidableController.actionPaneType.value != ActionPaneType.none) {
                slidableController.close();
                return;
              }
            }
            // 移动端：显示 BottomSheet 详情面板
            DetailBottomSheet.show(context, task);
          },
          onLongPress: () {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final Offset position = box.localToGlobal(Offset.zero);
            _showContextMenu(context, ref, Offset(
              position.dx + box.size.width / 2,
              position.dy + box.size.height / 2,
            ));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AmberDimens.spacingMd,
              vertical: 12,
            ),
            // 监听滑动动画，让勾选框跟着移动
            child: AnimatedBuilder(
              animation: slidableController?.animation ?? const AlwaysStoppedAnimation(0),
              builder: (context, child) {
                // ratio: 0 = 关闭, 1 = 完全打开
                // extentRatio = 0.4，所以最大滑动距离 = 卡片宽度 * 0.4
                final ratio = slidableController?.animation.value ?? 0.0;
                // 勾选框向左移动的距离：只需要移出勾选框自身宽度即可
                final checkboxOffset = ratio * checkboxTotalWidth;

                return Row(
                  children: [
                    // 勾选框区域：固定宽度，内部用 ClipRect 裁剪溢出部分
                    SizedBox(
                      width: checkboxTotalWidth,
                      child: ClipRect(
                        child: Transform.translate(
                          offset: Offset(-checkboxOffset, 0),
                          child: Row(
                            children: [
                              _buildCheckbox(ref),
                              const SizedBox(width: AmberDimens.spacingMd),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // 文字：保持原位，不移动（优先级图标在第二行显示）
                    Expanded(child: _buildTaskContent(ref, navState)),
                    if (trailing != null) ...[
                      const SizedBox(width: AmberDimens.spacingMd),
                      trailing!,
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 构建任务内容区域（标题 + 优先级/日期/标签）
  /// 移动端 _buildMobileTaskCard 使用
  Widget _buildTaskContent(WidgetRef ref, AppNavState navState) {
    final displaySettings = ref.watch(displaySettingsProvider);

    final shouldShowDate = displaySettings.showDueDate &&
        task.dueDate != null &&
        !_shouldHideDateLabel(navState.currentView, task.dueDate!);
    final shouldShowTags = displaySettings.showTags && task.tags.isNotEmpty;
    // 判断是否需要显示优先级（有优先级且设置开启）
    final shouldShowPriority = displaySettings.showPriority &&
        task.priority != TaskPriority.none;
    final isOverdue = task.dueDate != null && _isOverdue(task.dueDate!);

    // 判断是否需要显示第二行
    final shouldShowSecondRow = shouldShowPriority || shouldShowDate || shouldShowTags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 使用 LayoutBuilder 和 Stack 实现半删除线效果
        _buildTitleWithHalfStrikethrough(
          title: task.title,
          isCompleted: task.isCompleted,
          isInProgress: task.isInProgress,
          isOverdue: isOverdue,
          overdueColor: Color(displaySettings.overdueTitleColorValue),
        ),
        if (shouldShowSecondRow) const SizedBox(height: 4),
        if (shouldShowSecondRow)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 优先级图标（放在最前面）
              if (shouldShowPriority) ...[
                _buildPriorityIcon(true)!,
                const SizedBox(width: 6),
              ],
              if (shouldShowDate) ...[
                Icon(
                  Icons.calendar_today_outlined,
                  size: 12,
                  color: _getDueDateColor(
                    task.dueDate!,
                    overdueColor: Color(displaySettings.overdueLabelColorValue),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDueDate(task.dueDate!),
                  style: TextStyle(
                    fontSize: 12,
                    color: _getDueDateColor(
                      task.dueDate!,
                      overdueColor: Color(displaySettings.overdueLabelColorValue),
                    ),
                  ),
                ),
              ],
              if (shouldShowTags) ...[
                if (shouldShowDate || shouldShowPriority)
                  const SizedBox(width: AmberDimens.spacingSm),
                ...task.tags.take(3).map((tagName) {
                  final allTags = ref.watch(tagsProvider);
                  final tagObj = allTags.firstWhere(
                    (t) => t.name == tagName,
                    orElse: () => Tag(
                      id: '',
                      name: tagName,
                      color: AmberColors.primary,
                      createdAt: DateTime.now(),
                    ),
                  );
                  final tagColor = tagObj.color;

                  return Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tagColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: tagColor.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      tagName,
                      style: TextStyle(
                        fontSize: 10,
                        color: tagColor,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
            ],
          ),
      ],
    );
  }

  /// 构建任务卡片主体
  /// [margin] 可选，默认使用标准间距。移动端由于外层包裹 Slidable 需手动控制 margin。
  /// [showShadow] 是否显示阴影
  /// [showBorder] 是否显示边框
  /// [borderRadius] 边框圆角
  Widget _buildTaskCard(
    BuildContext context,
    WidgetRef ref,
    bool isSelected, {
    EdgeInsetsGeometry? margin,
    bool showShadow = true,
    bool showBorder = true,
    BorderRadiusGeometry? borderRadius,
  }) {
    final navState = ref.watch(appNavProvider);

    return Container(
      margin:
          margin ??
          const EdgeInsets.symmetric(
            horizontal: AmberDimens.spacingMd,
            vertical: 4, // 减小垂直间距，更紧凑
          ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(12), // 更圆润的角
        border: showBorder
            ? Border.all(
                color: isSelected
                    ? AmberColors.primary
                    : const Color(0xFFEEEEEE),
                width: 1, // 极细边框
              )
            : null,
        boxShadow: [
          if (showShadow && !task.isCompleted) // 未完成任务加一点微弱的阴影
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Builder(
          builder: (context) {
            return InkWell(
              onTap:
                  onTap ??
                  () {
                    // 检查是否在 Slidable 内部且处于打开状态
                    final slidable = Slidable.of(context);
                    if (slidable != null) {
                      // 如果侧滑菜单是打开的，点击内容区域则关闭菜单
                      // ActionPaneType.none 表示关闭状态
                      if (slidable.actionPaneType.value !=
                          ActionPaneType.none) {
                        slidable.close();
                        return;
                      }
                    }

                    // 移动端：显示 BottomSheet 详情面板
                    // 桌面端：打开右侧详情面板
                    if (Platform.isAndroid || Platform.isIOS) {
                      DetailBottomSheet.show(context, task);
                    } else {
                      ref.read(appNavProvider.notifier).selectTask(task.id);
                    }
                  },
          // 桌面端：鼠标右键触发菜单
          onSecondaryTapDown: (details) {
            _showContextMenu(context, ref, details.globalPosition);
          },
          // 移动端：长按触发菜单（桌面端不需要长按）
          onLongPress: (Platform.isAndroid || Platform.isIOS) ? () {
            // 获取当前组件的位置作为菜单弹出位置
            final RenderBox box = context.findRenderObject() as RenderBox;
            final Offset position = box.localToGlobal(Offset.zero);
            // 菜单显示在任务项中间偏右的位置
            _showContextMenu(context, ref, Offset(position.dx + box.size.width / 2, position.dy + box.size.height / 2));
          } : null,
          borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AmberDimens.spacingMd,
                  vertical: 12,
                ),
                child: Builder(
                  builder: (context) {
                    // 获取显示设置
                    final displaySettings = ref.watch(displaySettingsProvider);

                    return Row(
                      children: [
                        _buildCheckbox(ref),
                        const SizedBox(width: AmberDimens.spacingMd),
                        Expanded(
                          child: _buildTaskContentColumn(
                            ref: ref,
                            navState: navState,
                            displaySettings: displaySettings,
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: AmberDimens.spacingMd),
                          trailing!,
                        ],
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, WidgetRef ref, Offset position) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    // 如果已删除（垃圾桶），只显示还原和彻底删除
    if (task.isDeleted) {
      showInstantMenu<String>(
        context: context,
        position: RelativeRect.fromRect(
          position & const Size(40, 40),
          Offset.zero & overlay.size,
        ),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
        items: <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'restore',
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onTap: () {
              ref.read(taskProvider.notifier).restoreTask(task.id);
            },
            child: const Row(
              children: [
                Icon(
                  Icons.restore_from_trash_rounded,
                  size: 16,
                  color: AmberColors.primary,
                ),
                SizedBox(width: 8),
                Text(
                  '还原',
                  style: TextStyle(fontSize: 13, color: AmberColors.primary),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),
          PopupMenuItem<String>(
            value: 'delete_forever',
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onTap: () {
              Future.delayed(Duration.zero, () async {
                // 先检查是否有关联的番茄记录
                final hasPomodoroRecords = await ref
                    .read(taskProvider.notifier)
                    .hasTaskPomodoroRecords(task.id);

                if (!context.mounted) return;

                if (hasPomodoroRecords) {
                  // 有番茄记录，需要特殊提示
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('无法删除'),
                      content: const Text(
                        '该任务有关联的番茄时钟记录。\n\n'
                        '请先前往番茄时钟页面删除相关记录，或选择"强制删除"同时删除任务和番茄记录。',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            ref
                                .read(taskProvider.notifier)
                                .forceDeleteTaskWithPomodoros(task.id);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text(
                            '强制删除',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  // 无关联记录，普通确认
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('彻底删除'),
                      content: const Text('删除后无法恢复，确定要删除吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            ref
                                .read(taskProvider.notifier)
                                .permanentlyDeleteTask(task.id);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text(
                            '删除',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              });
            },
            child: const Row(
              children: [
                Icon(
                  Icons.delete_forever_outlined,
                  size: 16,
                  color: Colors.red,
                ),
                SizedBox(width: 8),
                Text('彻底删除', style: TextStyle(color: Colors.red, fontSize: 13)),
              ],
            ),
          ),
        ],
      );
      return;
    }

    // 判断是否为桌面端（支持便签功能）
    final isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;

    // 动态构建菜单项列表
    final menuItems = <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        value: 'edit',
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        onTap: () {
          Future.delayed(Duration.zero, () {
            _showEditDialog(context, ref);
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
        value: 'move_to',
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        onTap: () {
          Future.delayed(Duration.zero, () {
            _showMoveTaskDialog(context, ref);
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
      PopupMenuItem<String>(
        value: 'tags',
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        onTap: () {
          Future.delayed(Duration.zero, () {
            _showTaskTagsDialog(context, ref);
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
      // 只有未完成的任务才显示"进行中"选项
      if (!task.isCompleted)
        PopupMenuItem<String>(
          value: 'in_progress',
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onTap: () {
            ref.read(taskProvider.notifier).toggleTaskInProgress(task.id);
          },
          child: Row(
            children: [
              Icon(
                task.isInProgress ? Icons.remove_circle_outline : Icons.timelapse_outlined,
                size: 16,
                color: task.isInProgress ? AmberColors.primary : AmberColors.textPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                task.isInProgress ? '取消进行中' : '标记进行中',
                style: TextStyle(
                  fontSize: 13,
                  color: task.isInProgress ? AmberColors.primary : AmberColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      // 桌面端才显示"打开便签"选项
      if (isDesktop)
        PopupMenuItem<String>(
          value: 'open_note',
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onTap: () {
            Future.delayed(Duration.zero, () {
              _showStickyNoteWindow(context, ref);
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
                style: TextStyle(fontSize: 13, color: AmberColors.textPrimary),
              ),
            ],
          ),
        ),
      PopupMenuItem<String>(
        value: 'priority',
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        onTap: () {
          Future.delayed(Duration.zero, () {
            _showPriorityDialog(context, ref);
          });
        },
        child: const Row(
          children: [
            Icon(
              Icons.flag_outlined,
              size: 16,
              color: AmberColors.textPrimary,
            ),
            SizedBox(width: 8),
            Text(
              '优先级',
              style: TextStyle(fontSize: 13, color: AmberColors.textPrimary),
            ),
          ],
        ),
      ),
      const PopupMenuDivider(height: 1),
      PopupMenuItem<String>(
        value: 'delete',
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        onTap: () {
          Future.delayed(Duration.zero, () async {
            // 先尝试删除
            final success =
                await ref.read(taskProvider.notifier).deleteTask(task.id);

            if (success) {
              // 删除成功，播放动画和音效
              ref.read(soundServiceProvider).playDelete();
              if (context.mounted) {
                TrashAnimationService.instance.playTrashAnimation(
                  context,
                  position,
                  onComplete: () {
                    // 任务已经删除了，这里不需要再操作
                  },
                );
              }
            } else {
              // 有番茄记录冲突，弹窗提示
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('无法删除'),
                    content: const Text(
                      '该任务有关联的番茄时钟记录。\n\n'
                      '请先前往番茄时钟页面删除相关记录，或选择"强制删除"移入垃圾桶。',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          ref
                              .read(taskProvider.notifier)
                              .forceDeleteTask(task.id);
                          ref.read(soundServiceProvider).playDelete();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: const Text(
                          '强制删除',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              }
            }
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
    ];

    showInstantMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
      items: menuItems,
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: task.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑任务标题'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '任务标题',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              ref
                  .read(taskProvider.notifier)
                  .updateTask(task.copyWith(title: value.trim()));
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = controller.text.trim();
              if (title.isNotEmpty) {
                ref
                    .read(taskProvider.notifier)
                    .updateTask(task.copyWith(title: title));
                Navigator.pop(context);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showMoveTaskDialog(BuildContext context, WidgetRef ref) {
    // 移动任务到其他清单
    final allLists = ref.read(taskListProvider);
    // Flatten lists for dropdown (Folders aren't usually valid for tasks unless we allow tasks in folders directly?
    // Current schema: Task.listId -> TaskList.id.
    // TaskList can be folder.
    // Does logic allow task in folder?
    // Usually tasks go in lists.
    // So filter for !isFolder.
    final validLists = allLists.where((l) => !l.isFolder).toList();
    String? selectedListId = task.listId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('移动任务到'),
          content: DropdownButtonFormField<String?>(
            value: validLists.any((l) => l.id == selectedListId)
                ? selectedListId
                : null,
            items: validLists
                .map((l) => DropdownMenuItem(value: l.id, child: Text(l.name)))
                .toList(),
            onChanged: (val) => setState(() => selectedListId = val),
            decoration: const InputDecoration(
              labelText: '选择清单',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedListId != null) {
                  ref
                      .read(taskProvider.notifier)
                      .updateTask(task.copyWith(listId: selectedListId));
                }
                Navigator.pop(context);
              },
              child: const Text('移动'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskTagsDialog(BuildContext context, WidgetRef ref) {
    final allTags = ref.read(tagsProvider);
    final selectedTags = List<String>.from(task.tags);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('管理任务标签'),
          content: SizedBox(
            width: 300,
            child: allTags.isEmpty
                ? const Center(child: Text('暂无可用标签'))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allTags.map((tag) {
                      final isSelected = selectedTags.contains(tag.name);
                      final tagColor = tag.color; // Tag.color is Color

                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
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
                            // 选中时显示浅色背景，未选中显示灰色背景
                            color: isSelected
                                ? tagColor.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              // 选中时显示同色边框，未选中无边框
                              color: isSelected
                                  ? tagColor.withOpacity(0.3)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            tag.name,
                            style: TextStyle(
                              fontSize: 12,
                              // 选中时显示同色文字，未选中显示深灰文字
                              color: isSelected
                                  ? tagColor
                                  : AmberColors.textSecondary,
                              fontWeight: isSelected
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
                    .read(taskProvider.notifier)
                    .updateTask(task.copyWith(tags: selectedTags));
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPriorityDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('设置优先级'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              ref
                  .read(taskProvider.notifier)
                  .updateTask(task.copyWith(priority: TaskPriority.high));
              Navigator.pop(context);
            },
            child: const Row(
              children: [
                Icon(Icons.flag, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Text('高优先级'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              ref
                  .read(taskProvider.notifier)
                  .updateTask(task.copyWith(priority: TaskPriority.medium));
              Navigator.pop(context);
            },
            child: const Row(
              children: [
                Icon(Icons.flag, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Text('中优先级'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              ref
                  .read(taskProvider.notifier)
                  .updateTask(task.copyWith(priority: TaskPriority.low));
              Navigator.pop(context);
            },
            child: const Row(
              children: [
                Icon(Icons.flag, color: Colors.blue, size: 18),
                SizedBox(width: 8),
                Text('低优先级'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              ref
                  .read(taskProvider.notifier)
                  .updateTask(task.copyWith(priority: TaskPriority.none));
              Navigator.pop(context);
            },
            child: const Row(
              children: [
                Icon(Icons.flag_outlined, color: Colors.grey, size: 18),
                SizedBox(width: 8),
                Text('无优先级'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStickyNoteWindow(BuildContext context, WidgetRef ref) async {
    // 对于单个任务，构建只包含该任务的列表
    final activeTasks = task.isCompleted
        ? <Map<String, dynamic>>[]
        : [{'id': task.id, 'title': task.title, 'isCompleted': false}];

    final completedTasks = task.isCompleted
        ? [{'id': task.id, 'title': task.title, 'isCompleted': true}]
        : <Map<String, dynamic>>[];

    // ========== 优先使用原生便签实现 ==========
    final nativeService = NativeStickyNoteService.instance;

    if (nativeService.isSupported) {
      // 检查是否已打开
      final isOpen = await nativeService.isWindowOpen(task.id);
      if (isOpen) {
        // 已打开，聚焦
        await nativeService.focusStickyNote(task.id);
        if (context.mounted) {
          ToastManager().show(context, '便签已打开', type: ToastType.info);
        }
        return;
      }

      // 创建原生便签窗口
      final success = await nativeService.createStickyNote(
        id: task.id,
        title: task.title,
        activeTasks: activeTasks,
        completedTasks: completedTasks,
        themeColor: '0xFFE1F5FE', // 蓝色，区分列表便签
      );

      if (success) {
        debugPrint('[TaskItem] 原生便签创建成功: ${task.id}');
        return;
      } else {
        debugPrint('[TaskItem] 原生便签创建失败，尝试 Flutter 多窗口');
      }
    }

    // ========== Fallback: Flutter 多窗口实现 (desktop_multi_window 0.3.0) ==========
    // 用于不支持原生便签的平台或原生创建失败时

    // Check registry
    if (ref.read(stickyNoteRegistryProvider.notifier).isOpen(task.id)) {
      // 获取已注册的windowId
      final existingWindowId =
          ref.read(stickyNoteRegistryProvider.notifier).getWindowId(task.id);

      if (existingWindowId != null && existingWindowId.isNotEmpty) {
        // 验证窗口是否真的还活着（通过 WindowController.getAll 检查）
        bool isAlive = false;
        try {
          final allWindows = await WindowController.getAll();
          isAlive = allWindows.any((w) => w.windowId == existingWindowId);
        } catch (e) {
          debugPrint('[TaskItem] 检查窗口失败: $e');
          isAlive = false;
        }

        if (!isAlive) {
          // 窗口已死,清理注册表
          debugPrint('[TaskItem] 窗口$existingWindowId已失效,清理注册表');
          ref.read(stickyNoteRegistryProvider.notifier).unregister(task.id);
        } else {
          // 窗口还活着,显示警告
          if (context.mounted) {
            ToastManager().show(context, '当前已打开便签', type: ToastType.warning);
          }
          return;
        }
      }
    }

    // 创建独立窗口 (0.3.0 新 API)
    final windowController = await WindowController.create(
      WindowConfiguration(
        arguments: jsonEncode({
          'id': task.id, // Add ID for registry
          'type': 'sticky_note',
          'title': task.title,
          'content': task.description ?? '', // Include description if available
          'themeColor':
              '0xFFE1F5FE', // Default Blue for tasks to distinguish from lists
        }),
        hiddenAtLaunch: true,
      ),
    );

    // Register window
    ref
        .read(stickyNoteRegistryProvider.notifier)
        .register(task.id, windowController.windowId);

    debugPrint('[TaskItem] 创建 Flutter 便签窗口: ${windowController.windowId}');

    // 显示窗口
    await windowController.show();
  }

  Widget _buildCheckbox(WidgetRef ref) {
    if (task.isDeleted) {
      // 垃圾桶中不可选，仅显示状态，无交互
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: task.isCompleted
              ? AmberColors.primary.withValues(alpha: 0.5)
              : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: task.isCompleted
                ? AmberColors.primary.withValues(alpha: 0.5)
                : const Color(0xFFE0E0E0),
            width: 1.5,
          ),
        ),
        child: task.isCompleted
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      );
    }

    return GestureDetector(
      onTap: () {
        if (!task.isCompleted) {
          ref.read(soundServiceProvider).playCompletion();
        } else {
          ref.read(soundServiceProvider).playAdd(); // Uncomplete sound
        }
        ref.read(taskProvider.notifier).toggleTaskComplete(task.id);
      },
      child: Container(
        width: 24, // 加大复选框
        height: 24,
        decoration: BoxDecoration(
          color: task.isCompleted
              ? AmberColors.primary.withValues(alpha: 0.5)
              : task.isInProgress
                  ? AmberColors.primary.withValues(alpha: 0.25) // 进行中：浅色背景
                  : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: task.isCompleted
                ? AmberColors.primary.withValues(alpha: 0.5)
                : task.isInProgress
                    ? AmberColors.primary.withValues(alpha: 0.5) // 进行中：琥珀色边框
                    : const Color(0xFFE0E0E0),
            width: 1.5,
          ),
        ),
        child: task.isCompleted
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : task.isInProgress
                ? _buildHalfCheckIcon() // 进行中：半勾图标
                : null,
      ),
    );
  }

  /// 构建半勾图标（进行中状态）
  /// 使用 CustomPaint 绘制一个只有一半的勾
  Widget _buildHalfCheckIcon() {
    return CustomPaint(
      size: const Size(16, 16),
      painter: _HalfCheckPainter(color: Colors.white),
    );
  }

  /// 构建优先级图标
  /// 根据任务优先级显示不同颜色的旗帜图标
  /// [showPriority] 是否显示优先级（来自 DisplaySettings）
  Widget? _buildPriorityIcon(bool showPriority) {
    // 不显示优先级或者无优先级时返回 null
    if (!showPriority || task.priority == TaskPriority.none) {
      return null;
    }

    // 根据优先级返回不同颜色的旗帜
    final Color flagColor;
    switch (task.priority) {
      case TaskPriority.high:
        flagColor = Colors.red;
      case TaskPriority.medium:
        flagColor = Colors.orange;
      case TaskPriority.low:
        flagColor = Colors.blue;
      case TaskPriority.none:
        return null; // 理论上不会执行到这里
    }

    return Icon(
      Icons.flag,
      size: 16,
      color: flagColor,
    );
  }

  /// 构建任务内容列（标题 + 优先级/日期/标签）
  /// 桌面端 _buildTaskCard 使用
  Widget _buildTaskContentColumn({
    required WidgetRef ref,
    required AppNavState navState,
    required DisplaySettings displaySettings,
  }) {
    // 判断是否需要显示日期
    // 条件：1. 全局设置开启 2. 有截止日期 3. 不是在「今天」视图下的今天任务
    final shouldShowDate = displaySettings.showDueDate &&
        task.dueDate != null &&
        !_shouldHideDateLabel(navState.currentView, task.dueDate!);

    // 判断是否需要显示标签
    final shouldShowTags = displaySettings.showTags && task.tags.isNotEmpty;

    // 判断是否需要显示优先级（有优先级且设置开启）
    final shouldShowPriority = displaySettings.showPriority &&
        task.priority != TaskPriority.none;

    // 判断任务是否已过期
    final isOverdue = task.dueDate != null && _isOverdue(task.dueDate!);

    // 判断是否需要显示第二行（优先级、日期、标签任一存在）
    final shouldShowSecondRow = shouldShowPriority || shouldShowDate || shouldShowTags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 使用半删除线组件
        _buildTitleWithHalfStrikethrough(
          title: task.title,
          isCompleted: task.isCompleted,
          isInProgress: task.isInProgress,
          isOverdue: isOverdue,
          overdueColor: Color(displaySettings.overdueTitleColorValue),
        ),
        if (shouldShowSecondRow) const SizedBox(height: 4),
        // 第二行：优先级+日期+标签
        if (shouldShowSecondRow)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 优先级图标（放在最前面）
              if (shouldShowPriority) ...[
                _buildPriorityIcon(true)!,
                const SizedBox(width: 6),
              ],
              // 日期部分
              if (shouldShowDate) ...[
                Icon(
                  Icons.calendar_today_outlined,
                  size: 12,
                  color: _getDueDateColor(
                    task.dueDate!,
                    overdueColor: Color(displaySettings.overdueLabelColorValue),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDueDate(task.dueDate!),
                  style: TextStyle(
                    fontSize: 12,
                    color: _getDueDateColor(
                      task.dueDate!,
                      overdueColor: Color(displaySettings.overdueLabelColorValue),
                    ),
                  ),
                ),
              ],
              // 标签部分
              if (shouldShowTags) ...[
                if (shouldShowDate || shouldShowPriority)
                  const SizedBox(width: AmberDimens.spacingSm),
                ...task.tags.take(3).map((tagName) {
                  // 查找标签对应的颜色
                  final allTags = ref.watch(tagsProvider);
                  final tagObj = allTags.firstWhere(
                    (t) => t.name == tagName,
                    orElse: () => Tag(
                      id: '',
                      name: tagName,
                      color: AmberColors.primary,
                      createdAt: DateTime.now(),
                    ),
                  );
                  final tagColor = tagObj.color;

                  return Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: tagColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: tagColor.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      tagName,
                      style: TextStyle(
                        fontSize: 10,
                        color: tagColor,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
            ],
          ),
      ],
    );
  }

  /// 构建带半删除线效果的标题
  /// [isCompleted] 已完成：完整删除线
  /// [isInProgress] 进行中：半删除线（只覆盖前半部分文字）
  Widget _buildTitleWithHalfStrikethrough({
    required String title,
    required bool isCompleted,
    required bool isInProgress,
    required bool isOverdue,
    required Color overdueColor,
  }) {
    // 确定标题颜色
    final textColor = isCompleted
        ? AmberColors.textCompleted
        : isInProgress
            ? AmberColors.textSecondary // 进行中：使用次要颜色
            : isOverdue
                ? overdueColor
                : AmberColors.textPrimary;

    // 已完成：使用系统删除线
    if (isCompleted) {
      return Text(
        title,
        style: TextStyle(
          fontSize: 15,
          color: textColor,
          decoration: TextDecoration.lineThrough,
          fontWeight: FontWeight.w400,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // 进行中：使用 LayoutBuilder + Stack 实现半删除线
    if (isInProgress) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // 底层：正常文字
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  color: textColor,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // 顶层：半删除线（使用 ClipRect 裁剪到一半宽度）
              Positioned.fill(
                child: ClipRect(
                  clipper: _HalfWidthClipper(),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 1.5,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    // 普通状态：正常文字
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        color: textColor,
        fontWeight: FontWeight.w400,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// 判断任务是否已过期
  /// 使用 AmberDateUtils 确保跨时区一致性
  bool _isOverdue(DateTime dueDate) {
    return AmberDateUtils.isOverdue(dueDate);
  }

  /// 获取截止日期的显示颜色
  /// [dueDate] 截止日期
  /// [overdueColor] 过期任务的自定义颜色，可选，默认使用 AmberColors.warning
  Color _getDueDateColor(DateTime dueDate, {Color? overdueColor}) {
    if (AmberDateUtils.isOverdue(dueDate)) {
      return overdueColor ?? AmberColors.warning; // 过期：使用自定义颜色或默认警告色
    } else if (AmberDateUtils.isToday(dueDate)) {
      return AmberColors.primary; // 今天
    }
    return AmberColors.textSecondary; // 未来
  }

  /// 格式化截止日期为友好文本
  /// 使用 AmberDateUtils 确保跨时区一致性
  String _formatDueDate(DateTime date) {
    if (AmberDateUtils.isOverdue(date)) {
      return '已过期';
    } else if (AmberDateUtils.isToday(date)) {
      return '今天';
    } else if (AmberDateUtils.isTomorrow(date)) {
      return '明天';
    } else {
      return DateFormat('M月d日').format(date);
    }
  }

  /// 判断是否应该隐藏日期标签
  /// 在「今天」视图下，今天的任务不需要显示「今天」标签（冗余信息）
  bool _shouldHideDateLabel(NavView currentView, DateTime dueDate) {
    // 在「今天」视图下，如果任务截止日期是今天，则隐藏日期标签
    if (currentView == NavView.today && AmberDateUtils.isToday(dueDate)) {
      return true;
    }
    return false;
  }
}

/// 半勾图标绘制器
/// 用于绘制任务"进行中"状态的半勾标记
class _HalfCheckPainter extends CustomPainter {
  final Color color;

  _HalfCheckPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // 绘制半勾：只画勾的前半部分（左下到中心）
    // 完整勾的路径：左下 -> 中下 -> 右上
    // 半勾只画：左下 -> 中下
    final path = Path();

    // 起点：左侧偏下
    final startX = size.width * 0.2;
    final startY = size.height * 0.5;

    // 终点：中间偏下（勾的拐点）
    final endX = size.width * 0.45;
    final endY = size.height * 0.7;

    path.moveTo(startX, startY);
    path.lineTo(endX, endY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HalfCheckPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// 半宽度裁剪器
/// 用于裁剪删除线，只显示左半部分
class _HalfWidthClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    // 只保留左半部分
    return Rect.fromLTWH(0, 0, size.width * 0.5, size.height);
  }

  @override
  bool shouldReclip(covariant _HalfWidthClipper oldClipper) => false;
}

























