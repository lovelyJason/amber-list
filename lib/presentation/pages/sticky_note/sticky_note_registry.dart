import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Registry to track active sticky note windows to prevent duplicates.
/// Maps Content ID (List ID or Task ID) to Window ID.
class StickyNoteRegistry extends StateNotifier<Map<String, int>> {
  StickyNoteRegistry() : super({});

  void register(String contentId, int windowId) {
    state = {...state, contentId: windowId};
  }

  void unregister(String contentId) {
    if (state.containsKey(contentId)) {
      final newState = Map<String, int>.from(state);
      newState.remove(contentId);
      state = newState;
    }
  }
  
  void unregisterByWindowId(int windowId) {
    final entry = state.entries.firstWhere((e) => e.value == windowId, orElse: () => const MapEntry('', -1));
    if (entry.value != -1) {
       unregister(entry.key);
    }
  }

  bool isOpen(String contentId) {
    return state.containsKey(contentId);
  }
  
  int? getWindowId(String contentId) {
    return state[contentId];
  }
}

final stickyNoteRegistryProvider = StateNotifierProvider<StickyNoteRegistry, Map<String, int>>((ref) {
  return StickyNoteRegistry();
});
