import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:amber_list/core/services/pomodoro_timer.dart';
import 'package:amber_list/data/models/models.dart';

void main() {
  group('PomodoroTimer Service Tests', () {
    late PomodoroTimer timer;

    setUp(() {
      timer = PomodoroTimer();
    });

    tearDown(() {
      timer.dispose();
    });

    test('Initial state should be idle and focus type', () {
      expect(timer.state.status, TimerStatus.idle);
      expect(timer.state.currentType, PomodoroSessionType.focus);
    });

    test('Start should change status to running', () {
      timer.start(taskId: '123');
      expect(timer.state.status, TimerStatus.running);
      expect(timer.state.currentTaskId, '123');
    });

    test('Pause and Resume should work correctly', () {
      timer.start();
      expect(timer.state.status, TimerStatus.running);

      timer.pause();
      expect(timer.state.status, TimerStatus.paused);

      timer.resume();
      expect(timer.state.status, TimerStatus.running);
    });

    test('Timer should countdown and complete', () {
      fakeAsync((async) {
        timer.start();
        final initialSeconds = timer.state.remainingSeconds;

        // Advance 1 second
        async.elapse(const Duration(seconds: 1));
        expect(timer.state.remainingSeconds, initialSeconds - 1);

        // Advance to completion
        async.elapse(Duration(seconds: initialSeconds));
        
        expect(timer.state.status, TimerStatus.completed);
        expect(timer.state.remainingSeconds, 0);
        expect(timer.state.completedFocusSessions, 1);
      });
    });

    test('Should trigger long break after 4 focus sessions', () {
      // Simulate 4 completions
      // Since 'complete' increments counter and we can't easily set state directly (immutable),
      // we might need to rely on calling complete() multiple times manually or mocking/subclassing if we really wanted isolated state.
      // But PomodoroTimer exposes no setter.
      // However, we can just call 'complete()' manually which is public.

      timer.complete(); // 1
      expect(timer.shouldTriggerLongBreak(), false);

      timer.complete(); // 2
      expect(timer.shouldTriggerLongBreak(), false);

      timer.complete(); // 3
      expect(timer.shouldTriggerLongBreak(), false);

      timer.complete(); // 4
      expect(timer.shouldTriggerLongBreak(), true);
    });
    
    test('Switch type should reset timer', () {
      timer.start();
      timer.switchType(PomodoroSessionType.shortBreak);
      
      expect(timer.state.currentType, PomodoroSessionType.shortBreak);
      expect(timer.state.status, TimerStatus.idle);
      expect(timer.state.remainingSeconds, PomodoroSessionType.shortBreak.defaultDuration);
    });
  });
}
