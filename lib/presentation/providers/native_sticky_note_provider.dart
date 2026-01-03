import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/native_sticky_note_service.dart';
import '../../core/utils/sound_service.dart';
import 'task_provider.dart';

/// 原生便签服务 Provider
/// 负责初始化原生便签服务并设置回调
///
/// 使用方式：在应用启动时 watch 此 provider 以触发初始化
final nativeStickyNoteProvider = Provider<NativeStickyNoteService>((ref) {
  final service = NativeStickyNoteService.instance;

  // 设置任务状态变化回调
  // 当原生便签窗口中任务被勾选/取消勾选时，同步到 Flutter 端
  service.onTaskToggled = (taskId, isCompleted) {
    debugPrint('[NativeStickyNoteProvider] 收到任务状态变化: $taskId -> $isCompleted');

    // 更新 Flutter 端的任务状态
    try {
      // 获取当前任务状态
      final tasks = ref.read(taskProvider);
      final taskIndex = tasks.indexWhere((t) => t.id == taskId);

      if (taskIndex == -1) {
        debugPrint('[NativeStickyNoteProvider] 任务不存在: $taskId');
        return;
      }

      final task = tasks[taskIndex];

      // 只有状态真的变化时才更新
      if (task.isCompleted != isCompleted) {
        // 播放音效（和主窗口保持一致）
        if (isCompleted) {
          ref.read(soundServiceProvider).playCompletion();
        } else {
          ref.read(soundServiceProvider).playAdd();
        }

        // 调用 provider 的 toggleTaskComplete 方法
        // 注意：这会触发数据库更新和状态更新
        ref.read(taskProvider.notifier).toggleTaskComplete(taskId);
        debugPrint('[NativeStickyNoteProvider] 任务状态已同步: $taskId -> $isCompleted');
      }
    } catch (e) {
      debugPrint('[NativeStickyNoteProvider] 同步任务状态失败: $e');
    }
  };

  // 设置窗口关闭回调
  service.onStickyNoteClosed = (noteId) {
    debugPrint('[NativeStickyNoteProvider] 便签窗口已关闭: $noteId');
    // 这里可以做一些清理工作，比如更新 UI 状态
  };

  return service;
});

/// 用于更新打开的便签窗口内容的辅助 Provider
/// 当 Flutter 主窗口中任务状态变化时，同步到原生便签窗口
class StickyNoteUpdater {
  final NativeStickyNoteService _service;
  final Ref _ref;

  StickyNoteUpdater(this._service, this._ref);

  /// 更新指定列表的便签窗口
  Future<void> updateStickyNote(String listId) async {
    if (!_service.openNotes.contains(listId)) {
      return; // 便签未打开，无需更新
    }

    try {
      final tasks = _ref.read(taskProvider);
      final listTasks = tasks
          .where((t) => t.listId == listId && !t.isDeleted)
          .toList();

      final activeTasks = listTasks
          .where((t) => !t.isCompleted)
          .map((t) => {'id': t.id, 'title': t.title, 'isCompleted': false})
          .toList();

      final completedTasks = listTasks
          .where((t) => t.isCompleted)
          .map((t) => {'id': t.id, 'title': t.title, 'isCompleted': true})
          .toList();

      await _service.updateStickyNote(
        id: listId,
        activeTasks: activeTasks,
        completedTasks: completedTasks,
      );
    } catch (e) {
      debugPrint('[StickyNoteUpdater] 更新便签失败: $e');
    }
  }
}

/// StickyNoteUpdater Provider
final stickyNoteUpdaterProvider = Provider<StickyNoteUpdater>((ref) {
  final service = ref.watch(nativeStickyNoteProvider);
  return StickyNoteUpdater(service, ref);
});
