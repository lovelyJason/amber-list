import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../data/models/models.dart';
import '../../../providers/providers.dart';
import '../../../widgets/task_item.dart';
import '../../../widgets/common/toast/toast_manager.dart';
import 'spotlight_dialog.dart';

/// 日历相关对话框
/// 包含任务列表弹窗、Spotlight 搜索等
class CalendarDialogs {
  /// 显示当天任务列表对话框
  /// 包含任务输入框和任务列表
  static void showDayTaskListDialog(
    BuildContext context,
    DateTime day,
    List<Task> initialTasks,
  ) {
    showDialog(
      context: context,
      builder: (context) => _DayTaskListDialog(day: day),
    );
  }

  /// 显示 Spotlight 搜索对话框
  static void showSpotlightSearch(
    BuildContext context,
    WidgetRef ref, {
    required DateTime? selectedDay,
    required DateTime focusedDay,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 100),
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 600,
                child: SpotlightDialog(
                  selectedDate: selectedDay ?? focusedDay,
                  onTaskCreated: (title) {
                    final date = selectedDay ?? focusedDay;
                    ref
                        .read(taskProvider.notifier)
                        .createTask(title: title, dueDate: date);
                    // 播放任务添加音效
                    ref.read(soundServiceProvider).playAdd();
                    ToastManager().show(
                      context,
                      '任务已添加至 ${DateFormat('M月d日', 'zh_CN').format(date)}',
                      type: ToastType.success,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// 当天任务列表弹窗组件
/// 包含任务输入框（与清单页一致）和任务列表
class _DayTaskListDialog extends ConsumerStatefulWidget {
  final DateTime day;

  const _DayTaskListDialog({required this.day});

  @override
  ConsumerState<_DayTaskListDialog> createState() => _DayTaskListDialogState();
}

class _DayTaskListDialogState extends ConsumerState<_DayTaskListDialog> {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isAddingTask = false;

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 添加任务
  void _addTask(String title) {
    if (title.trim().isEmpty) return;

    // 规范化为 UTC 日期存储，确保跨设备同步时日期一致
    final normalizedDate = AmberDateUtils.normalizeToUtcDate(widget.day);

    ref.read(soundServiceProvider).playAdd();
    ref.read(taskProvider.notifier).createTask(
          title: title.trim(),
          dueDate: normalizedDate,
        );

    _inputController.clear();
    setState(() => _isAddingTask = false);
  }

  @override
  Widget build(BuildContext context) {
    final allTasks = ref.watch(taskProvider);
    final currentDayTasks = allTasks.where((task) {
      // 过滤已删除的任务（垃圾桶里的不显示）
      if (task.isDeleted) return false;
      if (task.dueDate == null) return false;
      return isSameDay(task.dueDate!, widget.day);
    }).toList();

    return AlertDialog(
      title: Text(
        DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(widget.day),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 400,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            // 任务输入框（与清单页一致的样式）
            _buildQuickAdd(),
            const SizedBox(height: AmberDimens.spacingSm),
            // 任务列表
            Expanded(
              child: currentDayTasks.isEmpty
                  ? Center(
                      child: Text(
                        '暂无任务',
                        style: TextStyle(
                          color: AmberColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: currentDayTasks.length,
                      itemBuilder: (context, index) {
                        return TaskItem(task: currentDayTasks[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            for (var task in currentDayTasks) {
              if (!task.isCompleted) {
                ref.read(taskProvider.notifier).toggleTaskComplete(task.id);
              }
            }
          },
          child: const Text('全选'),
        ),
        TextButton(
          onPressed: () {
            for (var task in currentDayTasks) {
              ref.read(taskProvider.notifier).toggleTaskComplete(task.id);
            }
          },
          child: const Text('反选'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  /// 构建快速添加任务输入框（与清单页样式一致）
  Widget _buildQuickAdd() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AmberDimens.spacingMd,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isAddingTask ? AmberColors.primary : const Color(0xFFEEEEEE),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.add_rounded,
            color: AmberColors.primary,
            size: 24,
          ),
          const SizedBox(width: AmberDimens.spacingMd),
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _focusNode,
              decoration: const InputDecoration(
                hintText: '添加任务...',
                hintStyle: TextStyle(
                  color: AmberColors.textDisabled,
                  fontSize: 15,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 15),
              onTap: () => setState(() => _isAddingTask = true),
              onSubmitted: _addTask,
            ),
          ),
          if (_isAddingTask)
            IconButton(
              onPressed: () => _addTask(_inputController.text),
              icon: const Icon(Icons.arrow_upward_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: AmberColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(32, 32),
              ),
              color: Colors.white,
            ),
        ],
      ),
    );
  }
}
