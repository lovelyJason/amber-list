import 'package:flutter/material.dart';
import '../../core/constants/constants.dart';
import '../../data/models/models.dart';

/// ============================================================
/// 同步冲突解决对话框
/// ============================================================
/// 当任务/笔记发生冲突时,弹窗让用户选择保留哪个版本:
/// - 本地版本
/// - 云端版本
/// - 合并(保留两者)

enum ConflictResolution {
  keepLocal,  // 保留本地版本
  keepRemote, // 保留云端版本
  keepBoth,   // 保留两者(创建副本)
}

class ConflictDialog extends StatelessWidget {
  final String itemType; // "任务" 或 "笔记"
  final dynamic localItem;
  final dynamic remoteItem;

  const ConflictDialog({
    super.key,
    required this.itemType,
    required this.localItem,
    required this.remoteItem,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_amber_outlined, color: AmberColors.warning),
          const SizedBox(width: 8),
          Text('$itemType冲突'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '本地和云端的$itemType发生了冲突,请选择保留哪个版本:',
              style: const TextStyle(fontSize: 14, color: AmberColors.textSecondary),
            ),
            const SizedBox(height: AmberDimens.spacingLg),

            // 本地版本预览
            _buildVersionCard(
              title: '📱 本地版本',
              item: localItem,
              backgroundColor: AmberColors.primaryLight,
            ),

            const SizedBox(height: AmberDimens.spacingMd),

            // 云端版本预览
            _buildVersionCard(
              title: '☁️ 云端版本',
              item: remoteItem,
              backgroundColor: Colors.blue.shade50,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ConflictResolution.keepLocal),
          child: const Text('保留本地'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, ConflictResolution.keepRemote),
          child: const Text('保留云端'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, ConflictResolution.keepBoth),
          style: ElevatedButton.styleFrom(
            backgroundColor: AmberColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('保留两者'),
        ),
      ],
    );
  }

  /// 构建版本卡片
  Widget _buildVersionCard({
    required String title,
    required dynamic item,
    required Color backgroundColor,
  }) {
    String content;
    String updateTime;

    if (item is Task) {
      content = item.title;
      updateTime = _formatDateTime(item.updatedAt);
    } else if (item is Note) {
      content = item.title;
      updateTime = _formatDateTime(item.updatedAt);
    } else {
      content = '未知项目';
      updateTime = '未知时间';
    }

    return Container(
      padding: const EdgeInsets.all(AmberDimens.spacingMd),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
        border: Border.all(color: AmberColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            '更新时间: $updateTime',
            style: const TextStyle(
              fontSize: 11,
              color: AmberColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// 显示冲突对话框的快捷方法
Future<ConflictResolution?> showConflictDialog(
  BuildContext context, {
  required String itemType,
  required dynamic localItem,
  required dynamic remoteItem,
}) {
  return showDialog<ConflictResolution>(
    context: context,
    barrierDismissible: false, // 必须选择一个选项
    builder: (context) => ConflictDialog(
      itemType: itemType,
      localItem: localItem,
      remoteItem: remoteItem,
    ),
  );
}
