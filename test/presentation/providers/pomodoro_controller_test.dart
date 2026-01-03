import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:amber_list/presentation/providers/pomodoro_provider.dart';
import 'package:amber_list/core/services/pomodoro_timer.dart';
import 'package:amber_list/core/utils/sound_service.dart';
import 'package:amber_list/data/repositories/pomodoro_repository.dart';
import 'package:amber_list/data/models/models.dart';

// Mock dependencies
class MockPomodoroTimer extends Mock implements PomodoroTimer {}
class MockPomodoroRepository extends Mock implements PomodoroRepository {}
class MockSoundService extends Mock implements SoundService {}

void main() {
  setUpAll(() {
    registerFallbackValue(PomodoroSessionType.focus);
  });

  group('PomodoroController Tests', () {
    late MockPomodoroTimer mockTimer;
    late MockPomodoroRepository mockRepository;
    late MockSoundService mockSoundService;
    late PomodoroController controller;

    setUp(() {
      mockTimer = MockPomodoroTimer();
      mockRepository = MockPomodoroRepository();
      mockSoundService = MockSoundService();

      // Stub timer state
      when(() => mockTimer.state).thenReturn(PomodoroTimerState());
      
      // Stub addListener/removeListener since Controller adds itself
      when(() => mockTimer.addListener(any())).thenReturn(null);
      when(() => mockTimer.removeListener(any())).thenReturn(null);

      controller = PomodoroController(
        timer: mockTimer,
        repository: mockRepository,
        soundService: mockSoundService,
      );
    });

    // tearDown(() {
    //   controller.dispose();
    // });

    test('startPomodoro should start timer and play sound', () async {
      // Arrange
      const taskId = 'task-1';
      when(() => mockTimer.start(taskId: taskId)).thenReturn(null);
      when(() => mockSoundService.playPomodoroTick()).thenAnswer((_) async {});
      when(() => mockRepository.createSession(
            type: any(named: 'type'),
            taskId: any(named: 'taskId'),
          )).thenAnswer((_) async => 'session-1');

      // Act
      await controller.startPomodoro(taskId: taskId);

      // Assert
      verify(() => mockTimer.start(taskId: taskId)).called(1);
      verify(() => mockSoundService.playPomodoroTick()).called(1);
      verify(() => mockRepository.createSession(
        type: PomodoroSessionType.focus,
        taskId: taskId,
      )).called(1);
    });

    test('pause shoud pause timer and play tick sound', () {
      // Arrange
      when(() => mockTimer.pause()).thenReturn(null);
      when(() => mockSoundService.playPomodoroTick()).thenAnswer((_) async {});

      // Act
      controller.pause();

      // Assert
      verify(() => mockTimer.pause()).called(1);
      verify(() => mockSoundService.playPomodoroTick()).called(1);
    });

     test('resume shoud resume timer and play tick sound', () {
      // Arrange
      when(() => mockTimer.resume()).thenReturn(null);
      when(() => mockSoundService.playPomodoroTick()).thenAnswer((_) async {});

      // Act
      controller.resume();

      // Assert
      verify(() => mockTimer.resume()).called(1);
      verify(() => mockSoundService.playPomodoroTick()).called(1);
    });
  });
}
