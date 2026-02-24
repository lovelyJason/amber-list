import 'package:flutter/material.dart';

import '../../../../../core/constants/constants.dart';
import 'markdown_editor_controller.dart';

/// 复选框指示器
///
/// 设计哲学:
/// - 当光标在复选框行时，在左侧显示可点击的勾选框图标
/// - 点击图标切换勾选状态（修改底层 `- [ ]` 为 `- [x]` 或反之）
/// - 与 HeadingIndicator、LinePlusMenu 共用左侧指示器区域
class CheckboxIndicator extends StatelessWidget {
  final LineInfo lineInfo;
  final MarkdownEditorController controller;

  const CheckboxIndicator({
    super.key,
    required this.lineInfo,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (!lineInfo.isCheckbox) {
      return const SizedBox.shrink();
    }

    final isChecked = _isChecked();

    return GestureDetector(
      onTap: () => _toggleCheckbox(),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          child: Icon(
            isChecked ? Icons.check_box : Icons.check_box_outline_blank,
            size: 18,
            color: isChecked ? AmberColors.success : AmberColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// 判断当前行是否已勾选
  bool _isChecked() {
    final trimmed = lineInfo.lineText.trimLeft();
    return trimmed.startsWith('- [x] ') || trimmed.startsWith('- [X] ');
  }

  /// 切换勾选状态
  void _toggleCheckbox() {
    final lineText = lineInfo.lineText;
    final trimmed = lineText.trimLeft();
    final indent = lineText.length - trimmed.length;

    // 计算 `[` 后面字符的位置
    // lineStart + indent + 3 = `- [` 的后一个位置
    final bracketContentPos = lineInfo.lineStart + indent + 3;

    final isChecked = _isChecked();
    final newChar = isChecked ? ' ' : 'x';

    final newText = controller.text.replaceRange(
      bracketContentPos,
      bracketContentPos + 1,
      newChar,
    );

    // 保持光标位置不变
    final currentSelection = controller.selection;
    controller.value = TextEditingValue(
      text: newText,
      selection: currentSelection,
    );
  }
}
