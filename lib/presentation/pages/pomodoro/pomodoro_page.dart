import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'dart:math' as math;
import '../../../core/constants/constants.dart';
import '../../../core/services/pomodoro_timer.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/adaptive/bottom_nav_bar.dart';
import '../../widgets/common/toast/toast_manager.dart';

/// 番茄时钟页面
class PomodoroPage extends ConsumerStatefulWidget {
  const PomodoroPage({super.key});

  @override
  ConsumerState<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends ConsumerState<PomodoroPage> {
  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(pomodoroTimerProvider);
    final timerState = timer.state;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile =
            constraints.maxWidth < ResponsiveHelper.mobileBreakpoint;

        if (isMobile) {
          return _buildMobileLayout(context, timerState);
        } else {
          return _buildDesktopLayout(context, timerState);
        }
      },
    );
  }

  /// 构建桌面端布局（原有布局）
  Widget _buildDesktopLayout(BuildContext context, PomodoroTimerState timerState) {
    return Row(
      children: [
        // 左侧: 专注模式面板
        Expanded(
          flex: 2,
          child: _buildFocusModePanel(context, timerState),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        // 右侧: 任务队列
        Expanded(
          flex: 1,
          child: _buildSessionQueuePanel(context),
        ),
      ],
    );
  }

  /// 构建移动端布局
  /// 移动端使用垂直布局，上方是番茄钟，下方是简化的任务队列
  Widget _buildMobileLayout(BuildContext context, PomodoroTimerState timerState) {
    return Scaffold(
      backgroundColor: AmberColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 专注模式面板（缩小版）
            Expanded(
              flex: 3,
              child: _buildMobileFocusPanel(context, timerState),
            ),
            // 分隔线
            const Divider(height: 1),
            // 任务队列（简化版）
            Expanded(
              flex: 2,
              child: _buildMobileQueuePanel(context),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const MobileBottomNavBar(),
    );
  }

  /// 移动端专注面板（简化版）
  Widget _buildMobileFocusPanel(
    BuildContext context,
    PomodoroTimerState timerState,
  ) {
    return Container(
      color: AmberColors.background,
      padding: const EdgeInsets.all(AmberDimens.spacingMd),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 模式切换胶囊
          Center(child: _buildCapsuleModeSwitcher(timerState)),
          const SizedBox(height: AmberDimens.spacingLg),

          // 圆形倒计时器（稍小）
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(200, 200),
                  painter: _CircularProgressPainter(
                    progress: timerState.currentType.defaultDuration > 0
                        ? (timerState.currentType.defaultDuration -
                                timerState.remainingSeconds) /
                            timerState.currentType.defaultDuration
                        : 0.0,
                    fillColor: _getColorForType(timerState.currentType),
                    backgroundColor: AmberColors.divider,
                    strokeWidth: 10.0,
                  ),
                ),
                Text(
                  '${(timerState.remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(timerState.remainingSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 40,
                    color: AmberColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AmberDimens.spacingLg),

          // 控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 重置按钮
              IconButton(
                onPressed: () {
                  ref.read(pomodoroControllerProvider.notifier).reset();
                },
                icon: const Icon(Icons.refresh),
                tooltip: '重置',
              ),
              const SizedBox(width: AmberDimens.spacingMd),
              // 开始/暂停按钮
              ElevatedButton.icon(
                onPressed: () {
                  final controller = ref.read(pomodoroControllerProvider.notifier);
                  if (timerState.status == TimerStatus.running) {
                    controller.pause();
                  } else if (timerState.status == TimerStatus.paused) {
                    controller.resume();
                  } else {
                    controller.startPomodoro();
                  }
                },
                icon: Icon(
                  timerState.status == TimerStatus.running
                      ? Icons.pause
                      : Icons.play_arrow,
                  size: 24,
                ),
                label: Text(
                  timerState.status == TimerStatus.running
                      ? '暂停'
                      : (timerState.status == TimerStatus.paused ? '继续' : '开始'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 移动端任务队列面板（简化版）
  Widget _buildMobileQueuePanel(BuildContext context) {
    final queueAsync = ref.watch(pomodoroQueueProvider);

    return Container(
      color: AmberColors.sidebarBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Padding(
            padding: const EdgeInsets.all(AmberDimens.spacingMd),
            child: Row(
              children: [
                const Text(
                  '任务队列',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AmberColors.textPrimary,
                  ),
                ),
                const Spacer(),
                // 添加按钮
                TextButton.icon(
                  onPressed: () => _showTaskSelectionDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加'),
                  style: TextButton.styleFrom(
                    foregroundColor: AmberColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 队列列表
          Expanded(
            child: queueAsync.when(
              data: (queue) {
                if (queue.isEmpty) {
                  return const Center(
                    child: Text(
                      '点击添加按钮添加任务',
                      style: TextStyle(
                        color: AmberColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AmberDimens.spacingMd,
                  ),
                  itemCount: queue.length,
                  itemBuilder: (context, index) {
                    final item = queue[index];
                    final task = item.task;
                    final isActive = index == 0;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isActive ? Icons.play_circle : Icons.circle_outlined,
                        color: isActive
                            ? AmberColors.primary
                            : AmberColors.textDisabled,
                      ),
                      title: Text(
                        task?.title ?? 'Unknown',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      trailing: IconButton(
                        onPressed: () => removeTaskFromQueue(ref, item.id),
                        icon: const Icon(Icons.close, size: 18),
                        color: AmberColors.textSecondary,
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('错误: $error')),
            ),
          ),
        ],
      ),
    );
  }

  /// 专注模式面板
  Widget _buildFocusModePanel(
    BuildContext context,
    PomodoroTimerState timerState,
  ) {
    final queueAsync = ref.watch(pomodoroQueueProvider);

    return Container(
      color: AmberColors.background,
      child: Stack(
        children: [
          // 光晕背景 - 调整为不对称光晕
          // 中心点向左偏移，大幅向下移动以避开顶部胶囊，并确保底部覆盖
          Center(
            child: Transform.translate(
              offset: const Offset(0, 100), // 大幅向下偏移，彻底避开上方元素
              child: Container(
                height: 700, // 增加容器高度，提供足够渐变空间
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.15, 0.0), // 向右微调，增加右侧光晕覆盖
                    radius: 0.5, // 半径设为0.5(即接触容器边缘)，彻底消除截断
                    colors: [
                      _getColorForType(
                        timerState.currentType,
                      ).withOpacity(0.35),
                      _getColorForType(timerState.currentType).withOpacity(0.1),
                      AmberColors.background.withOpacity(0.0),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // 内容层
          Padding(
            padding: const EdgeInsets.all(AmberDimens.spacingXl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 标题（根据模式动态变化）
                Text(
                  _getModeTitle(timerState.currentType),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AmberColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getModeSubtitle(timerState.currentType),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AmberColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AmberDimens.spacingXl),

                // 模式切换胶囊
                Center(child: _buildCapsuleModeSwitcher(timerState)),
                const SizedBox(height: AmberDimens.spacingXl * 2),

                // 自定义圆形倒计时器 (纯静态,根据state显示)
                // 自定义圆形倒计时器 (纯静态,根据state显示)
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // 番茄梗装饰 (位于时钟上方)
                    Positioned(
                      top: -40, // 向下移动，使梗的根部连接到番茄上
                      child: CustomPaint(
                        size: const Size(120, 60), // 增加高度以容纳下垂的叶子
                        painter: _TomatoStemPainter(),
                      ),
                    ),
                    _CustomCircularTimer(
                      remainingSeconds: timerState.remainingSeconds,
                      totalSeconds: timerState.currentType.defaultDuration,
                      fillColor: _getColorForType(timerState.currentType),
                    ),
                  ],
                ),
                const SizedBox(height: AmberDimens.spacingXl),

                // 当前任务显示（只要队列不为空就显示）
                Center(
                  child: queueAsync.when(
                    data: (queue) => queue.isNotEmpty
                        ? _buildCurrentTaskCard(queue.first.task)
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (error, stack) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: AmberDimens.spacingXl),

                // 控制按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 重置按钮
                    IconButton(
                      onPressed: () {
                        ref.read(pomodoroControllerProvider.notifier).reset();
                      },
                      icon: const Icon(Icons.refresh),
                      tooltip: '重置',
                    ),
                    const SizedBox(width: AmberDimens.spacingLg),
                    // 开始/暂停按钮
                    ElevatedButton.icon(
                      onPressed: () {
                        final controller = ref.read(
                          pomodoroControllerProvider.notifier,
                        );
                        if (timerState.status == TimerStatus.running) {
                          controller.pause();
                        } else if (timerState.status == TimerStatus.paused) {
                          controller.resume();
                        } else {
                          controller.startPomodoro();
                        }
                      },
                      icon: Icon(
                        timerState.status == TimerStatus.running
                            ? Icons.pause
                            : Icons.play_arrow,
                        size: 24,
                      ),
                      label: Text(
                        timerState.status == TimerStatus.running
                            ? '暂停'
                            : (timerState.status == TimerStatus.paused
                                  ? '继续'
                                  : '开始'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 胶囊样式模式切换器
  Widget _buildCapsuleModeSwitcher(PomodoroTimerState timerState) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE8E0), // 浅灰色背景
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCapsuleOption(
            '番茄钟',
            PomodoroSessionType.focus,
            timerState.currentType == PomodoroSessionType.focus,
            timerState,
          ),
          _buildCapsuleOption(
            '短休息',
            PomodoroSessionType.shortBreak,
            timerState.currentType == PomodoroSessionType.shortBreak,
            timerState,
          ),
          _buildCapsuleOption(
            '长休息',
            PomodoroSessionType.longBreak,
            timerState.currentType == PomodoroSessionType.longBreak,
            timerState,
          ),
        ],
      ),
    );
  }

  /// 单个胶囊选项
  Widget _buildCapsuleOption(
    String label,
    PomodoroSessionType type,
    bool isSelected,
    PomodoroTimerState timerState,
  ) {
    return GestureDetector(
      onTap: () {
        // 检查是否正在运行番茄钟
        if (timerState.status == TimerStatus.running) {
          // 正在运行,不允许切换,弹Toast警告
          ToastManager().show(
            context,
            '番茄钟运行中,请先暂停或等待结束',
            type: ToastType.warning,
            position: ToastPosition.top,
          );
          return;
        }

        // 允许切换
        ref.read(pomodoroControllerProvider.notifier).switchType(type);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? const Color(0xFF4A4A4A)
                : const Color(0xFF9B9B9B),
          ),
        ),
      ),
    );
  }

  /// 任务队列面板
  Widget _buildSessionQueuePanel(BuildContext context) {
    final queueAsync = ref.watch(pomodoroQueueProvider);
    final timer = ref.watch(pomodoroTimerProvider);
    final timerState = timer.state;

    return Container(
      color: AmberColors.sidebarBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Padding(
            padding: const EdgeInsets.all(AmberDimens.spacingMd),
            child: Row(
              children: [
                const Text(
                  '任务队列',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AmberColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                queueAsync.when(
                  data: (queue) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AmberColors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${queue.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AmberColors.primary,
                      ),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 队列列表
          Expanded(
            child: queueAsync.when(
              data: (queue) {
                if (queue.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FluentIcons.timer_24_regular,
                          size: 48,
                          color: AmberColors.textDisabled,
                        ),
                        SizedBox(height: 8),
                        Text(
                          '队列空空如也',
                          style: TextStyle(
                            color: AmberColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '添加任务开始专注吧',
                          style: TextStyle(
                            color: AmberColors.textDisabled,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(AmberDimens.spacingMd),
                  itemCount: queue.length,
                  itemBuilder: (context, index) {
                    final item = queue[index];
                    final task = item.task;
                    final isActive = index == 0; // 第一个任务为Active

                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: AmberDimens.spacingMd,
                      ),
                      child: _buildQueueCard(
                        task: task,
                        item: item,
                        isActive: isActive,
                        timerState: timerState,
                        onRemove: () => removeTaskFromQueue(ref, item.id),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('加载失败: $error'),
              ),
            ),
          ),
          // 添加按钮
          Padding(
            padding: const EdgeInsets.all(AmberDimens.spacingMd),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showTaskSelectionDialog(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('从清单添加任务'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AmberColors.primary,
                  side: const BorderSide(color: AmberColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示任务选择对话框
  void _showTaskSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => _TaskSelectionDialog(
        ref: ref,
        onSelected: (task) {
          // 添加到队列（默认预估1个番茄钟）
          ref
              .read(pomodoroControllerProvider.notifier)
              .addToQueue(task.id, estimatedPomodoros: 1);
          Navigator.pop(dialogContext);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已添加 "${task.title}" 到专注队列'),
                width: 400,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  /// 构建队列任务卡片（还原设计稿样式）
  Widget _buildQueueCard({
    required Task? task,
    required PomodoroQueueItemModel item,
    required bool isActive,
    required PomodoroTimerState timerState,
    required VoidCallback onRemove,
  }) {
    final taskTitle = task?.title ?? 'Unknown Task';

    // 计算进度: Active时用倒计时进度,否则用番茄数进度
    final double progress;
    if (isActive && timerState.status == TimerStatus.running) {
      // 倒计时进度 = (总时长 - 剩余时长) / 总时长
      final totalSeconds = timerState.currentType.defaultDuration;
      final elapsedSeconds = totalSeconds - timerState.remainingSeconds;
      progress = totalSeconds > 0 ? elapsedSeconds / totalSeconds : 0.0;
    } else {
      // 番茄数进度
      progress = item.completedPomodoros / item.estimatedPomodoros;
    }

    return Container(
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFFFF9E6) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border(
                left: const BorderSide(color: AmberColors.primary, width: 4),
                top: const BorderSide(color: AmberColors.primary, width: 1),
                right: const BorderSide(color: AmberColors.primary, width: 1),
                bottom: const BorderSide(color: AmberColors.primary, width: 1),
              )
            : Border.all(color: AmberColors.divider, width: 1),
      ),
      child: Stack(
        children: [
          // 背景小圆点装饰（仅Active显示）
          if (isActive)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: CustomPaint(painter: _DotPatternPainter()),
              ),
            ),

          // 内容区域
          Padding(
            padding: EdgeInsets.fromLTRB(isActive ? 20 : 16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 左侧图标
                    if (isActive)
                      // Active: 播放图标
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AmberColors.primary,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          size: 16,
                          color: Colors.white,
                        ),
                      )
                    else
                      // 非Active: 空心圆圈
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AmberColors.textDisabled,
                            width: 2,
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),

                    // 任务标题
                    Expanded(
                      child: Text(
                        taskTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: AmberColors.textPrimary,
                        ),
                      ),
                    ),

                    // 右上角Active标签
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AmberColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    // 删除按钮
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onRemove,
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: AmberColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 进度信息
                Row(
                  children: [
                    // 小圆点进度指示器（仅Active显示）
                    if (isActive)
                      Expanded(
                        child: Row(
                          children: List.generate(
                            item.estimatedPomodoros,
                            (index) => Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: index < item.completedPomodoros
                                      ? AmberColors.primary
                                      : AmberColors.divider,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // 文字进度（Active显示百分比，非Active显示预估）
                    Text(
                      isActive
                          ? '${(progress * 100).toInt()}%'
                          : 'Est. ${item.estimatedPomodoros} Pomodoro${item.estimatedPomodoros > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AmberColors.textSecondary,
                        fontWeight: isActive
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),

                // 进度条（仅Active显示）
                if (isActive) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: const Color(0xFFFFE5B4),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AmberColors.primary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 根据类型获取颜色
  Color _getColorForType(PomodoroSessionType type) {
    switch (type) {
      case PomodoroSessionType.focus:
        return AmberColors.primary;
      case PomodoroSessionType.shortBreak:
        return AmberColors.success;
      case PomodoroSessionType.longBreak:
        return AmberColors.info;
    }
  }

  /// 根据模式获取标题
  String _getModeTitle(PomodoroSessionType type) {
    switch (type) {
      case PomodoroSessionType.focus:
        return '专注模式';
      case PomodoroSessionType.shortBreak:
        return '短休息';
      case PomodoroSessionType.longBreak:
        return '长休息';
    }
  }

  /// 根据模式获取副标题
  String _getModeSubtitle(PomodoroSessionType type) {
    switch (type) {
      case PomodoroSessionType.focus:
        return '保持专注,高效追踪你的时间';
      case PomodoroSessionType.shortBreak:
        return '稍作休息,准备下一轮专注';
      case PomodoroSessionType.longBreak:
        return '好好放松,恢复精力继续前行';
    }
  }

  /// 当前正在进行的任务卡片
  Widget _buildCurrentTaskCard(Task? task) {
    if (task == null) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFAF0), // 更淡的米白色
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFFFFE8CC), // 更淡的边框
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 左侧番茄图标
            CustomPaint(size: const Size(20, 20), painter: _TomatoPainter(),
            ),
            const SizedBox(width: 10),
            // 文字（一行显示）
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: '正在专注: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFAA8866),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    TextSpan(
                      text: task.title,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5D4E37),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void removeTaskFromQueue(WidgetRef ref, String queueItemId) {
  ref.read(pomodoroControllerProvider.notifier).removeFromQueue(queueItemId);
}

/// 圆点背景装饰画笔（用于Active任务卡片）
class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AmberColors.primary.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    const dotRadius = 2.0;
    const spacing = 20.0;

    // 绘制均匀分布的小圆点
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 自定义圆形倒计时器 Widget
class _CustomCircularTimer extends StatelessWidget {
  final int remainingSeconds; // 剩余秒数
  final int totalSeconds; // 总秒数
  final Color fillColor; // 填充颜色

  const _CustomCircularTimer({
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    // 计算进度 (已过时间 / 总时间)
    final elapsedSeconds = totalSeconds - remainingSeconds;
    final progress = totalSeconds > 0 ? elapsedSeconds / totalSeconds : 0.0;

    // 格式化时间显示 (MM:SS)
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final timeText = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 圆环
          CustomPaint(
            size: const Size(280, 280),
            painter: _CircularProgressPainter(
              progress: progress,
              fillColor: fillColor,
              backgroundColor: AmberColors.divider,
              strokeWidth: 12.0,
            ),
          ),
          // 时间文字
          Text(
            timeText,
            style: const TextStyle(
              fontSize: 56,
              color: AmberColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// 圆形进度条画笔
class _CircularProgressPainter extends CustomPainter {
  final double progress; // 进度 0.0 - 1.0
  final Color fillColor; // 填充颜色
  final Color backgroundColor; // 背景颜色
  final double strokeWidth; // 线宽

  _CircularProgressPainter({
    required this.progress,
    required this.fillColor,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 背景圆环 (灰色)
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // 进度圆环 (彩色)
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // 从顶部(-90度)开始,顺时针绘制
      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // 起始角度 (顶部)
        sweepAngle, // 扫描角度
        false, // useCenter
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// 番茄图标画笔
class _TomatoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final tomatoBody = Paint()
      ..color =
          const Color(0xFFE53935) // 番茄红
      ..style = PaintingStyle.fill;

    final tomatoLeaf = Paint()
      ..color =
          const Color(0xFF43A047) // 叶子绿
      ..style = PaintingStyle.fill;

    // 绘制番茄身体（圆形偏扁）
    final bodyRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.55),
      width: size.width * 0.75,
      height: size.height * 0.7,
    );
    canvas.drawOval(bodyRect, tomatoBody);

    // 绘制顶部叶子（五角星形状的简化版）
    final leafPath = Path();
    final centerX = size.width * 0.5;
    final topY = size.height * 0.15;

    // 三片小叶子
    leafPath.moveTo(centerX, topY);
    leafPath.lineTo(centerX - 2, topY + 4);
    leafPath.lineTo(centerX - 1, topY);
    leafPath.close();

    leafPath.moveTo(centerX, topY);
    leafPath.lineTo(centerX + 2, topY + 4);
    leafPath.lineTo(centerX + 1, topY);
    leafPath.close();

    leafPath.moveTo(centerX, topY);
    leafPath.lineTo(centerX - 1, topY + 5);
    leafPath.lineTo(centerX + 1, topY + 5);
    leafPath.close();

    canvas.drawPath(leafPath, tomatoLeaf);

    // 添加高光效果
    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.35, size.height * 0.4),
      size.width * 0.15,
      highlight,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 番茄梗装饰画笔
class _TomatoStemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color =
          const Color(0xFFF3E5D0) // 米黄色/浅棕色
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    // 根部起始Y坐标 (画笔高度的一半偏下，留出上方给垂直梗，下方给下垂叶子)
    final rootY = 35.0; 

    // 绘制中间的垂直梗
    canvas.drawLine(
      Offset(centerX, rootY + 5), // 略微向下延伸以连接
      Offset(centerX, 10), // 顶部
      paint,
    );

    // 绘制左右两片叶子/须
    final path = Path();
    
    // 左侧曲线 - 末端下垂以贴合圆形
    path.moveTo(centerX, rootY);
    path.quadraticBezierTo(
      centerX - 25,
      rootY - 25, // 控制点 (拱起)
      centerX - 50,
      rootY + 15, // 终点 (下垂，低于根部)
    );

    // 右侧曲线 - 末端下垂
    path.moveTo(centerX, rootY);
    path.quadraticBezierTo(
      centerX + 25,
      rootY - 25, // 控制点 (拱起)
      centerX + 50,
      rootY + 15, // 终点 (下垂，低于根部)
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TaskSelectionDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  final Function(Task) onSelected;

  const _TaskSelectionDialog({required this.ref, required this.onSelected});

  @override
  ConsumerState<_TaskSelectionDialog> createState() =>
      _TaskSelectionDialogState();
}

class _TaskSelectionDialogState extends ConsumerState<_TaskSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showTodayOnly = true; // 默认显示"今天"的任务

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 获取所有未完成的任务
    final allTasks = ref
        .watch(taskProvider)
        .where((t) => !t.isCompleted && !t.isDeleted)
        .toList();

    // 根据选择过滤任务
    final filteredByDate = _showTodayOnly
        ? allTasks.where((t) {
            if (t.dueDate == null) return false;
            final today = DateTime.now();
            final todayStart = DateTime(today.year, today.month, today.day);
            final todayEnd = todayStart.add(const Duration(days: 1));
            return t.dueDate!.isAfter(todayStart) &&
                t.dueDate!.isBefore(todayEnd);
          }).toList()
        : allTasks; // 收集箱：显示所有任务

    // 搜索过滤
    final filteredTasks = _searchQuery.isEmpty
        ? filteredByDate
        : filteredByDate
              .where(
                (t) =>
                    t.title.toLowerCase().contains(_searchQuery.toLowerCase()),
              )
              .toList();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AmberDimens.radiusLg),
      ),
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(AmberDimens.spacingLg),
        child: Column(
          children: [
            // 头部
            Row(
              children: [
                const Text(
                  '选择任务',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AmberDimens.spacingMd),

            // 清单切换按钮
            Row(
              children: [
                _buildListFilterButton('今天', true),
                const SizedBox(width: AmberDimens.spacingSm),
                _buildListFilterButton('收集箱', false),
              ],
            ),
            const SizedBox(height: AmberDimens.spacingMd),

            // 搜索框
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索任务...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: AmberDimens.spacingMd),

            // 列表
            Expanded(
              child: filteredTasks.isEmpty
                  ? Center(
                      child: Text(
                        allTasks.isEmpty ? '暂时没有待办任务' : '未找到相关任务',
                        style: const TextStyle(
                          color: AmberColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredTasks.length,
                      itemBuilder: (context, index) {
                        final task = filteredTasks[index];
                        return ListTile(
                          title: Text(task.title),
                          subtitle: task.dueDate != null
                              ? Text('截止: ${_formatDate(task.dueDate!)}')
                              : null,
                          trailing: const Icon(
                            Icons.add_circle_outline,
                            color: AmberColors.primary,
                          ),
                          onTap: () => widget.onSelected(task),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AmberDimens.radiusSm,
                            ),
                          ),
                          hoverColor: AmberColors.primary.withOpacity(0.05),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }

  /// 清单筛选按钮
  Widget _buildListFilterButton(String label, bool showToday) {
    final isSelected = _showTodayOnly == showToday;
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _showTodayOnly = showToday;
        });
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? AmberColors.primary : Colors.transparent,
        foregroundColor: isSelected ? Colors.white : AmberColors.textPrimary,
        side: BorderSide(
          color: isSelected ? AmberColors.primary : AmberColors.divider,
        ),
      ),
      child: Text(label),
    );
  }
}
