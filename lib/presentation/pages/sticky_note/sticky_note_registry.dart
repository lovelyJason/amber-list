import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 便签窗口注册表
/// 用于跟踪已打开的便签窗口，防止重复打开
///
/// 映射关系: Content ID (清单ID 或 任务ID) -> Window ID
/// 注: desktop_multi_window 0.3.0 版本使用 String UUID 作为窗口 ID
class StickyNoteRegistry extends StateNotifier<Map<String, String>> {
  StickyNoteRegistry() : super({});

  /// 注册一个便签窗口
  /// [contentId] 清单或任务的 ID
  /// [windowId] desktop_multi_window 分配的窗口 UUID
  void register(String contentId, String windowId) {
    state = {...state, contentId: windowId};
  }

  /// 通过内容 ID 注销窗口
  void unregister(String contentId) {
    if (state.containsKey(contentId)) {
      final newState = Map<String, String>.from(state);
      newState.remove(contentId);
      state = newState;
    }
  }

  /// 通过窗口 ID 注销窗口
  /// 用于窗口关闭回调时清理注册表
  void unregisterByWindowId(String windowId) {
    final entry = state.entries.firstWhere(
      (e) => e.value == windowId,
      orElse: () => const MapEntry('', ''),
    );
    if (entry.value.isNotEmpty) {
      unregister(entry.key);
    }
  }

  /// 检查指定内容的便签是否已打开
  bool isOpen(String contentId) {
    return state.containsKey(contentId);
  }

  /// 获取指定内容对应的窗口 ID
  String? getWindowId(String contentId) {
    return state[contentId];
  }
}

final stickyNoteRegistryProvider =
    StateNotifierProvider<StickyNoteRegistry, Map<String, String>>((ref) {
  return StickyNoteRegistry();
});