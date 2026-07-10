import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/constants.dart';
import '../../../../data/models/models.dart';
import 'note_markdown_preview.dart';

/// 笔记网格卡片
///
/// 设计哲学：
/// - 固定尺寸 240x180，适合网格排列
/// - 显示标题、内容预览、标签和更新时间
/// - 选中态高亮显示
class NoteCard extends StatelessWidget {
  final Note note;
  final bool isSelected;
  final VoidCallback onTap;
  final void Function(TapDownDetails) onSecondaryTapDown;

  const NoteCard({
    super.key,
    required this.note,
    required this.isSelected,
    required this.onTap,
    required this.onSecondaryTapDown,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onSecondaryTapDown: onSecondaryTapDown,
      child: Container(
        width: 240,
        height: 180,
        padding: const EdgeInsets.all(AmberDimens.spacingMd),
        decoration: BoxDecoration(
          color:
              isSelected ? AmberColors.primaryLight : AmberColors.cardBackground,
          borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            _buildTitleRow(),
            const SizedBox(height: AmberDimens.spacingSm),
            // 内容预览
            Expanded(child: _buildContentPreview()),
            // 底部日期
            _buildDateRow(),
          ],
        ),
      ),
    );
  }

  /// 构建标题行
  Widget _buildTitleRow() {
    return Row(
      children: [
        if (note.isPinned)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.push_pin, size: 14, color: AmberColors.primary),
          ),
        Expanded(
          child: Text(
            note.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (note.tags.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AmberColors.primaryTransparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              note.tags.first,
              style: const TextStyle(
                fontSize: 10,
                color: AmberColors.primary,
              ),
            ),
          ),
      ],
    );
  }

  /// 构建内容预览
  Widget _buildContentPreview() {
    return NoteMarkdownPreview(
      markdown: note.previewMarkdown,
      maxLines: 5,
      fontSize: 12,
    );
  }

  /// 构建日期行
  Widget _buildDateRow() {
    return Text(
      _formatDate(note.updatedAt),
      style: const TextStyle(
        fontSize: 11,
        color: AmberColors.textDisabled,
      ),
    );
  }

  /// 格式化日期显示
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return DateFormat('M月d日').format(date);
    }
  }
}

/// 新建笔记卡片
///
/// 设计哲学：
/// - 与 NoteCard 同尺寸，保持网格一致性
/// - 虚线边框 + 浅色背景，暗示"添加"操作
/// - 居中显示图标和文字
class CreateNoteCard extends StatelessWidget {
  final VoidCallback onTap;

  const CreateNoteCard({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 240,
        height: 180,
        decoration: BoxDecoration(
          color: AmberColors.sidebarBackground,
          borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
          border: Border.all(
            color: AmberColors.divider,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AmberColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                size: 24,
                color: AmberColors.primary,
              ),
            ),
            const SizedBox(height: AmberDimens.spacingSm),
            const Text(
              '新建笔记',
              style: TextStyle(
                color: AmberColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 笔记列表项
///
/// 自定义卡片风格，带 hover 交互和选中态高亮
class NoteListItem extends StatefulWidget {
  final Note note;
  final bool isSelected;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const NoteListItem({
    super.key,
    required this.note,
    required this.isSelected,
    required this.index,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<NoteListItem> createState() => _NoteListItemState();
}

class _NoteListItemState extends State<NoteListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AmberColors.primaryLight
                : _isHovered
                    ? Colors.black.withValues(alpha: 0.02)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
            border: Border.all(
              color: widget.isSelected
                  ? AmberColors.primary.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              _buildIcon(note),
              const SizedBox(width: 14),
              Expanded(child: _buildContent(note)),
              const SizedBox(width: 12),
              _buildTrailing(note),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(Note note) {
    final isPinned = note.isPinned;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: isPinned
            ? AmberColors.primary.withValues(alpha: 0.12)
            : AmberColors.sidebarBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        isPinned ? Icons.push_pin_rounded : Icons.description_outlined,
        size: 16,
        color: isPinned ? AmberColors.primary : AmberColors.textDisabled,
      ),
    );
  }

  Widget _buildContent(Note note) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          note.title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AmberColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (note.previewMarkdown.isNotEmpty) ...[
          const SizedBox(height: 3),
          NoteMarkdownPreview(
            markdown: note.previewMarkdown,
            maxLines: 1,
            fontSize: 12.5,
          ),
        ],
      ],
    );
  }

  Widget _buildTrailing(Note note) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (note.tags.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AmberColors.primaryTransparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              note.tags.first,
              style: const TextStyle(
                fontSize: 11,
                color: AmberColors.primaryDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Text(
          _formatDate(note.updatedAt),
          style: const TextStyle(
            fontSize: 12,
            color: AmberColors.textDisabled,
          ),
        ),
        AnimatedOpacity(
          opacity: _isHovered ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ReorderableDragStartListener(
              index: widget.index,
              child: const Icon(
                Icons.drag_indicator_rounded,
                size: 18,
                color: AmberColors.textDisabled,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return DateFormat('M月d日').format(date);
  }
}
