import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/ui_utils.dart';
import '../providers/providers.dart';

/// ============================================================
/// 筛选排序按钮组件
/// ============================================================
/// 提供筛选和排序功能的按钮组合
/// 可在 TaskListView header 和移动端 AppBar 中复用
///
/// 设计哲学：
/// - 筛选按钮：点击弹出隐藏已完成/已过期选项
/// - 排序按钮：点击弹出排序方式选项
/// - 状态由 taskFilterSortProvider 统一管理

/// 筛选按钮（弹出菜单）
class FilterButton extends ConsumerWidget {
  /// 是否紧凑模式（适用于 AppBar）
  final bool compact;

  const FilterButton({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterSort = ref.watch(taskFilterSortProvider);
    final filterSortNotifier = ref.read(taskFilterSortProvider.notifier);

    return InstantPopupMenuButton<bool>(
      tooltip: '筛选',
      offset: const Offset(0, 40),
      icon: Icon(
        filterSort.hasActiveFilter
            ? Icons.filter_alt_rounded
            : Icons.filter_list_rounded,
        color: filterSort.hasActiveFilter ? AmberColors.primary : AmberColors.textSecondary,
        size: compact ? 22 : 24,
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: true,
          onTap: () {
            filterSortNotifier.toggleHideCompleted();
          },
          child: Row(
            children: [
              Icon(
                filterSort.hideCompleted
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 20,
                color: AmberColors.primary,
              ),
              const SizedBox(width: 8),
              const Text('隐藏已完成任务'),
            ],
          ),
        ),
        PopupMenuItem(
          value: false,
          onTap: () {
            filterSortNotifier.toggleHideOverdue();
          },
          child: Row(
            children: [
              Icon(
                filterSort.hideOverdue
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 20,
                color: AmberColors.primary,
              ),
              const SizedBox(width: 8),
              const Text('隐藏已过期任务'),
            ],
          ),
        ),
      ],
    );
  }
}

/// 排序按钮（弹出菜单）
class SortButton extends ConsumerWidget {
  /// 是否紧凑模式（适用于 AppBar）
  final bool compact;

  const SortButton({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterSort = ref.watch(taskFilterSortProvider);
    final filterSortNotifier = ref.read(taskFilterSortProvider.notifier);

    return InstantPopupMenuButton<SortOption>(
      tooltip: '排序',
      offset: const Offset(0, 40),
      initialValue: filterSort.sortOption,
      icon: Icon(
        Icons.sort_rounded,
        color: filterSort.hasCustomSort ? AmberColors.primary : AmberColors.textSecondary,
        size: compact ? 22 : 24,
      ),
      onSelected: (result) {
        filterSortNotifier.setSortOption(result);
      },
      itemBuilder: (context) => [
        for (var option in SortOption.values)
          PopupMenuItem(
            value: option,
            child: Row(
              children: [
                if (filterSort.sortOption == option)
                  const Icon(
                    Icons.check,
                    size: 18,
                    color: AmberColors.primary,
                  )
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Text(getSortOptionName(option)),
              ],
            ),
          ),
      ],
    );
  }
}

/// 筛选排序按钮组合（包含筛选和排序两个按钮）
class FilterSortButtons extends StatelessWidget {
  /// 是否紧凑模式（适用于 AppBar）
  final bool compact;

  const FilterSortButtons({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilterButton(compact: compact),
        SortButton(compact: compact),
      ],
    );
  }
}
