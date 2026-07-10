import 'package:flutter/material.dart';

import '../../../../core/constants/constants.dart';

/// 笔记卡片用的 Markdown 预览（轻量富文本，不可交互）
///
/// 支持删除线、加粗等内联样式渲染，同时保持卡片级别的高性能。
class NoteMarkdownPreview extends StatelessWidget {
  final String markdown;
  final int maxLines;
  final double fontSize;

  const NoteMarkdownPreview({
    super.key,
    required this.markdown,
    this.maxLines = 5,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = markdown.trim();
    if (trimmed.isEmpty) {
      return Text(
        '空笔记',
        style: TextStyle(
          fontSize: fontSize,
          color: AmberColors.textDisabled,
        ),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final baseStyle = TextStyle(
      fontSize: fontSize,
      height: 1.45,
      color: AmberColors.textSecondary,
    );

    return Text.rich(
      _buildSpans(trimmed, baseStyle),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  TextSpan _buildSpans(String text, TextStyle baseStyle) {
    final cleaned = _stripBlockSyntax(text);
    final spans = _parseInline(cleaned, baseStyle);
    return TextSpan(children: spans);
  }

  /// 移除块级语法标记，保留行内内容
  static String _stripBlockSyntax(String markdown) {
    var text = markdown;

    // 连续波浪号（AppFlowy 编码器产物）
    text = text.replaceAll(RegExp(r'~{4,}'), '');

    // 代码块
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '[代码块]');

    // 图片
    text = text.replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), '[图片]');

    // 块级标记
    text = text.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    text = text.replaceAll(
        RegExp(r'^[\-\*]\s*\[[x ]\]\s*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'\[[x ]\]\s*'), '');
    text = text.replaceAll(RegExp(r'^[\-\*\+]\s+', multiLine: true), '• ');

    // 有序列表：将 CommonMark 的 `1. 1. 1.` 重编为 `1. 2. 3.`
    var seqNum = 0;
    text = text.replaceAllMapped(
      RegExp(r'^\d+\.\s+', multiLine: true),
      (_) => '${++seqNum}. ',
    );

    text = text.replaceAll(RegExp(r'^>\s*', multiLine: true), '');
    text =
        text.replaceAll(RegExp(r'^[\-\*]{3,}\s*$', multiLine: true), '');

    // 压缩空白
    text = text.replaceAll(RegExp(r'\n\s*\n'), '\n');
    text = text.replaceAll(RegExp(r' +'), ' ');

    return text.trim();
  }

  // ── 内联 Markdown 标记 ──
  // 按优先级排列：链接 > 加粗 > 删除线 > 斜体 > 行内代码
  static final _inlinePattern = RegExp(
    r'\[([^\]]+)\]\([^)]+\)' // 链接 [text](url)
    r'|'
    r'\*\*(.+?)\*\*' // 加粗 **text**
    r'|'
    r'~~(.+?)~~' // 删除线 ~~text~~
    r'|'
    r'\*(.+?)\*' // 斜体 *text*
    r'|'
    r'`(.+?)`', // 行内代码 `code`
  );

  /// 递归解析内联 Markdown 为 TextSpan 列表
  List<InlineSpan> _parseInline(String text, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    var lastEnd = 0;

    for (final match in _inlinePattern.allMatches(text)) {
      // 匹配前的普通文本
      if (match.start > lastEnd) {
        final plain = text.substring(lastEnd, match.start);
        if (plain.isNotEmpty) spans.add(TextSpan(text: plain, style: baseStyle));
      }

      if (match.group(1) != null) {
        // 链接 → URL 型省略，否则保留文字
        final linkText = match.group(1)!;
        if (!linkText.startsWith('http')) {
          spans.add(TextSpan(text: linkText, style: baseStyle));
        }
      } else if (match.group(2) != null) {
        // 加粗
        spans.addAll(_parseInline(
          match.group(2)!,
          baseStyle.copyWith(fontWeight: FontWeight.w600),
        ));
      } else if (match.group(3) != null) {
        // 删除线
        spans.addAll(_parseInline(
          match.group(3)!,
          baseStyle.copyWith(
            decoration: TextDecoration.lineThrough,
            color: AmberColors.textDisabled,
          ),
        ));
      } else if (match.group(4) != null) {
        // 斜体
        spans.addAll(_parseInline(
          match.group(4)!,
          baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (match.group(5) != null) {
        // 行内代码
        spans.add(TextSpan(
          text: match.group(5),
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            backgroundColor: Colors.grey.withValues(alpha: 0.12),
          ),
        ));
      }

      lastEnd = match.end;
    }

    // 匹配后的剩余文本
    if (lastEnd < text.length) {
      final remaining = text.substring(lastEnd);
      // 清理残留 ~~
      final cleaned = remaining.replaceAll('~~', '');
      if (cleaned.isNotEmpty) {
        spans.add(TextSpan(text: cleaned, style: baseStyle));
      }
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text.replaceAll('~~', ''), style: baseStyle));
    }

    return spans;
  }
}
