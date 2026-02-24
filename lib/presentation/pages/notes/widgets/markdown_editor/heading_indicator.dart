import 'package:flutter/material.dart';

import '../../../../../core/constants/constants.dart';
import 'markdown_editor_controller.dart';

/// 标题层级指示器
///
/// 设计哲学:
/// - 当光标在标题行时，在行首左侧显示 H1/H2/H3 等层级标识
/// - 使用蓝色高亮，视觉突出
/// - 点击可快速切换标题级别
class HeadingIndicator extends StatelessWidget {
  final LineInfo lineInfo;
  final MarkdownEditorController controller;

  const HeadingIndicator({
    super.key,
    required this.lineInfo,
    required this.controller,
  });

  /// 下标数字映射（Unicode 下标字符）
  static const _subscriptDigits = ['₀', '₁', '₂', '₃', '₄', '₅', '₆', '₇', '₈', '₉'];

  @override
  Widget build(BuildContext context) {
    if (lineInfo.headingLevel == 0) {
      return const SizedBox.shrink();
    }

    // 使用下标格式：H₁, H₂, H₃ 等
    final subscript = _subscriptDigits[lineInfo.headingLevel];


    return GestureDetector(
      onTap: () => _showHeadingMenu(context),
      child: Container(
        height: 14, // 与光标高度一致
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 2, right: 4),
        child: Text(
          'H$subscript',
          style: const TextStyle(
            fontSize: 10, // 更小的字号，更精致
            fontWeight: FontWeight.w700,
            color: AmberColors.primary,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  /// 显示标题级别切换菜单
  void _showHeadingMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero);

    showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + 30,
        offset.dx + 150,
        offset.dy + 250,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      items: [
        _buildMenuItem(1, 'H₁', '一级标题'),
        _buildMenuItem(2, 'H₂', '二级标题'),
        _buildMenuItem(3, 'H₃', '三级标题'),
        _buildMenuItem(4, 'H₄', '四级标题'),
        _buildMenuItem(5, 'H₅', '五级标题'),
        _buildMenuItem(6, 'H₆', '六级标题'),
        const PopupMenuDivider(),
        _buildMenuItem(0, '¶', '取消标题'),
      ],
    ).then((level) {
      if (level == null) return;
      _changeHeadingLevel(level);
    });
  }

  /// 构建菜单项
  PopupMenuItem<int> _buildMenuItem(int level, String prefix, String title) {
    final isSelected = level == lineInfo.headingLevel;

    return PopupMenuItem<int>(
      value: level,
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              prefix,
              style: TextStyle(
                fontSize: level == 0 ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AmberColors.primary
                    : AmberColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: isSelected
                    ? AmberColors.primary
                    : AmberColors.textPrimary,
              ),
            ),
          ),
          if (isSelected)
            Icon(
              Icons.check,
              size: 16,
              color: AmberColors.primary,
            ),
        ],
      ),
    );
  }

  /// 改变标题级别
  void _changeHeadingLevel(int newLevel) {
    final lineStart = lineInfo.lineStart;
    final lineText = lineInfo.lineText;
    final currentLevel = lineInfo.headingLevel;

    // 移除当前标题前缀
    String newLineText = lineText;
    if (currentLevel > 0) {
      // 移除 "### " 格式
      final prefixLength = currentLevel + 1; // # 数量 + 空格
      if (lineText.length >= prefixLength) {
        newLineText = lineText.substring(prefixLength);
      }
    }

    // 添加新的标题前缀
    if (newLevel > 0) {
      newLineText = '${'#' * newLevel} $newLineText';
    }

    // 更新文本
    controller.value = controller.value.copyWith(
      text: controller.text.replaceRange(
        lineStart,
        lineInfo.lineEnd,
        newLineText,
      ),
    );
  }
}
