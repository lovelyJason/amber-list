import 'package:flutter/material.dart';

import '../../../../core/constants/constants.dart';

/// 笔记卡片用的 Markdown 预览（轻量、不可交互）
///
/// 设计哲学：
/// - 性能优先！卡片预览不需要完整的 Markdown 渲染
/// - 使用纯文本显示，避免 flutter_markdown 的解析开销
/// - 移除 Markdown 语法符号，只保留可读文本
/// - 卡片数量多时也能保持流畅滚动
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

    // 将 Markdown 转换为纯文本预览（移除语法符号）
    final plainText = _stripMarkdown(trimmed);

    return Text(
      plainText,
      style: TextStyle(
        fontSize: fontSize,
        height: 1.45,
        color: AmberColors.textSecondary,
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// 移除 Markdown 语法，保留可读文本
  ///
  /// 这比完整的 Markdown 解析快 10 倍以上
  String _stripMarkdown(String markdown) {
    var text = markdown;

    // 移除标题标记 (# ## ### 等)
    text = text.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');

    // 移除加粗/斜体标记 (**text** 或 *text* 或 __text__ 或 _text_)
    text = text.replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1');
    text = text.replaceAll(RegExp(r'__(.+?)__'), r'$1');
    text = text.replaceAll(RegExp(r'\*(.+?)\*'), r'$1');
    text = text.replaceAll(RegExp(r'_(.+?)_'), r'$1');

    // 移除删除线 (~~text~~)
    text = text.replaceAll(RegExp(r'~~(.+?)~~'), r'$1');

    // 移除行内代码 (`code`)
    text = text.replaceAll(RegExp(r'`(.+?)`'), r'$1');

    // 移除链接，保留链接文字 ([text](url) → text)
    text = text.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');

    // 移除图片 (![alt](url) → [图片])
    text = text.replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), '[图片]');

    // 移除无序列表标记 (- 或 * 或 +)
    text = text.replaceAll(RegExp(r'^[\-\*\+]\s+', multiLine: true), '');

    // 移除有序列表标记 (1. 2. 3.)
    text = text.replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '');

    // 移除任务列表标记 (- [ ] 或 - [x])
    text = text.replaceAll(RegExp(r'^[\-\*]\s*\[[x ]\]\s*', multiLine: true), '');
    // 同时处理复选框变体 (如直接的 [x] [ ])
    text = text.replaceAll(RegExp(r'\[[x ]\]\s*'), '');

    // 移除引用标记 (>)
    text = text.replaceAll(RegExp(r'^>\s*', multiLine: true), '');

    // 移除代码块 (```code```)
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '[代码块]');

    // 移除水平线 (--- 或 ***)
    text = text.replaceAll(RegExp(r'^[\-\*]{3,}\s*$', multiLine: true), '');

    // 压缩多个连续空行为单个空格
    text = text.replaceAll(RegExp(r'\n\s*\n'), '\n');

    // 压缩多个连续空格
    text = text.replaceAll(RegExp(r' +'), ' ');

    return text.trim();
  }
}

