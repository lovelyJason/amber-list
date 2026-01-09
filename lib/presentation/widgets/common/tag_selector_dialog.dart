import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/constants.dart';
import '../../../data/models/tag.dart';
import '../../providers/providers.dart';

/// 标签选择器弹窗
///
/// 统一的标签选择 UI 组件，用于任务详情面板、日历弹窗等场景
/// 特点：
/// - 带颜色的标签显示
/// - 选中/未选中状态明显区分
/// - 支持多选
///
/// 使用示例：
/// ```dart
/// final result = await TagSelectorDialog.show(
///   context: context,
///   ref: ref,
///   selectedTags: task.tags,
///   title: '管理任务标签',
/// );
/// if (result != null) {
///   // 用户点击了保存，result 是新的标签列表
/// }
/// ```
class TagSelectorDialog extends ConsumerStatefulWidget {
  /// 当前已选中的标签名称列表
  final List<String> selectedTags;

  /// 弹窗标题
  final String title;

  const TagSelectorDialog({
    super.key,
    required this.selectedTags,
    this.title = '管理任务标签',
  });

  /// 显示标签选择器弹窗
  ///
  /// 返回值：
  /// - List<String>：用户点击保存后返回新的标签列表
  /// - null：用户点击取消或关闭弹窗
  static Future<List<String>?> show({
    required BuildContext context,
    required WidgetRef ref,
    required List<String> selectedTags,
    String title = '管理任务标签',
  }) {
    return showDialog<List<String>>(
      context: context,
      builder: (context) => TagSelectorDialog(
        selectedTags: selectedTags,
        title: title,
      ),
    );
  }

  @override
  ConsumerState<TagSelectorDialog> createState() => _TagSelectorDialogState();
}

class _TagSelectorDialogState extends ConsumerState<TagSelectorDialog> {
  late List<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    // 复制一份，避免直接修改原列表
    _selectedTags = List.from(widget.selectedTags);
  }

  @override
  Widget build(BuildContext context) {
    final allTags = ref.watch(tagsProvider);

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 300,
        child: allTags.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    '暂无可用标签',
                    style: TextStyle(color: AmberColors.textSecondary),
                  ),
                ),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allTags.map((tag) => _buildTagChip(tag)).toList(),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedTags),
          child: const Text('保存'),
        ),
      ],
    );
  }

  /// 构建单个标签 Chip
  Widget _buildTagChip(Tag tag) {
    final isSelected = _selectedTags.contains(tag.name);
    final tagColor = tag.color;

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedTags.remove(tag.name);
          } else {
            _selectedTags.add(tag.name);
          }
        });
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          // 选中时显示浅色背景，未选中显示灰色背景
          color: isSelected
              ? tagColor.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            // 选中时显示同色边框，未选中无边框
            color: isSelected
                ? tagColor.withValues(alpha: 0.4)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          tag.name,
          style: TextStyle(
            fontSize: 13,
            // 选中时显示同色文字，未选中显示深灰文字
            color: isSelected ? tagColor : AmberColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
