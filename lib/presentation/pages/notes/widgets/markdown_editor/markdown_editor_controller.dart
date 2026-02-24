import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/constants/constants.dart';

/// Markdown 编辑器控制器
///
/// 设计哲学:
/// - 继承 TextEditingController，支持原生 TextField 所有功能
/// - 提供 Markdown 格式化方法（粗体、斜体、标题等）
/// - 监听光标位置变化，计算当前行信息
/// - 支持快捷键绑定（Cmd+B、Cmd+I 等）
/// - 通过 buildTextSpan 实现 Markdown 语法渲染（所见即所得）
/// - 链接点击：按住 Cmd/Ctrl 键点击蓝色链接可跳转浏览器
class MarkdownEditorController extends TextEditingController {
  /// 当前光标所在行的信息
  LineInfo? _currentLineInfo;
  LineInfo? get currentLineInfo => _currentLineInfo;

  /// 光标位置变化回调
  VoidCallback? onCursorChanged;

  /// 上一次的文本长度，用于检测是否输入了换行符
  int _previousTextLength = 0;

  /// 上一次光标位置，用于判断移动方向
  int _previousCursorPos = 0;

  MarkdownEditorController({String? text}) : super(text: text) {
    _previousTextLength = text?.length ?? 0;
    _previousCursorPos = text?.length ?? 0;
    addListener(_onTextChanged);
  }

  /// 重写 value setter，拦截光标移动
  /// 当光标进入复选框前缀区域时，自动跳过
  @override
  set value(TextEditingValue newValue) {
    final adjustedValue = _adjustCursorForCheckbox(newValue);
    _previousCursorPos = adjustedValue.selection.baseOffset;
    super.value = adjustedValue;
  }

  /// 调整光标位置，跳过复选框前缀区域
  TextEditingValue _adjustCursorForCheckbox(TextEditingValue newValue) {
    // 只处理非选择状态（光标移动）
    if (!newValue.selection.isCollapsed) return newValue;

    final cursorPos = newValue.selection.baseOffset;
    if (cursorPos < 0) return newValue;

    // 空文本直接返回
    if (newValue.text.isEmpty) return newValue;

    // 光标位置超出文本长度时修正（防止越界）
    final safeCursorPos = cursorPos.clamp(0, newValue.text.length);

    // 查找当前行信息
    final lineStart = newValue.text.lastIndexOf('\n', safeCursorPos > 0 ? safeCursorPos - 1 : 0) + 1;
    final lineEnd = newValue.text.indexOf('\n', safeCursorPos);
    final actualLineEnd = lineEnd == -1 ? newValue.text.length : lineEnd;

    // 边界检查：确保 lineStart <= actualLineEnd
    if (lineStart > actualLineEnd) return newValue;

    final lineText = newValue.text.substring(lineStart, actualLineEnd);
    final trimmed = lineText.trimLeft();
    final indent = lineText.length - trimmed.length;

    // 检查是否是复选框行
    final isCheckbox = trimmed.startsWith('- [ ] ') ||
        trimmed.startsWith('- [x] ') ||
        trimmed.startsWith('- [X] ');

    if (!isCheckbox) return newValue;

    // 复选框前缀区域：lineStart + indent 到 lineStart + indent + 6
    // 即 `- [ ] ` 这6个字符
    final prefixStart = lineStart + indent;
    final prefixEnd = prefixStart + 6; // `- [ ] ` = 6字符
    final contentStart = prefixEnd; // 内容开始位置

    // 判断移动方向
    final isMovingLeft = cursorPos < _previousCursorPos;
    final isMovingRight = cursorPos > _previousCursorPos;

    // 光标在前缀区域内（位置 1-5，不包括行首0和内容开始位置6）
    if (cursorPos > prefixStart && cursorPos < contentStart) {
      if (isMovingLeft) {
        // 向左移动时，跳到行首（缩进后的位置）
        return newValue.copyWith(
          selection: TextSelection.collapsed(offset: prefixStart),
        );
      } else if (isMovingRight) {
        // 向右移动时，跳到内容开始
        return newValue.copyWith(
          selection: TextSelection.collapsed(offset: contentStart),
        );
      }
    }

    return newValue;
  }

  /// 文本变化时更新行信息
  void _onTextChanged() {
    // 检测是否输入了换行符（自动续行列表）
    _handleAutoListContinuation();

    _updateCurrentLineInfo();
    onCursorChanged?.call();

    // 更新记录
    _previousTextLength = text.length;
  }

  /// 处理列表自动续行
  /// 当在列表项末尾按回车时，自动添加下一个列表前缀
  void _handleAutoListContinuation() {
    // 只处理新增字符的情况（不是删除或粘贴大段文本）
    if (text.length != _previousTextLength + 1) return;

    final cursorPos = selection.baseOffset;
    if (cursorPos <= 0) return;

    // 检查新增的字符是否是换行符
    if (text[cursorPos - 1] != '\n') return;

    // 获取上一行（换行符之前的行）
    final beforeNewline = text.substring(0, cursorPos - 1);
    final prevLineStart = beforeNewline.lastIndexOf('\n') + 1;
    final prevLineText = beforeNewline.substring(prevLineStart);

    // 检测上一行的列表类型并生成续行前缀
    final continuation = _getListContinuation(prevLineText);
    if (continuation == null) return;

    // 如果上一行是空列表项（只有前缀没有内容），则删除前缀而不是续行
    if (_isEmptyListItem(prevLineText)) {
      // 删除上一行的列表前缀，保留换行
      final newText = text.substring(0, prevLineStart) + text.substring(cursorPos);
      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: prevLineStart),
      );
      return;
    }

    // 插入续行前缀
    final newText = text.substring(0, cursorPos) +
        continuation +
        text.substring(cursorPos);

    value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPos + continuation.length),
    );
  }

  /// 获取列表续行前缀
  /// 返回 null 表示不是列表项
  String? _getListContinuation(String line) {
    final trimmed = line.trimLeft();
    final indent = line.length - trimmed.length;
    final indentStr = ' ' * indent;

    // 复选框：- [ ] 或 - [x]
    if (trimmed.startsWith('- [ ] ') || trimmed.startsWith('- [x] ') || trimmed.startsWith('- [X] ')) {
      return '$indentStr- [ ] ';
    }

    // 无序列表：- 或 *
    if (trimmed.startsWith('- ')) {
      return '$indentStr- ';
    }
    if (trimmed.startsWith('* ')) {
      return '$indentStr* ';
    }

    // 有序列表：1. 2. 3. ...
    final numberedMatch = RegExp(r'^(\d+)\. ').firstMatch(trimmed);
    if (numberedMatch != null) {
      final currentNum = int.parse(numberedMatch.group(1)!);
      return '$indentStr${currentNum + 1}. ';
    }

    // 引用：>
    if (trimmed.startsWith('> ')) {
      return '$indentStr> ';
    }

    return null;
  }

  /// 检查是否为空列表项（只有前缀没有内容）
  bool _isEmptyListItem(String line) {
    final trimmed = line.trimLeft();

    // 复选框空项
    if (trimmed == '- [ ] ' || trimmed == '- [x] ' || trimmed == '- [X] ' ||
        trimmed == '- [ ]' || trimmed == '- [x]' || trimmed == '- [X]') {
      return true;
    }

    // 无序列表空项
    if (trimmed == '- ' || trimmed == '* ' || trimmed == '-' || trimmed == '*') {
      return true;
    }

    // 有序列表空项
    if (RegExp(r'^\d+\. ?$').hasMatch(trimmed)) {
      return true;
    }

    // 引用空项
    if (trimmed == '> ' || trimmed == '>') {
      return true;
    }

    return false;
  }

  /// 手动刷新当前行信息（供外部调用）
  void refreshLineInfo() {
    _updateCurrentLineInfo();
  }

  /// 更新当前行信息
  void _updateCurrentLineInfo() {
    final cursorPos = selection.baseOffset;
    if (cursorPos < 0 || text.isEmpty) {
      _currentLineInfo = null;
      return;
    }

    // 查找当前行的起始和结束位置
    final beforeCursor = text.substring(0, cursorPos);
    final lineStart = beforeCursor.lastIndexOf('\n') + 1;

    final afterCursor = text.substring(cursorPos);
    final lineEndOffset = afterCursor.indexOf('\n');
    final lineEnd = lineEndOffset == -1 ? text.length : cursorPos + lineEndOffset;

    final lineText = text.substring(lineStart, lineEnd);
    final lineNumber = '\n'.allMatches(beforeCursor).length;

    _currentLineInfo = LineInfo(
      lineNumber: lineNumber,
      lineStart: lineStart,
      lineEnd: lineEnd,
      lineText: lineText,
      headingLevel: _detectHeadingLevel(lineText),
      isListItem: _detectListItem(lineText),
      isCheckbox: _detectCheckbox(lineText),
      isQuote: lineText.trimLeft().startsWith('>'),
      isCodeBlock: lineText.trimLeft().startsWith('```'),
    );
  }

  /// 检测标题级别 (0 = 非标题, 1-6 = H1-H6)
  int _detectHeadingLevel(String line) {
    final trimmed = line.trimLeft();
    if (!trimmed.startsWith('#')) return 0;

    int level = 0;
    for (int i = 0; i < trimmed.length && i < 6; i++) {
      if (trimmed[i] == '#') {
        level++;
      } else {
        break;
      }
    }

    // 确保 # 后面必须有空格才是标题（符合 Markdown 规范）
    if (level > 0 && level < trimmed.length && trimmed[level] == ' ') {
      return level;
    }

    return 0;
  }

  /// 检测是否为列表项
  bool _detectListItem(String line) {
    final trimmed = line.trimLeft();
    return trimmed.startsWith('- ') ||
        trimmed.startsWith('* ') ||
        RegExp(r'^\d+\. ').hasMatch(trimmed);
  }

  /// 检测是否为复选框
  bool _detectCheckbox(String line) {
    final trimmed = line.trimLeft();
    return trimmed.startsWith('- [ ] ') ||
           trimmed.startsWith('- [x] ') ||
           trimmed.startsWith('- [X] ');
  }

  // ============================================================
  // Markdown 格式化方法
  // ============================================================

  /// 切换粗体 **text**
  void toggleBold() {
    _wrapSelection('**', '**');
  }

  /// 切换斜体 *text*
  void toggleItalic() {
    _wrapSelection('*', '*');
  }

  /// 切换下划线 <u>text</u>
  void toggleUnderline() {
    _wrapSelection('<u>', '</u>');
  }

  /// 切换删除线 ~~text~~
  void toggleStrikethrough() {
    _wrapSelection('~~', '~~');
  }

  /// 切换高亮 ==text==
  void toggleHighlight() {
    _wrapSelection('==', '==');
  }

  /// 切换行内代码 `code`
  void toggleInlineCode() {
    _wrapSelection('`', '`');
  }

  /// 插入链接 [text](url)
  void insertLink(String displayText, String url) {
    final linkText = '[$displayText]($url)';
    _replaceSelection(linkText);
  }

  /// 插入标题
  void insertHeading(int level) {
    if (level < 1 || level > 6) return;

    final prefix = '${'#' * level} ';
    _insertAtLineStart(prefix);
  }

  /// 插入无序列表
  void insertBulletList() {
    _insertAtLineStart('- ');
  }

  /// 插入有序列表
  void insertNumberedList() {
    _insertAtLineStart('1. ');
  }

  /// 插入复选框
  void insertCheckbox() {
    _insertAtLineStart('- [ ] ');
  }

  /// 插入引用
  void insertQuote() {
    _insertAtLineStart('> ');
  }

  /// 插入分割线
  void insertDivider() {
    _insertNewLine('---');
  }

  /// 插入代码块
  void insertCodeBlock([String language = '']) {
    _insertNewLine('```$language\n\n```');
  }

  /// 插入表格（2x2 默认）
  void insertTable() {
    const table = '''
| 标题1 | 标题2 |
|-------|-------|
| 内容1 | 内容2 |
''';
    _insertNewLine(table);
  }

  /// 插入当前时间戳
  void insertTimestamp() {
    final now = DateTime.now();
    final timestamp =
        '${now.year}-${_pad(now.month)}-${_pad(now.day)} ${_pad(now.hour)}:${_pad(now.minute)}';
    _replaceSelection(timestamp);
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  // ============================================================
  // 内部辅助方法
  // ============================================================

  /// 用前后缀包裹选中文本
  void _wrapSelection(String prefix, String suffix) {
    final start = selection.start;
    final end = selection.end;

    if (start < 0) return;

    final selectedText = text.substring(start, end);
    final newText = '$prefix$selectedText$suffix';

    value = value.copyWith(
      text: text.replaceRange(start, end, newText),
      selection: TextSelection.collapsed(
        offset: start + prefix.length + selectedText.length,
      ),
    );
  }

  /// 替换选中文本
  void _replaceSelection(String replacement) {
    final start = selection.start;
    final end = selection.end;

    if (start < 0) return;

    value = value.copyWith(
      text: text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  /// 在当前行开头插入内容
  void _insertAtLineStart(String prefix) {
    // 获取当前行信息，如果为 null 则手动计算
    int lineStart;
    String lineText;

    if (_currentLineInfo != null) {
      lineStart = _currentLineInfo!.lineStart;
      lineText = _currentLineInfo!.lineText;
    } else {
      // 手动计算行信息（处理空文本或首行情况）
      final cursorPos = selection.baseOffset;
      if (cursorPos < 0) return;

      if (text.isEmpty) {
        // 空文本，直接在开头插入
        lineStart = 0;
        lineText = '';
      } else {
        final beforeCursor = text.substring(0, cursorPos);
        lineStart = beforeCursor.lastIndexOf('\n') + 1;
        final afterCursor = text.substring(cursorPos);
        final lineEndOffset = afterCursor.indexOf('\n');
        final lineEnd = lineEndOffset == -1 ? text.length : cursorPos + lineEndOffset;
        lineText = text.substring(lineStart, lineEnd);
      }
    }

    // 检查是否已有相同前缀，有则移除
    if (lineText.trimLeft().startsWith(prefix.trim())) {
      // 移除前缀
      final prefixStart = lineStart + lineText.indexOf(prefix.trim());
      value = value.copyWith(
        text: text.replaceRange(prefixStart, prefixStart + prefix.length, ''),
        selection: TextSelection.collapsed(
          offset: selection.baseOffset - prefix.length,
        ),
      );
    } else {
      // 添加前缀
      value = value.copyWith(
        text: text.replaceRange(lineStart, lineStart, prefix),
        selection: TextSelection.collapsed(
          offset: selection.baseOffset + prefix.length,
        ),
      );
    }
  }

  /// 在新行插入内容
  void _insertNewLine(String content) {
    final cursorPos = selection.baseOffset;
    if (cursorPos < 0) return;

    // 确保在新行插入
    final needNewlineBefore = cursorPos > 0 && text[cursorPos - 1] != '\n';
    final insertText = '${needNewlineBefore ? '\n' : ''}$content\n';

    value = value.copyWith(
      text: text.replaceRange(cursorPos, cursorPos, insertText),
      selection: TextSelection.collapsed(
        offset: cursorPos + insertText.length - 1,
      ),
    );
  }

  // ============================================================
  // Markdown 渲染（buildTextSpan 实现所见即所得）
  // ============================================================

  /// 重写 buildTextSpan 实现 Markdown 语法渲染
  ///
  /// 支持的语法：
  /// - 标题：# H1, ## H2, ### H3 等
  /// - 列表：- 无序列表, 1. 有序列表
  /// - 复选框：- [ ] 未完成, - [x] 已完成
  /// - 引用：> 引用内容
  /// - 粗体：**粗体**
  /// - 斜体：*斜体*
  /// - 删除线：~~删除线~~
  /// - 高亮：==高亮==
  /// - 行内代码：`代码`
  /// - 链接：[文字](url)
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle(
      fontSize: 14,
      height: 1.5, // 紧凑行高，避免间距过大
      color: AmberColors.textPrimary,
    );

    if (text.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }

    final lines = text.split('\n');
    final List<InlineSpan> spans = [];
    int lineStart = 0; // 跟踪每行的起始位置

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // 解析每一行，生成对应的 TextSpan，传入行起始位置
      spans.addAll(_parseLine(line, baseStyle, lineStart));

      // 添加换行符（最后一行除外）
      if (i < lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: baseStyle));
      }

      // 更新下一行的起始位置（当前行长度 + 换行符）
      lineStart += line.length + 1;
    }

    return TextSpan(children: spans, style: baseStyle);
  }

  /// 解析单行内容
  /// [lineStart] 是该行在整个文本中的起始位置，用于checkbox点击时定位修改位置
  List<InlineSpan> _parseLine(String line, TextStyle baseStyle, int lineStart) {
    final trimmed = line.trimLeft();
    final indent = line.length - trimmed.length;
    final indentStr = ' ' * indent;

    // 检测标题
    final headingLevel = _detectHeadingLevel(line);
    if (headingLevel > 0) {
      return _buildHeadingSpans(line, headingLevel, baseStyle);
    }

    // 检测复选框
    if (_detectCheckbox(line)) {
      return _buildCheckboxSpans(line, baseStyle, indentStr, lineStart + indent);
    }

    // 检测无序列表
    if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
      return _buildBulletListSpans(line, baseStyle, indentStr, trimmed);
    }

    // 检测有序列表
    final numberedMatch = RegExp(r'^(\d+)\. (.*)$').firstMatch(trimmed);
    if (numberedMatch != null) {
      return _buildNumberedListSpans(line, baseStyle, indentStr, numberedMatch);
    }

    // 检测引用
    if (trimmed.startsWith('> ')) {
      return _buildQuoteSpans(line, baseStyle, indentStr, trimmed);
    }

    // 检测分割线
    if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
      return [
        TextSpan(
          text: line,
          style: baseStyle.copyWith(
            color: AmberColors.divider,
            letterSpacing: 4,
          ),
        ),
      ];
    }

    // 普通行，解析内联格式
    return _parseInlineFormatting(line, baseStyle);
  }

  /// 构建标题 TextSpan
  /// 使用极小字号隐藏 # 前缀，保持光标位置正确
  /// 通过 WidgetSpan 撑起行高，避免被截断
  List<InlineSpan> _buildHeadingSpans(String line, int level, TextStyle baseStyle) {
    final hashPrefix = '#' * level;
    final prefixWithSpace = '$hashPrefix ';

    // 找到 # 前缀的位置
    final prefixStart = line.indexOf(hashPrefix);
    final contentStart = line.indexOf(prefixWithSpace) + prefixWithSpace.length;
    final content = contentStart <= line.length ? line.substring(contentStart) : '';

    // 标题样式
    // 注意：height 必须和 baseStyle 保持一致（1.5），否则行高计算会出错
    final fontSize = _getHeadingFontSize(level);
    final headingStyle = baseStyle.copyWith(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: AmberColors.textPrimary,
      height: 1.5, // 和 baseStyle 一致，确保行高计算准确
    );

    // 隐藏 # 前缀的样式（极小字号 + 透明，不占用宽度）
    final hiddenStyle = baseStyle.copyWith(
      fontSize: 0.01,
      color: Colors.transparent,
      height: 1.0,
    );

    return [
      // 保留前导空格（如果有的话）
      if (prefixStart > 0)
        TextSpan(
          text: line.substring(0, prefixStart),
          style: baseStyle,
        ),
      // # 前缀用极小字号隐藏（几乎不占宽度）
      TextSpan(
        text: prefixWithSpace,
        style: hiddenStyle,
      ),
      // 内容用标题样式
      ..._parseInlineFormatting(content, headingStyle),
    ];
  }

  /// 获取标题字体大小
  /// 字号差距缩小，视觉更统一
  double _getHeadingFontSize(int level) {
    const sizes = [20.0, 18.0, 16.0, 15.0, 14.5, 14.0];
    return sizes[level - 1];
  }

  /// 构建复选框 TextSpan
  ///
  /// 设计哲学：
  /// - `- ` 前缀用极小透明字体隐藏（2字符）
  /// - `[` 用 WidgetSpan 显示 Material Icon（占1个字符位置）
  /// - ` ]` 或 `x]` 用极小透明字体隐藏（2字符）
  /// - 最后的空格正常显示（1字符）
  /// - 总计 6 个字符位置，与原始 `- [ ] ` 一致
  /// [checkboxStart] 是 `- [ ] ` 在文本中的起始位置，用于点击时定位修改
  List<InlineSpan> _buildCheckboxSpans(String line, TextStyle baseStyle, String indentStr, int checkboxStart) {
    final trimmed = line.trimLeft();
    final isChecked = trimmed.startsWith('- [x] ') || trimmed.startsWith('- [X] ');
    final content = trimmed.substring(6); // 跳过 `- [ ] ` 或 `- [x] `

    final contentStyle = isChecked
        ? baseStyle.copyWith(
            color: AmberColors.textDisabled,
            decoration: TextDecoration.lineThrough,
          )
        : baseStyle;

    // 隐藏样式：极小字号 + 透明
    final hiddenStyle = baseStyle.copyWith(
      fontSize: 0.01,
      color: Colors.transparent,
      height: 1.0,
    );

    return [
      if (indentStr.isNotEmpty)
        TextSpan(text: indentStr, style: baseStyle),
      // `- ` 用极小透明字体隐藏（2字符）
      TextSpan(text: '- ', style: hiddenStyle),
      // `[` 用 WidgetSpan 显示 Icon（占1个字符位置）
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: GestureDetector(
          onTap: () => _toggleCheckbox(checkboxStart, isChecked),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Icon(
              isChecked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
              color: isChecked ? AmberColors.success : AmberColors.textSecondary,
            ),
          ),
        ),
      ),
      // ` ]` 或 `x]` 用极小透明字体隐藏（2字符）
      TextSpan(text: isChecked ? 'x]' : ' ]', style: hiddenStyle),
      // 最后的空格正常显示（1字符）
      TextSpan(text: ' ', style: baseStyle),
      ..._parseInlineFormatting(content, contentStyle),
    ];
  }

  /// 切换复选框状态
  /// [checkboxStart] 是 `- [ ] ` 在文本中的起始位置
  /// [isCurrentlyChecked] 当前是否已勾选
  void _toggleCheckbox(int checkboxStart, bool isCurrentlyChecked) {
    // 计算 [ ] 或 [x] 中间字符的位置（`- [` 后面的位置）
    final bracketContentPos = checkboxStart + 3; // `- [` = 3个字符

    // 替换 [ ] 为 [x] 或反之
    final newChar = isCurrentlyChecked ? ' ' : 'x';
    final newText = text.replaceRange(bracketContentPos, bracketContentPos + 1, newChar);

    // 保持光标位置不变
    final currentSelection = selection;
    value = TextEditingValue(
      text: newText,
      selection: currentSelection,
    );
  }

  /// 构建无序列表 TextSpan
  List<InlineSpan> _buildBulletListSpans(
    String line,
    TextStyle baseStyle,
    String indentStr,
    String trimmed,
  ) {
    // 跳过 "- " 或 "* " 前缀，获取内容
    final content = trimmed.substring(2);

    return [
      if (indentStr.isNotEmpty)
        TextSpan(text: indentStr, style: baseStyle),
      // 项目符号
      TextSpan(
        text: '• ',
        style: baseStyle.copyWith(
          color: AmberColors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      ..._parseInlineFormatting(content, baseStyle),
    ];
  }

  /// 构建有序列表 TextSpan
  List<InlineSpan> _buildNumberedListSpans(
    String line,
    TextStyle baseStyle,
    String indentStr,
    RegExpMatch match,
  ) {
    final number = match.group(1)!;
    final content = match.group(2)!;

    return [
      if (indentStr.isNotEmpty)
        TextSpan(text: indentStr, style: baseStyle),
      // 数字
      TextSpan(
        text: '$number. ',
        style: baseStyle.copyWith(
          color: AmberColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      ..._parseInlineFormatting(content, baseStyle),
    ];
  }

  /// 构建引用 TextSpan
  ///
  /// 设计哲学：
  /// - `> ` 前缀用透明零宽字体隐藏（保持光标位置正确）
  /// - 用 WidgetSpan 显示琥珀色竖线作为引用标识
  /// - 引用内容用斜体灰色显示
  List<InlineSpan> _buildQuoteSpans(
    String line,
    TextStyle baseStyle,
    String indentStr,
    String trimmed,
  ) {
    // 提取引用内容（去掉 `> ` 前缀）
    final content = trimmed.length > 2 ? trimmed.substring(2) : '';
    // 引用内容样式：灰色，不用斜体（斜体会导致光标和文字视觉重叠）
    final quoteStyle = baseStyle.copyWith(
      color: AmberColors.textSecondary,
    );

    // `> ` 两个字符用透明样式隐藏，用 WidgetSpan 画真正的竖线
    final hiddenStyle = baseStyle.copyWith(
      color: Colors.transparent,
      fontSize: 1, // 极小字号，几乎不占宽度
    );

    return [
      if (indentStr.isNotEmpty)
        TextSpan(text: indentStr, style: baseStyle),
      // 用 WidgetSpan 画一个真正的竖线（高度超出行高，实现连贯）
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          width: 2,
          height: 24, // 超出行高(21)，让上下行连接
          margin: const EdgeInsets.only(right: 6),
          color: AmberColors.primary,
        ),
      ),
      // `> ` 原始字符隐藏（保持光标位置正确）
      TextSpan(text: '> ', style: hiddenStyle),
      ..._parseInlineFormatting(content, quoteStyle),
    ];
  }

  /// 解析内联格式（粗体、斜体、代码、链接等）
  List<InlineSpan> _parseInlineFormatting(String text, TextStyle baseStyle) {
    if (text.isEmpty) return [TextSpan(text: '', style: baseStyle)];

    final spans = <InlineSpan>[];

    // 综合正则匹配所有内联格式
    // 注意：纯URL放在最后，避免和Markdown链接冲突
    final pattern = RegExp(
      r'\*\*(.+?)\*\*|'           // group(1): **粗体**
      r'(?<!\*)\*([^*]+?)\*(?!\*)|'  // group(2): *斜体* (非粗体)
      r'~~(.+?)~~|'              // group(3): ~~删除线~~
      r'==(.+?)==|'              // group(4): ==高亮==
      r'`([^`]+)`|'              // group(5): `代码`
      r'\[([^\]]+)\]\(([^)]+)\)|' // group(6,7): [链接](url)
      r'(https?://[^\s\u4e00-\u9fa5]+)', // group(8): 纯URL（不含中文和空格）
    );

    int lastEnd = 0;
    for (final match in pattern.allMatches(text)) {
      // 添加匹配前的普通文本
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }

      final fullMatch = match.group(0)!;

      if (fullMatch.startsWith('**')) {
        // 粗体
        spans.add(TextSpan(
          text: match.group(1),
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      } else if (fullMatch.startsWith('*') && !fullMatch.startsWith('**')) {
        // 斜体
        spans.add(TextSpan(
          text: match.group(2),
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (fullMatch.startsWith('~~')) {
        // 删除线
        spans.add(TextSpan(
          text: match.group(3),
          style: baseStyle.copyWith(decoration: TextDecoration.lineThrough),
        ));
      } else if (fullMatch.startsWith('==')) {
        // 高亮
        spans.add(TextSpan(
          text: match.group(4),
          style: baseStyle.copyWith(
            backgroundColor: Colors.yellow.shade200,
          ),
        ));
      } else if (fullMatch.startsWith('`')) {
        // 行内代码
        spans.add(TextSpan(
          text: match.group(5),
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            backgroundColor: AmberColors.divider.withValues(alpha: 0.5),
            color: Colors.pink.shade700,
          ),
        ));
      } else if (fullMatch.startsWith('[')) {
        // Markdown 链接：[文字](url)
        final linkText = match.group(6)!;
        final linkUrl = match.group(7)!;
        spans.add(TextSpan(
          text: linkText,
          style: baseStyle.copyWith(
            color: const Color(0xFF1976D2), // 蓝色链接
            decoration: TextDecoration.underline,
            decorationColor: const Color(0xFF1976D2),
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _launchUrl(linkUrl),
        ));
      } else if (fullMatch.startsWith('http')) {
        // 纯 URL 链接（自动识别 https:// 或 http://）
        final url = match.group(8)!;
        spans.add(TextSpan(
          text: url,
          style: baseStyle.copyWith(
            color: const Color(0xFF1976D2), // 蓝色链接
            decoration: TextDecoration.underline,
            decorationColor: const Color(0xFF1976D2),
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _launchUrl(url),
        ));
      }

      lastEnd = match.end;
    }

    // 添加最后的普通文本
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return spans.isEmpty ? [TextSpan(text: text, style: baseStyle)] : spans;
  }

  /// 打开链接（跳转浏览器）
  Future<void> _launchUrl(String url) async {
    // 处理内部链接（note: 和 task: 前缀）
    if (url.startsWith('note:') || url.startsWith('task:')) {
      // TODO: 内部链接跳转逻辑
      return;
    }

    // 外部链接，跳转浏览器
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    removeListener(_onTextChanged);
    super.dispose();
  }
}

/// 当前行信息
class LineInfo {
  /// 行号（从0开始）
  final int lineNumber;

  /// 行在文本中的起始位置
  final int lineStart;

  /// 行在文本中的结束位置
  final int lineEnd;

  /// 行文本内容
  final String lineText;

  /// 标题级别（0 = 非标题）
  final int headingLevel;

  /// 是否为列表项
  final bool isListItem;

  /// 是否为复选框
  final bool isCheckbox;

  /// 是否为引用
  final bool isQuote;

  /// 是否为代码块
  final bool isCodeBlock;

  const LineInfo({
    required this.lineNumber,
    required this.lineStart,
    required this.lineEnd,
    required this.lineText,
    required this.headingLevel,
    required this.isListItem,
    required this.isCheckbox,
    required this.isQuote,
    required this.isCodeBlock,
  });

  /// 是否为空行
  bool get isEmpty => lineText.trim().isEmpty;

  /// 当前行是否为新行开头（可显示加号菜单）
  bool get canShowPlusMenu => isEmpty;

  /// 获取当前行的字体大小
  /// 标题有不同字号，普通行是 14px
  double get fontSize {
    if (headingLevel > 0 && headingLevel <= 6) {
      const headingFontSizes = [20.0, 18.0, 16.0, 15.0, 14.5, 14.0];
      return headingFontSizes[headingLevel - 1];
    }
    return 14.0;
  }

  /// 获取当前行的行高（fontSize * 1.5）
  double get lineHeight => fontSize * 1.5;

  /// 获取光标/指示器的标准高度
  /// 统一为 18px，不随行类型变化
  double get cursorHeight => 18.0;

  /// 获取指示器的垂直偏移量（让指示器垂直居中在行内）
  double get indicatorVerticalOffset => (lineHeight - cursorHeight) / 2;
}
