import 'dart:convert';
import 'dart:io';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../pages/sticky_note/sticky_note_registry.dart';
import 'adaptive/detail_bottom_sheet.dart';
import 'common/toast/toast_manager.dart';
import 'common/toast/toast_types.dart';
import '../../core/constants/constants.dart';
import '../../core/services/native_sticky_note_service.dart';
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

  const TaskItem({
    super.key,
    required this.task,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(appNavProvider);
    final isSelected = navState.selectedTaskId == task.id;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AmberDimens.spacingMd,
        vertical: 4, // 减小垂直间距，更紧凑
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // 更圆润的角
        border: Border.all(
          color: isSelected ? AmberColors.primary : const Color(0xFFEEEEEE),
          width: 1, // 极细边框
        ),
        boxShadow: [
          if (!task.isCompleted) // 未完成任务加一点微弱的阴影
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () {
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
            child: Row(
              children: [
                _buildCheckbox(ref),
                const SizedBox(width: AmberDimens.spacingMd),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      // 获取显示设置
                      final displaySettings = ref.watch(displaySettingsProvider);

                      // 判断是否需要显示日期
                      // 条件：1. 全局设置开启 2. 有截止日期 3. 不是在「今天」视图下的今天任务
                      final shouldShowDate = displaySettings.showDueDate &&
                          task.dueDate != null &&
                          !_shouldHideDateLabel(navState.currentView, task.dueDate!);

                      // 判断是否需要显示标签
                      final shouldShowTags = displaySettings.showTags && task.tags.isNotEmpty;

                      // 判断任务是否已过期
                      final isOverdue = task.dueDate != null && _isOverdue(task.dueDate!);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 15,
                              // 标题颜色优先级：已完成 > 已过期 > 普通
                              color: task.isCompleted
                                  ? AmberColors.textCompleted
                                  : isOverdue
                                      ? Color(displaySettings.overdueTitleColorValue)
                                      : AmberColors.textPrimary,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (shouldShowDate || shouldShowTags)
                            const SizedBox(height: 4),
                          // 第二行：日期+标签（用Flexible包裹防止移动端overflow）
                          if (shouldShowDate || shouldShowTags)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // 日期部分（固定宽度，不会溢出）
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
                                // 标签部分（直接展开，避免嵌套导致对齐问题）
                                if (shouldShowTags) ...[
                                  if (shouldShowDate) const SizedBox(width: AmberDimens.spacingSm),
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
                    },
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AmberDimens.spacingMd),
                  trailing!,
                ],
              ],
            ),
          ),
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
              // Confirm dialog? User requested "Delete", typically implies permanent here.
              // Let's do it directly or quick confirm.
              // Given "instant" vibe, maybe direct? Or simple confirm.
              // Let's add simple confirm for safety.
              Future.delayed(Duration.zero, () {
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
          ref.read(soundServiceProvider).playDelete();
          // 播放抛物线动画，动画完成后执行删除
          TrashAnimationService.instance.playTrashAnimation(
            context,
            position,
            onComplete: () {
              ref.read(taskProvider.notifier).deleteTask(task.id);
            },
          );
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
    final titleController = TextEditingController(text: task.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑任务'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(labelText: '任务名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                ref
                    .read(taskProvider.notifier)
                    .updateTask(
                      task.copyWith(title: titleController.text.trim()),
                    );
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

    // ========== Fallback: Flutter 多窗口实现 ==========
    // 用于不支持原生便签的平台或原生创建失败时

    // Check registry
    if (ref.read(stickyNoteRegistryProvider.notifier).isOpen(task.id)) {
      // 获取已注册的windowId
      final existingWindowId =
          ref.read(stickyNoteRegistryProvider.notifier).getWindowId(task.id);

      if (existingWindowId != null) {
        // 验证窗口是否真的还活着
        bool isAlive = false;
        try {
          await DesktopMultiWindow.invokeMethod(
            existingWindowId,
            'ping',
          ).timeout(const Duration(milliseconds: 500));
          isAlive = true;
        } catch (e) {
          // 窗口已死,清理注册表
          debugPrint('[TaskItem] 窗口$existingWindowId已失效,清理注册表');
          ref.read(stickyNoteRegistryProvider.notifier).unregister(task.id);
          isAlive = false;
        }

        if (isAlive) {
          // 窗口还活着,显示警告
          if (context.mounted) {
            ToastManager().show(context, '当前已打开便签', type: ToastType.warning);
          }
          return;
        }
        // 窗口已死,继续创建新窗口
      }
    }

    // 创建独立窗口
    final window = await DesktopMultiWindow.createWindow(
      jsonEncode({
        'id': task.id, // Add ID for registry
        'type': 'sticky_note',
        'title': task.title,
        'content': task.description ?? '', // Include description if available
        'themeColor':
            '0xFFE1F5FE', // Default Blue for tasks to distinguish from lists
      }),
    );

    // Register window
    ref
        .read(stickyNoteRegistryProvider.notifier)
        .register(task.id, window.windowId);

    // 设置窗口大小和位置
    window
      ..setFrame(const Offset(0, 0) & const Size(300, 300))
      ..center()
      ..setTitle('便签: ${task.title}')
      ..show();
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
      ),
    );
  }

  /// 判断任务是否已过期
  bool _isOverdue(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.isBefore(today);
  }

  /// 获取截止日期的显示颜色
  /// [dueDate] 截止日期
  /// [overdueColor] 过期任务的自定义颜色，可选，默认使用 AmberColors.warning
  Color _getDueDateColor(DateTime dueDate, {Color? overdueColor}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (due.isBefore(today)) {
      return overdueColor ?? AmberColors.warning; // 过期：使用自定义颜色或默认警告色
    } else if (due.isAtSameMomentAs(today)) {
      return AmberColors.primary; // 今天
    }
    return AmberColors.textSecondary; // 未来
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final due = DateTime(date.year, date.month, date.day);

    if (due.isBefore(today)) {
      return '已过期';
    } else if (due.isAtSameMomentAs(today)) {
      return '今天';
    } else if (due.isAtSameMomentAs(tomorrow)) {
      return '明天';
    } else {
      return DateFormat('M月d日').format(date);
    }
  }

  /// 判断是否应该隐藏日期标签
  /// 在「今天」视图下，今天的任务不需要显示「今天」标签（冗余信息）
  bool _shouldHideDateLabel(NavView currentView, DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);

    // 在「今天」视图下，如果任务截止日期是今天，则隐藏日期标签
    if (currentView == NavView.today && due.isAtSameMomentAs(today)) {
      return true;
    }

    return false;
  }
}

























