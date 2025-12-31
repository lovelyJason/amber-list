import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/models.dart';

/// 计时器状态
enum TimerStatus {
  idle, // 空闲
  running, // 运行中
  paused, // 暂停
  completed, // 已完成
}

/// 番茄时钟状态
class PomodoroTimerState {
  final PomodoroSessionType currentType;
  final int remainingSeconds;
  final TimerStatus status;
  final String? currentTaskId;
  final int completedFocusSessions; // 连续完成的专注次数(用于判断长休息)

  PomodoroTimerState({
    this.currentType = PomodoroSessionType.focus,
    int? remainingSeconds,
    this.status = TimerStatus.idle,
    this.currentTaskId,
    this.completedFocusSessions = 0,
  }) : remainingSeconds = remainingSeconds ?? (currentType.defaultDuration);

  PomodoroTimerState copyWith({
    PomodoroSessionType? currentType,
    int? remainingSeconds,
    TimerStatus? status,
    String? currentTaskId,
    int? completedFocusSessions,
  }) {
    return PomodoroTimerState(
      currentType: currentType ?? this.currentType,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      status: status ?? this.status,
      currentTaskId: currentTaskId ?? this.currentTaskId,
      completedFocusSessions: completedFocusSessions ?? this.completedFocusSessions,
    );
  }

  /// 重置为默认时长
  PomodoroTimerState resetDuration() {
    return copyWith(
      remainingSeconds: currentType.defaultDuration,
      status: TimerStatus.idle,
    );
  }
}

/// 番茄时钟计时器引擎
class PomodoroTimer extends ChangeNotifier {
  PomodoroTimerState _state = PomodoroTimerState();
  Timer? _timer;
  DateTime? _startTime; // 记录开始时间,用于计算实际时长

  PomodoroTimerState get state => _state;

  // ===== 核心控制方法 =====

  /// 开始计时
  void start({String? taskId}) {
    if (_state.status == TimerStatus.running) return;

    _state = _state.copyWith(
      status: TimerStatus.running,
      currentTaskId: taskId,
    );

    _startTime = DateTime.now();
    _startTicker();
    notifyListeners();
  }

  /// 暂停计时
  void pause() {
    if (_state.status != TimerStatus.running) return;

    _state = _state.copyWith(status: TimerStatus.paused);
    _stopTicker();
    notifyListeners();
  }

  /// 恢复计时
  void resume() {
    if (_state.status != TimerStatus.paused) return;

    _state = _state.copyWith(status: TimerStatus.running);
    _startTicker();
    notifyListeners();
  }

  /// 重置当前会话
  void reset() {
    _stopTicker();
    _startTime = null;
    _state = _state.resetDuration();
    notifyListeners();
  }

  /// 切换会话类型
  void switchType(PomodoroSessionType type) {
    _stopTicker();
    _startTime = null;
    _state = PomodoroTimerState(
      currentType: type,
      remainingSeconds: type.defaultDuration,
      status: TimerStatus.idle,
      currentTaskId: _state.currentTaskId,
      completedFocusSessions: _state.completedFocusSessions,
    );
    notifyListeners();
  }

  /// 切换任务
  void switchTask(String? taskId) {
    _state = _state.copyWith(currentTaskId: taskId);
    notifyListeners();
  }

  /// 完成当前会话
  void complete() {
    _stopTicker();

    // 如果是专注会话,增加完成计数
    int newCompletedCount = _state.completedFocusSessions;
    if (_state.currentType == PomodoroSessionType.focus) {
      newCompletedCount++;
    }

    _state = _state.copyWith(
      status: TimerStatus.completed,
      remainingSeconds: 0,
      completedFocusSessions: newCompletedCount,
    );

    notifyListeners();
  }

  /// 获取实际已用时长(秒)
  int getElapsedSeconds() {
    if (_startTime == null) return 0;
    return _state.currentType.defaultDuration - _state.remainingSeconds;
  }

  /// 判断是否应该触发长休息
  bool shouldTriggerLongBreak() {
    return _state.completedFocusSessions >= 4;
  }

  /// 重置连续完成计数(长休息后调用)
  void resetCompletedCount() {
    _state = _state.copyWith(completedFocusSessions: 0);
    notifyListeners();
  }

  // ===== 内部计时逻辑 =====

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state.remainingSeconds > 0) {
        _state = _state.copyWith(
          remainingSeconds: _state.remainingSeconds - 1,
        );
        notifyListeners();
      } else {
        // 倒计时结束,自动标记完成
        complete();
      }
    });
  }

  void _stopTicker() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }
}
