import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/pomodoro_timer.dart';
import '../../core/utils/sound_service.dart';
import '../../data/models/models.dart';
import '../../data/repositories/pomodoro_repository.dart';
import 'database_provider.dart';

// ===== Repository Provider =====

final pomodoroRepositoryProvider = Provider<PomodoroRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return PomodoroRepository(db);
});

// ===== Timer Provider =====

final pomodoroTimerProvider = ChangeNotifierProvider<PomodoroTimer>((ref) {
  return PomodoroTimer();
});

// ===== Pomodoro Controller Provider =====

/// 番茄时钟控制器 - 协调Timer、Repository、Sound等
class PomodoroController extends StateNotifier<AsyncValue<void>> {
  final PomodoroTimer _timer;
  final PomodoroRepository _repository;
  final SoundService _soundService;

  String? _currentSessionId; // 当前会话ID

  PomodoroController({
    required PomodoroTimer timer,
    required PomodoroRepository repository,
    required SoundService soundService,
  })  : _timer = timer,
        _repository = repository,
        _soundService = soundService,
        super(const AsyncValue.data(null)) {
    // 监听计时器完成事件
    _timer.addListener(_onTimerStateChanged);
  }

  /// 监听计时器状态变化
  void _onTimerStateChanged() {
    if (_timer.state.status == TimerStatus.completed) {
      _handleSessionCompleted();
    }
  }

  /// 开始番茄钟
  Future<void> startPomodoro({String? taskId}) async {
    if (!mounted) return;
    try {
      state = const AsyncValue.loading();

      // 创建会话记录
      _currentSessionId = await _repository.createSession(
        type: _timer.state.currentType,
        taskId: taskId,
      );

      // 启动计时器
      _timer.start(taskId: taskId);
      _soundService.playPomodoroTick();

      if (mounted) {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// 暂停
  void pause() {
    _timer.pause();
    _soundService.playPomodoroTick();
  }

  /// 恢复
  void resume() {
    _timer.resume();
    _soundService.playPomodoroTick();
  }

  /// 重置
  void reset() {
    _currentSessionId = null;
    _timer.reset();
  }

  /// 切换会话类型
  void switchType(PomodoroSessionType type) {
    _currentSessionId = null;
    _timer.switchType(type);
  }

  /// 切换任务
  void switchTask(String? taskId) {
    _timer.switchTask(taskId);
  }

  /// 处理计时器完成(UI回调用)
  Future<void> handleTimerComplete() async {
    await _handleSessionCompleted();
  }

  /// 从队列移除任务
  Future<void> removeFromQueue(String queueItemId) async {
    try {
      await _repository.deleteQueueItem(queueItemId);
    } catch (e) {
      debugPrint('[PomodoroController] Error removing from queue: $e');
    }
  }

  /// 添加任务到队列
  Future<void> addToQueue(String taskId, {int estimatedPomodoros = 1}) async {
    try {
      await _repository.addToQueue(
        taskId: taskId,
        estimatedPomodoros: estimatedPomodoros,
      );
    } catch (e) {
      debugPrint('[PomodoroController] Error adding to queue: $e');
    }
  }

  /// 处理会话完成
  Future<void> _handleSessionCompleted() async {
    try {
      // 1. 保存会话数据
      if (_currentSessionId != null) {
        final actualDuration = _timer.getElapsedSeconds();
        await _repository.completeSession(_currentSessionId!, actualDuration);
      }

      // 2. 如果是专注会话,增加队列项完成数
      if (_timer.state.currentType == PomodoroSessionType.focus &&
          _timer.state.currentTaskId != null) {
        await _incrementQueueItemCompleted(_timer.state.currentTaskId!);
      }

      // 3. 播放完成音效
      // 3. 播放完成音效
      await _soundService.playPomodoroEnd();

      // 4. 显示系统通知
      // TODO: 显示系统通知 "番茄钟已完成,休息一下吧!"

      // 5. 自动切换到下一个会话类型
      _autoSwitchNextType();
    } catch (e) {
      debugPrint('[PomodoroController] Error handling completion: $e');
    }
  }

  /// 增加队列项完成数
  Future<void> _incrementQueueItemCompleted(String taskId) async {
    try {
      // 查找队列中对应的任务
      final queue = await _repository.watchQueue().first;
      final queueItem = queue.cast<PomodoroQueueItemModel?>().firstWhere(
            (item) => item?.taskId == taskId,
            orElse: () => null,
          );

      if (queueItem != null) {
        await _repository.incrementQueueItemCompleted(queueItem.id);
      }
    } catch (e) {
      debugPrint('[PomodoroController] Error incrementing queue item: $e');
    }
  }

  /// 自动切换到下一个会话类型
  void _autoSwitchNextType() {
    final currentType = _timer.state.currentType;

    if (currentType == PomodoroSessionType.focus) {
      // 专注完成 -> 判断长休息还是短休息
      if (_timer.shouldTriggerLongBreak()) {
        switchType(PomodoroSessionType.longBreak);
        _timer.resetCompletedCount(); // 重置计数
      } else {
        switchType(PomodoroSessionType.shortBreak);
      }
    } else {
      // 休息完成 -> 回到专注
      switchType(PomodoroSessionType.focus);
    }
  }

  @override
  void dispose() {
    _timer.removeListener(_onTimerStateChanged);
    super.dispose();
  }
}

final pomodoroControllerProvider =
    StateNotifierProvider<PomodoroController, AsyncValue<void>>((ref) {
  final timer = ref.watch(pomodoroTimerProvider);
  final repository = ref.watch(pomodoroRepositoryProvider);
  final soundService = ref.watch(soundServiceProvider);

  return PomodoroController(
    timer: timer,
    repository: repository,
    soundService: soundService,
  );
});

// ===== Queue Providers =====

/// 监听番茄时钟队列
final pomodoroQueueProvider =
    StreamProvider<List<PomodoroQueueItemModel>>((ref) {
  final repository = ref.watch(pomodoroRepositoryProvider);
  return repository.watchQueue();
});

/// 监听今日番茄钟会话历史
final todayPomodoroSessionsProvider =
    StreamProvider<List<PomodoroSessionModel>>((ref) {
  final repository = ref.watch(pomodoroRepositoryProvider);
  return repository.watchTodaySessions();
});

// ===== Queue Operations =====

/// 添加任务到队列
Future<void> addTaskToQueue(
  WidgetRef ref, {
  required String taskId,
  int estimatedPomodoros = 1,
}) async {
  final repository = ref.read(pomodoroRepositoryProvider);
  await repository.addToQueue(
    taskId: taskId,
    estimatedPomodoros: estimatedPomodoros,
  );
}

/// 从队列移除任务
Future<void> removeTaskFromQueue(WidgetRef ref, String queueItemId) async {
  final repository = ref.read(pomodoroRepositoryProvider);
  await repository.removeFromQueue(queueItemId);
}

/// 重排队列
Future<void> reorderQueue(WidgetRef ref, List<String> orderedIds) async {
  final repository = ref.read(pomodoroRepositoryProvider);
  await repository.reorderQueue(orderedIds);
}

/// 清空队列
Future<void> clearQueue(WidgetRef ref) async {
  final repository = ref.read(pomodoroRepositoryProvider);
  await repository.clearQueue();
}
