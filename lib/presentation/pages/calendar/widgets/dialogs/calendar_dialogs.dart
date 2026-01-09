import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../data/models/models.dart';
import 'day_task_list_dialog.dart';
import 'spotlight_dialog.dart';

/// 日历相关对话框入口类
/// 提供统一的静态方法显示各种日历相关弹窗
///
/// 包含以下弹窗：
/// - 当天任务列表弹窗 (showDayTaskListDialog)
/// - Spotlight 快速添加弹窗 (showSpotlightSearch)
class CalendarDialogs {
  /// 显示当天任务列表对话框
  ///
  /// 单击日历单元格时弹出，展示该天的所有任务
  /// 支持两种布局模式（可在弹窗内切换）：
  /// - 单列模式：任务列表全宽，双击任务弹出编辑对话框
  /// - 双列模式：左侧任务列表 + 右侧详情面板，单击选中任务
  ///
  /// [context] 上下文
  /// [day] 要显示任务的日期
  /// [initialTasks] 初始任务列表（预留参数，实际从 Provider 获取）
  static void showDayTaskListDialog(
    BuildContext context,
    DateTime day,
    List<Task> initialTasks,
  ) {
    showDialog(
      context: context,
      builder: (context) => DayTaskListDialog(day: day),
    );
  }

  /// 显示 Spotlight 搜索对话框
  ///
  /// 双击日历单元格时弹出，支持快速添加任务
  /// - 紧凑模式：只有标题输入框，回车即可添加
  /// - 展开模式：点击展开按钮显示截止日期、清单、优先级、标签选项
  ///
  /// [context] 上下文
  /// [ref] Riverpod WidgetRef（预留参数，SpotlightDialog 内部已自带）
  /// [selectedDay] 选中的日期
  /// [focusedDay] 聚焦的日期（用于 selectedDay 为空时的默认值）
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
                // SpotlightDialog 内部已经是 ConsumerStatefulWidget
                // 会直接通过 ref 创建任务，不需要外部回调
                child: SpotlightDialog(
                  selectedDate: selectedDay ?? focusedDay,
                  onTaskCreated: (_) {
                    // 任务创建已在 SpotlightDialog 内部处理
                    // 保留此回调仅为 API 兼容性
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
