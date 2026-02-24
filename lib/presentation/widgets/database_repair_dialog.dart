import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/constants.dart';
import '../../data/services/sync/sync_metadata.dart';
import '../providers/sync_provider.dart';

/// ============================================================
/// 数据库修复弹窗
/// ============================================================
/// 当检测到本地数据库损坏时，弹出此弹窗提供修复选项：
/// - 尝试自动修复（REINDEX + VACUUM）
/// - 从云端恢复（强制下载覆盖本地）
/// - 取消（忽略本次错误）

/// 显示数据库修复弹窗
///
/// 返回值：
/// - true: 修复成功或从云端恢复成功
/// - false: 用户取消或修复失败
Future<bool> showDatabaseRepairDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // 强制用户做出选择
    builder: (context) => DatabaseRepairDialog(ref: ref),
  );
  return result ?? false;
}

/// 数据库修复弹窗组件
class DatabaseRepairDialog extends StatefulWidget {
  final WidgetRef ref;

  const DatabaseRepairDialog({
    super.key,
    required this.ref,
  });

  @override
  State<DatabaseRepairDialog> createState() => _DatabaseRepairDialogState();
}

class _DatabaseRepairDialogState extends State<DatabaseRepairDialog> {
  /// 是否正在修复中
  bool _isRepairing = false;

  /// 修复进度信息
  String _progressMessage = '';

  /// 尝试修复数据库
  Future<void> _attemptRepair() async {
    setState(() {
      _isRepairing = true;
      _progressMessage = '正在尝试修复数据库...';
    });

    final result =
        await widget.ref.read(syncStateProvider.notifier).repairDatabase();

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _progressMessage = '✅ ${result.message}';
      });

      // 显示成功消息后关闭弹窗
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _isRepairing = false;
        _progressMessage = '❌ ${result.message}';
      });
    }
  }

  /// 从云端恢复（强制下载）
  Future<void> _restoreFromCloud() async {
    setState(() {
      _isRepairing = true;
      _progressMessage = '正在从云端恢复数据...';
    });

    final success = await widget.ref.read(syncStateProvider.notifier).manualSync(
          forceDownload: true,
        );

    if (!mounted) return;

    if (success) {
      setState(() {
        _progressMessage = '✅ 已从云端恢复数据';
      });

      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _isRepairing = false;
        _progressMessage = '❌ 云端恢复失败';
      });
    }
  }

  /// 取消修复
  void _cancel() {
    widget.ref.read(syncStateProvider.notifier).clearDatabaseCorruptedState();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade700,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Text('数据库损坏'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '检测到本地数据库文件损坏，这可能导致数据丢失或同步失败。',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AmberColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AmberColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '建议操作：',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildOptionItem(
                    '1. 尝试自动修复',
                    '使用 REINDEX 和 VACUUM 命令修复索引',
                  ),
                  const SizedBox(height: 4),
                  _buildOptionItem(
                    '2. 从云端恢复',
                    '如果云端数据是最新的，可以覆盖本地数据',
                  ),
                ],
              ),
            ),
            if (_progressMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _progressMessage.startsWith('✅')
                      ? Colors.green.withValues(alpha: 0.1)
                      : _progressMessage.startsWith('❌')
                          ? Colors.red.withValues(alpha: 0.1)
                          : AmberColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (_isRepairing && !_progressMessage.startsWith('✅'))
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AmberColors.primary,
                        ),
                      ),
                    if (_isRepairing && !_progressMessage.startsWith('✅'))
                      const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _progressMessage,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: _isRepairing
          ? null // 修复中不显示按钮
          : [
              TextButton(
                onPressed: _cancel,
                child: const Text(
                  '稍后处理',
                  style: TextStyle(color: AmberColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: _restoreFromCloud,
                child: const Text('从云端恢复'),
              ),
              ElevatedButton(
                onPressed: _attemptRepair,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AmberColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('尝试修复'),
              ),
            ],
    );
  }

  /// 构建选项说明项
  Widget _buildOptionItem(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(fontSize: 13)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: AmberColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
