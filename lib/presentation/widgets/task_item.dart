import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../pages/sticky_note/sticky_note_registry.dart';
import 'common/toast/toast_manager.dart';
import 'common/toast/toast_types.dart';
import '../../core/constants/constants.dart';
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
            ref.read(appNavProvider.notifier).selectTask(task.id);
          },
          onSecondaryTapDown: (details) {
            _showContextMenu(context, ref, details.globalPosition);
          },
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 15,
                          color: task.isCompleted
                              ? AmberColors.textCompleted
                              : AmberColors.textPrimary,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (task.dueDate != null || task.tags.isNotEmpty)
                        const SizedBox(height: 4),
                      if (task.dueDate != null || task.tags.isNotEmpty)
                        Row(
                          children: [
                            if (task.dueDate != null) ...[
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 12,
                                color: _getDueDateColor(task.dueDate!),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDueDate(task.dueDate!),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getDueDateColor(task.dueDate!),
                                ),
                              ),
                            ],
                            if (task.tags.isNotEmpty) ...[
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
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tagColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: tagColor.withOpacity(0.2), // 微弱的边框
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
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                    ],
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
          value: 'edit',
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onTap: () {
            // 触发编辑可能需要通知父组件或弹窗，简单起见先弹窗
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
              ), // Flag often used for priority
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
            ref.read(taskProvider.notifier).deleteTask(task.id);
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

  Color _getDueDateColor(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (due.isBefore(today)) {
      return AmberColors.warning; // 过期
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
}

























