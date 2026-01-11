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
  completedAt, // 按完成时间（已完成页面专用）
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
      // 优先级、创建时间、完成时间默认降序（高优先级/最新的在前）
      final defaultAscending = !(option == SortOption.priority ||
          option == SortOption.created ||
          option == SortOption.completedAt);
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
    case SortOption.completedAt:
      return '按完成时间';
  }
}

// ============================================================
// 已完成页面专用筛选排序 Provider
// ============================================================

/// 已完成页面筛选模式
enum CompletedFilterMode {
  all, // 全部
  today, // 今天完成的
  specificDate, // 指定日期完成的
}

/// 已完成页面筛选排序状态
@immutable
class CompletedFilterSortState {
  /// 筛选模式
  final CompletedFilterMode filterMode;

  /// 指定日期（仅当 filterMode == specificDate 时有效）
  final DateTime? specificDate;

  /// 当前排序方式（已完成页面默认按完成时间排序）
  final SortOption sortOption;

  /// 是否升序排列
  final bool sortAscending;

  const CompletedFilterSortState({
    this.filterMode = CompletedFilterMode.all,
    this.specificDate,
    this.sortOption = SortOption.completedAt,
    this.sortAscending = false, // 默认降序，最近完成的在前
  });

  /// 是否有筛选生效
  bool get hasActiveFilter => filterMode != CompletedFilterMode.all;

  /// 是否有非默认排序
  bool get hasCustomSort => sortOption != SortOption.completedAt;

  CompletedFilterSortState copyWith({
    CompletedFilterMode? filterMode,
    DateTime? specificDate,
    SortOption? sortOption,
    bool? sortAscending,
  }) {
    return CompletedFilterSortState(
      filterMode: filterMode ?? this.filterMode,
      specificDate: specificDate ?? this.specificDate,
      sortOption: sortOption ?? this.sortOption,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }
}

/// 已完成页面筛选排序 Provider
final completedFilterSortProvider =
    StateNotifierProvider<CompletedFilterSortNotifier, CompletedFilterSortState>(
        (ref) {
  return CompletedFilterSortNotifier();
});

/// 已完成页面筛选排序 Notifier
class CompletedFilterSortNotifier extends StateNotifier<CompletedFilterSortState> {
  CompletedFilterSortNotifier() : super(const CompletedFilterSortState());

  /// 设置筛选模式为全部
  void setFilterAll() {
    state = state.copyWith(filterMode: CompletedFilterMode.all);
  }

  /// 设置筛选模式为今天
  void setFilterToday() {
    state = state.copyWith(filterMode: CompletedFilterMode.today);
  }

  /// 设置筛选模式为指定日期
  void setFilterSpecificDate(DateTime date) {
    state = CompletedFilterSortState(
      filterMode: CompletedFilterMode.specificDate,
      specificDate: date,
      sortOption: state.sortOption,
      sortAscending: state.sortAscending,
    );
  }

  /// 设置排序方式
  void setSortOption(SortOption option) {
    if (state.sortOption == option) {
      // 再次点击同一排序，切换升降序
      state = state.copyWith(sortAscending: !state.sortAscending);
    } else {
      // 切换排序方式，完成时间默认降序，其他默认升序
      final defaultAscending = option != SortOption.completedAt &&
          option != SortOption.created &&
          option != SortOption.priority;
      state = state.copyWith(
        sortOption: option,
        sortAscending: defaultAscending,
      );
    }
  }

  /// 重置为默认状态
  void reset() {
    state = const CompletedFilterSortState();
  }
}
