import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ============================================================
/// 任务筛选排序 Provider
/// ============================================================
/// 管理任务列表的筛选和排序状态
/// 状态提升到 Provider 层，便于 AppBar 和 TaskListView 共享状态

/// 排序选项枚举
enum SortOption {
  smart, // 智能排序 (默认)
  dueDate, // 按截止日期
  priority, // 按优先级
  title, // 按标题
  created, // 按创建时间
}

/// 筛选排序状态数据类
@immutable
class TaskFilterSortState {
  /// 当前排序方式
  final SortOption sortOption;

  /// 是否升序排列
  final bool sortAscending;

  /// 是否隐藏已完成任务
  final bool hideCompleted;

  /// 是否隐藏已过期任务
  final bool hideOverdue;

  const TaskFilterSortState({
    this.sortOption = SortOption.smart,
    this.sortAscending = true,
    this.hideCompleted = false,
    this.hideOverdue = false,
  });

  /// 是否有筛选生效
  bool get hasActiveFilter => hideCompleted || hideOverdue;

  /// 是否有非默认排序
  bool get hasCustomSort => sortOption != SortOption.smart;

  TaskFilterSortState copyWith({
    SortOption? sortOption,
    bool? sortAscending,
    bool? hideCompleted,
    bool? hideOverdue,
  }) {
    return TaskFilterSortState(
      sortOption: sortOption ?? this.sortOption,
      sortAscending: sortAscending ?? this.sortAscending,
      hideCompleted: hideCompleted ?? this.hideCompleted,
      hideOverdue: hideOverdue ?? this.hideOverdue,
    );
  }
}

/// 任务筛选排序 Provider
final taskFilterSortProvider =
    StateNotifierProvider<TaskFilterSortNotifier, TaskFilterSortState>((ref) {
  return TaskFilterSortNotifier();
});

/// 任务筛选排序 Notifier
class TaskFilterSortNotifier extends StateNotifier<TaskFilterSortState> {
  TaskFilterSortNotifier() : super(const TaskFilterSortState());

  /// 切换隐藏已完成任务
  void toggleHideCompleted() {
    state = state.copyWith(hideCompleted: !state.hideCompleted);
  }

  /// 切换隐藏已过期任务
  void toggleHideOverdue() {
    state = state.copyWith(hideOverdue: !state.hideOverdue);
  }

  /// 设置排序方式
  void setSortOption(SortOption option) {
    if (state.sortOption == option && option != SortOption.smart) {
      // 再次点击同一排序，切换升降序
      state = state.copyWith(sortAscending: !state.sortAscending);
    } else {
      // 切换排序方式，根据类型设置默认升降序
      final defaultAscending = !(option == SortOption.priority || option == SortOption.created);
      state = state.copyWith(
        sortOption: option,
        sortAscending: defaultAscending,
      );
    }
  }

  /// 重置为默认状态
  void reset() {
    state = const TaskFilterSortState();
  }
}

/// 获取排序选项的中文名称
String getSortOptionName(SortOption option) {
  switch (option) {
    case SortOption.smart:
      return '智能排序';
    case SortOption.dueDate:
      return '按截止日期';
    case SortOption.priority:
      return '按优先级';
    case SortOption.title:
      return '按标题';
    case SortOption.created:
      return '按创建时间';
  }
}
