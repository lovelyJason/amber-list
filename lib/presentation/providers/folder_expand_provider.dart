import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'task_provider.dart';

/// 文件夹展开状态管理
///
/// 使用 Provider 管理侧边栏文件夹的展开/收起状态
/// 这样状态不会因为 Widget rebuild 而丢失（解决拖拽后自动展开失效的问题）
///
/// 状态数据：`Set<String>`，存储已展开文件夹的 ID 集合
class FolderExpandNotifier extends StateNotifier<Set<String>> {
  final Ref _ref;

  FolderExpandNotifier(this._ref) : super({});

  /// 展开指定文件夹
  void expand(String folderId) {
    if (!state.contains(folderId)) {
      state = {...state, folderId};
    }
  }

  /// 收起指定文件夹
  void collapse(String folderId) {
    if (state.contains(folderId)) {
      state = state.where((id) => id != folderId).toSet();
    }
  }

  /// 切换展开/收起状态
  void toggle(String folderId) {
    if (state.contains(folderId)) {
      collapse(folderId);
    } else {
      expand(folderId);
    }
  }

  /// 检查文件夹是否展开
  bool isExpanded(String folderId) {
    return state.contains(folderId);
  }

  /// 展开指定文件夹及其所有祖先
  /// 用于拖拽清单到深层文件夹时，确保路径上所有文件夹都展开
  void expandWithAncestors(String folderId) {
    final allLists = _ref.read(taskListProvider);
    final idsToExpand = <String>{};
    String? currentId = folderId;

    // 从目标文件夹向上收集所有祖先 ID
    while (currentId != null) {
      final folder = allLists.where((l) => l.id == currentId).firstOrNull;
      if (folder == null || !folder.isFolder) break;

      idsToExpand.add(currentId);
      currentId = folder.parentId;
    }

    // 合并到状态中
    if (idsToExpand.isNotEmpty) {
      state = {...state, ...idsToExpand};
    }
  }
}

/// 文件夹展开状态 Provider
final folderExpandProvider =
    StateNotifierProvider<FolderExpandNotifier, Set<String>>(
  (ref) => FolderExpandNotifier(ref),
);

/// 快捷方法：检查单个文件夹是否展开
/// 使用示例：ref.watch(isFolderExpandedProvider(folderId))
final isFolderExpandedProvider = Provider.family<bool, String>(
  (ref, folderId) => ref.watch(folderExpandProvider).contains(folderId),
);
