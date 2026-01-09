import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/constants.dart';
import '../../data/models/models.dart';
import '../providers/providers.dart';
import 'task_item.dart';

/// 已过期任务区域组件
///
/// 设计哲学：
/// - 放置在"今天"视图的顶部
/// - 红色高亮警示用户有过期任务需要处理
/// - 提供"全部顺延"和单个"顺延"按钮
/// - 可折叠设计，避免占用过多空间
/// - 折叠状态持久化到 SharedPreferences
class OverdueTasksSection extends ConsumerWidget {
  /// 已过期的任务列表
  final List<Task> overdueTasks;

  const OverdueTasksSection({
    super.key,
    required this.overdueTasks,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 如果没有过期任务，不显示此区域
    if (overdueTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    // 从 Provider 读取折叠状态
    final taskManagementSettings = ref.watch(taskManagementSettingsProvider);
    final isExpanded = taskManagementSettings.overdueExpanded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏：已过期 (N) + 全部顺延按钮
        _OverdueSectionHeader(
          count: overdueTasks.length,
          isExpanded: isExpanded,
        ),

        // 过期任务列表（可折叠）
        if (isExpanded) ...[
          ...overdueTasks.map((task) => _OverdueTaskItem(task: task)),
          // 底部分隔线
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AmberDimens.spacingMd,
              vertical: AmberDimens.spacingSm,
            ),
            child: Divider(height: 1),
          ),
        ],
      ],
    );
  }
}

/// 已过期区域标题栏组件
class _OverdueSectionHeader extends ConsumerWidget {
  final int count;
  final bool isExpanded;

  const _OverdueSectionHeader({
    required this.count,
    required this.isExpanded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displaySettings = ref.watch(displaySettingsProvider);
    final overdueColor = Color(displaySettings.overdueLabelColorValue);

    return InkWell(
      onTap: () {
        // 切换折叠状态并持久化
        ref.read(taskManagementSettingsProvider.notifier).toggleOverdueExpanded();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AmberDimens.spacingMd + 8,
          vertical: AmberDimens.spacingSm,
        ),
        child: Row(
          children: [
            // 展开/折叠图标
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_right_rounded,
              color: overdueColor,
              size: 20,
            ),
            const SizedBox(width: 4),
            // 警告图标
            Icon(
              Icons.warning_amber_rounded,
              color: overdueColor,
              size: 18,
            ),
            const SizedBox(width: 6),
            // 标题
            Text(
              '已过期',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: overdueColor,
              ),
            ),
            const SizedBox(width: 6),
            // 数量 Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: overdueColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: overdueColor,
                ),
              ),
            ),
            const Spacer(),
            // 全部顺延按钮
            TextButton.icon(
              onPressed: () => _postponeAll(context, ref, count),
              icon: Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: overdueColor,
              ),
              label: Text(
                '全部顺延',
                style: TextStyle(
                  fontSize: 12,
                  color: overdueColor,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 全部顺延（带确认弹窗）
  Future<void> _postponeAll(BuildContext context, WidgetRef ref, int count) async {
    // 二次确认弹窗
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认顺延'),
        content: Text('确定要将 $count 个过期任务全部顺延到今天吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认顺延'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 播放声音
    ref.read(soundServiceProvider).playCompletion();

    // 执行顺延
    await ref.read(taskProvider.notifier).postponeAllOverdueTasks();

    // 显示提示
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已将 $count 个任务顺延到今天'),
          behavior: SnackBarBehavior.floating,
          width: 300,
        ),
      );
    }
  }
}

/// 过期任务项组件
///
/// 在标准 TaskItem 基础上增加"顺延"按钮
class _OverdueTaskItem extends ConsumerWidget {
  final Task task;

  const _OverdueTaskItem({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displaySettings = ref.watch(displaySettingsProvider);

    return Stack(
      children: [
        // 标准任务项
        TaskItem(task: task),

        // 右侧顺延按钮（悬浮在任务项上方）
        Positioned(
          right: AmberDimens.spacingMd + 8,
          top: 0,
          bottom: 0,
          child: Center(
            child: _PostponeButton(
              task: task,
              overdueColor: Color(displaySettings.overdueLabelColorValue),
            ),
          ),
        ),
      ],
    );
  }
}

/// 单个任务的顺延按钮
class _PostponeButton extends ConsumerStatefulWidget {
  final Task task;
  final Color overdueColor;

  const _PostponeButton({
    required this.task,
    required this.overdueColor,
  });

  @override
  ConsumerState<_PostponeButton> createState() => _PostponeButtonState();
}

class _PostponeButtonState extends ConsumerState<_PostponeButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // 只有 hover 时才显示按钮，减少视觉干扰
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _isHovered ? 1.0 : 0.0,
        child: TextButton.icon(
          onPressed: _postpone,
          icon: Icon(
            Icons.arrow_forward_rounded,
            size: 14,
            color: widget.overdueColor,
          ),
          label: Text(
            '顺延',
            style: TextStyle(
              fontSize: 11,
              color: widget.overdueColor,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            minimumSize: const Size(0, 24),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: widget.overdueColor.withValues(alpha: 0.1),
          ),
        ),
      ),
    );
  }

  /// 顺延单个任务
  Future<void> _postpone() async {
    // 播放声音
    ref.read(soundServiceProvider).playCompletion();

    // 执行顺延
    await ref.read(taskProvider.notifier).postponeTask(widget.task.id);

    // 格式化原截止日期
    final originalDate = widget.task.dueDate != null
        ? DateFormat('M月d日', 'zh_CN').format(widget.task.dueDate!)
        : '未知';

    // 显示提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已将任务从 $originalDate 顺延到今天'),
          behavior: SnackBarBehavior.floating,
          width: 350,
        ),
      );
    }
  }
}
