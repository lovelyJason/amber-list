import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 导航视图类型
enum NavView {
  inbox,    // 收集箱
  today,    // 今天
  upcoming, // 最近7天
  all, // 全部
  calendar, // 日历
  notes,    // 笔记
  pomodoro, // 番茄时钟
  list,     // 自定义清单
  completed, // 已完成
  trash, // 垃圾桶
}

/// 应用导航状态
class AppNavState {
  final NavView currentView;
  final String? selectedListId;  // 当前选中的清单ID
  final String? selectedTaskId;  // 当前选中的任务ID
  final bool isDetailPanelOpen;  // 详情面板是否打开
  final bool isListSidebarOpen; // 清单侧边栏是否打开

  const AppNavState({
    this.currentView = NavView.today,
    this.selectedListId,
    this.selectedTaskId,
    this.isDetailPanelOpen = false,
    this.isListSidebarOpen = true,
  });

  AppNavState copyWith({
    NavView? currentView,
    String? selectedListId,
    String? selectedTaskId,
    bool? isDetailPanelOpen,
    bool? isListSidebarOpen,
  }) {
    return AppNavState(
      currentView: currentView ?? this.currentView,
      selectedListId: selectedListId ?? this.selectedListId,
      selectedTaskId: selectedTaskId ?? this.selectedTaskId,
      isDetailPanelOpen: isDetailPanelOpen ?? this.isDetailPanelOpen,
      isListSidebarOpen: isListSidebarOpen ?? this.isListSidebarOpen,
    );
  }
}

/// 应用导航状态Notifier
class AppNavNotifier extends StateNotifier<AppNavState> {
  AppNavNotifier() : super(const AppNavState());

  /// 切换视图
  void setView(NavView view, {String? listId}) {
    state = state.copyWith(
      currentView: view,
      selectedListId: listId,
      selectedTaskId: null,
      isDetailPanelOpen: false,
    );
  }

  /// 选择任务
  void selectTask(String? taskId) {
    state = state.copyWith(
      selectedTaskId: taskId,
      isDetailPanelOpen: taskId != null,
    );
  }

  /// 切换详情面板
  void toggleDetailPanel() {
    state = state.copyWith(
      isDetailPanelOpen: !state.isDetailPanelOpen,
    );
  }

  /// 关闭详情面板
  void closeDetailPanel() {
    state = state.copyWith(
      selectedTaskId: null,
      isDetailPanelOpen: false,
    );
  }

  /// 切换清单侧边栏
  void toggleListSidebar() {
    state = state.copyWith(isListSidebarOpen: !state.isListSidebarOpen);
  }
}

/// 应用导航状态Provider
final appNavProvider = StateNotifierProvider<AppNavNotifier, AppNavState>((ref) {
  return AppNavNotifier();
});
