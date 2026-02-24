import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/constants.dart';
import '../../../data/models/models.dart';
import '../../widgets/common/toast/toast_manager.dart';
import 'notes_provider.dart';

/// 笔记垃圾篓页面
///
/// 功能说明：
/// - 展示所有已软删除的笔记
/// - 支持恢复单个笔记
/// - 支持永久删除单个笔记
/// - 支持清空垃圾篓
/// - 笔记删除后 30 天自动清理（启动时执行）
class NotesTrashPage extends ConsumerWidget {
  const NotesTrashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trashNotesAsync = ref.watch(trashNotesProvider);

    return Scaffold(
      backgroundColor: AmberColors.background,
      appBar: AppBar(
        backgroundColor: AmberColors.cardBackground,
        elevation: 0,
        toolbarHeight: 56,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 80), // 红绿灯宽度留白
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: AmberColors.textPrimary),
            ),
            const SizedBox(width: 8),
            const Text(
              '垃圾篓',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AmberColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          // 清空垃圾篓按钮
          trashNotesAsync.when(
            data: (notes) => notes.isNotEmpty
                ? IconButton(
                    onPressed: () => _showEmptyTrashDialog(context, ref),
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    tooltip: '清空垃圾篓',
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (e, s) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: trashNotesAsync.when(
        data: (notes) => notes.isEmpty
            ? _buildEmptyState()
            : _buildNotesList(context, ref, notes),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            '加载失败: $error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.delete_outline,
            size: 64,
            color: AmberColors.textDisabled.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AmberDimens.spacingMd),
          const Text(
            '垃圾篓是空的',
            style: TextStyle(
              fontSize: 16,
              color: AmberColors.textSecondary,
            ),
          ),
          const SizedBox(height: AmberDimens.spacingSm),
          const Text(
            '删除的笔记会在这里保留 30 天',
            style: TextStyle(
              fontSize: 13,
              color: AmberColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建笔记列表
  Widget _buildNotesList(BuildContext context, WidgetRef ref, List<Note> notes) {
    return ListView.builder(
      padding: const EdgeInsets.all(AmberDimens.spacingMd),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return _buildNoteItem(context, ref, note);
      },
    );
  }

  /// 构建单个笔记项
  Widget _buildNoteItem(BuildContext context, WidgetRef ref, Note note) {
    final daysLeft = _getDaysUntilExpire(note.deletedAt);

    return Card(
      margin: const EdgeInsets.only(bottom: AmberDimens.spacingSm),
      color: AmberColors.cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
        side: const BorderSide(color: AmberColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AmberDimens.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Expanded(
                  child: Text(
                    note.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AmberColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 剩余天数标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: daysLeft <= 7
                        ? Colors.red.withValues(alpha: 0.1)
                        : AmberColors.primaryTransparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$daysLeft 天后删除',
                    style: TextStyle(
                      fontSize: 11,
                      color: daysLeft <= 7 ? Colors.red : AmberColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AmberDimens.spacingSm),
            // 内容预览
            Text(
              note.summary.isNotEmpty ? note.summary : '空笔记',
              style: TextStyle(
                fontSize: 13,
                color: note.summary.isNotEmpty
                    ? AmberColors.textSecondary
                    : AmberColors.textDisabled,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AmberDimens.spacingMd),
            // 操作按钮
            Row(
              children: [
                // 删除时间
                Text(
                  '删除于 ${_formatDeleteTime(note.deletedAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AmberColors.textDisabled,
                  ),
                ),
                const Spacer(),
                // 恢复按钮
                TextButton.icon(
                  onPressed: () => _restoreNote(context, ref, note),
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('恢复'),
                  style: TextButton.styleFrom(
                    foregroundColor: AmberColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                const SizedBox(width: AmberDimens.spacingSm),
                // 永久删除按钮
                TextButton.icon(
                  onPressed: () => _showDeleteForeverDialog(context, ref, note),
                  icon: const Icon(Icons.delete_forever, size: 18),
                  label: const Text('删除'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 计算剩余天数
  int _getDaysUntilExpire(DateTime? deletedAt) {
    if (deletedAt == null) return 30;
    final expireDate = deletedAt.add(const Duration(days: 30));
    final daysLeft = expireDate.difference(DateTime.now()).inDays;
    return daysLeft.clamp(0, 30);
  }

  /// 格式化删除时间
  String _formatDeleteTime(DateTime? deletedAt) {
    if (deletedAt == null) return '未知';
    final now = DateTime.now();
    final diff = now.difference(deletedAt);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} 分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} 小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} 天前';
    } else {
      return DateFormat('M月d日').format(deletedAt);
    }
  }

  /// 恢复笔记
  void _restoreNote(BuildContext context, WidgetRef ref, Note note) {
    ref.read(notesProvider.notifier).restoreNote(note.id);
    ToastManager().show(
      context,
      '笔记已恢复',
      type: ToastType.success,
    );
  }

  /// 显示永久删除确认对话框
  Future<void> _showDeleteForeverDialog(
    BuildContext context,
    WidgetRef ref,
    Note note,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('永久删除'),
        content: Text('确定要永久删除笔记"${note.title}"吗？\n此操作无法撤销！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              '取消',
              style: TextStyle(color: AmberColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(notesProvider.notifier).permanentlyDeleteNote(note.id);
      if (context.mounted) {
        ToastManager().show(
          context,
          '笔记已永久删除',
          type: ToastType.info,
        );
      }
    }
  }

  /// 显示清空垃圾篓确认对话框
  Future<void> _showEmptyTrashDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空垃圾篓'),
        content: const Text('确定要清空垃圾篓吗？\n所有笔记将被永久删除，此操作无法撤销！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              '取消',
              style: TextStyle(color: AmberColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final count = await ref.read(notesProvider.notifier).emptyTrash();
      if (context.mounted) {
        ToastManager().show(
          context,
          '已清空 $count 条笔记',
          type: ToastType.info,
        );
      }
    }
  }
}
