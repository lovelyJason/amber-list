import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/constants.dart';
import '../../data/models/note.dart';

/// 嵌入式笔记预览卡片
///
/// 设计哲学：
/// - 在任务详情关联笔记区域以卡片形式展示笔记摘要
/// - 显示标题 + 内容前几行预览
/// - 点击跳转笔记编辑页面
class EmbeddedNoteCard extends StatelessWidget {
  final Note note;

  /// 点击卡片跳转笔记详情
  final VoidCallback? onTap;

  /// 取消关联
  final VoidCallback? onUnlink;

  const EmbeddedNoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(AmberDimens.spacingSm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AmberColors.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 笔记图标
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.description_outlined,
                size: 16,
                color: AmberColors.primary,
              ),
            ),
            const SizedBox(width: AmberDimens.spacingSm),
            // 笔记信息
            Expanded(child: _buildNoteInfo()),
            // 取消关联按钮
            if (onUnlink != null) _buildUnlinkButton(),
          ],
        ),
      ),
    );
  }

  /// 笔记信息：标题 + 内容预览 + 更新时间
  Widget _buildNoteInfo() {
    final preview = _contentPreview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          note.title.isNotEmpty ? note.title : '无标题',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AmberColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (preview.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            preview,
            style: const TextStyle(
              fontSize: 11,
              color: AmberColors.textSecondary,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 2),
        Text(
          DateFormat('yyyy-MM-dd HH:mm').format(note.updatedAt),
          style: TextStyle(
            fontSize: 10,
            color: AmberColors.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  /// 内容预览（去掉 Markdown 标记，取前 100 字符）
  String get _contentPreview {
    if (note.content.isEmpty) return '';
    // 简单清理：去掉 Markdown 标题标记、链接语法、列表标记
    final cleaned = note.content
        .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
        .replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1')
        .replaceAll(RegExp(r'^[-*+]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '')
        .replaceAll(RegExp(r'\*{1,2}([^*]*)\*{1,2}'), r'$1')
        .replaceAll(RegExp(r'`([^`]*)`'), r'$1')
        .trim();
    if (cleaned.length > 100) return '${cleaned.substring(0, 100)}...';
    return cleaned;
  }

  /// 取消关联按钮
  Widget _buildUnlinkButton() {
    return GestureDetector(
      onTap: onUnlink,
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(
          Icons.close,
          size: 14,
          color: AmberColors.textSecondary,
        ),
      ),
    );
  }
}
