import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../data/models/models.dart';
import '../../../providers/providers.dart';
import '../../../widgets/task_item.dart';
import '../../../widgets/common/toast/toast_manager.dart';
import 'spotlight_dialog.dart';

/// 日历相关对话框
/// 包含任务列表弹窗、Spotlight 搜索等
class CalendarDialogs {
  /// 显示当天任务列表对话框
  static void showDayTaskListDialog(
    BuildContext context,
    DateTime day,
    List<Task> initialTasks,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final allTasks = ref.watch(taskProvider);
            final currentDayTasks = allTasks.where((task) {
              // 过滤已删除的任务（垃圾桶里的不显示）
              if (task.isDeleted) return false;
              if (task.dueDate == null) return false;
              return isSameDay(task.dueDate!, day);
            }).toList();

            return AlertDialog(
              title: Text(
                DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(day),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 400,
                height: MediaQuery.of(context).size.height * 0.6,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: currentDayTasks.length,
                  itemBuilder: (context, index) {
                    return TaskItem(task: currentDayTasks[index]);
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    for (var task in currentDayTasks) {
                      if (!task.isCompleted) {
                        ref
                            .read(taskProvider.notifier)
                            .toggleTaskComplete(task.id);
                      }
                    }
                  },
                  child: const Text('全选'),
                ),
                TextButton(
                  onPressed: () {
                    for (var task in currentDayTasks) {
                      ref
                          .read(taskProvider.notifier)
                          .toggleTaskComplete(task.id);
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
          },
        );
      },
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
      barrierColor: Colors.black.withOpacity(0.5),
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
