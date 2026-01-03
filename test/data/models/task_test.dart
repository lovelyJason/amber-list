import 'package:flutter_test/flutter_test.dart';
import 'package:amber_list/data/models/task.dart';

void main() {
  group('Task Model Tests', () {
    test('Should create a task with default values', () {
      final task = Task(
        id: '1',
        title: 'Test Task',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(task.priority, TaskPriority.none);
      expect(task.isCompleted, false);
      expect(task.isDeleted, false);
      expect(task.tags, isEmpty);
    });

    test('Should toggle completion status correctly', () {
      final initialTask = Task(
        id: '1',
        title: 'Test Task',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isCompleted: false,
      );

      // Act: Toggle to complete
      final completedTask = initialTask.toggleComplete();

      // Assert
      expect(completedTask.isCompleted, true);
      expect(completedTask.completedAt, isNotNull);
      expect(completedTask.updatedAt.isAfter(initialTask.updatedAt), true);

      // Act: Toggle back to incomplete
      final incompleteTask = completedTask.toggleComplete();

      // Assert
      expect(incompleteTask.isCompleted, false);
      expect(incompleteTask.completedAt, isNull);
    });

    test('Should copy with new values', () {
      final task = Task(
        id: '1',
        title: 'Original Title',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        priority: TaskPriority.low,
      );

      final updatedTask = task.copyWith(
        title: 'New Title',
        priority: TaskPriority.high,
      );

      expect(updatedTask.id, task.id);
      expect(updatedTask.title, 'New Title');
      expect(updatedTask.priority, TaskPriority.high);
      expect(updatedTask.createdAt, task.createdAt);
    });
  });
}
