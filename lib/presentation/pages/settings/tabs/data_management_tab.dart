import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/constants.dart';
import '../../../../data/services/export_service.dart';
import '../../../../data/services/sync/sync_metadata.dart';
import '../../../providers/database_provider.dart';
import '../../../widgets/common/toast/toast_manager.dart';
import '../../../widgets/common/toast/toast_types.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';

/// 数据管理标签页
class DataManagementTab extends ConsumerWidget {
  const DataManagementTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AmberDimens.spacingLg),
      children: [
        SettingsSection(
          title: 'SQLite 数据库',
          children: [
            SettingsTile(
              icon: Icons.file_download_outlined,
              title: '导出数据库',
              subtitle: '将所有数据导出为SQLite数据库文件',
              onTap: () => _exportDatabase(context, ref),
            ),
            SettingsTile(
              icon: Icons.file_upload_outlined,
              title: '导入数据库',
              subtitle: '从SQLite数据库文件恢复数据',
              onTap: () => _importDatabase(context, ref),
            ),
          ],
        ),
        const SizedBox(height: AmberDimens.spacingLg),
        SettingsSection(
          title: 'JSON 数据',
          children: [
            SettingsTile(
              icon: Icons.code,
              title: '导出为JSON',
              subtitle: '将数据导出为可读的JSON格式',
              onTap: () => _exportJson(context, ref),
            ),
            SettingsTile(
              icon: Icons.upload_file,
              title: '从JSON导入',
              subtitle: '从JSON文件导入数据',
              onTap: () => _importJson(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  // ===== 导出导入逻辑 =====

  /// 导出数据库
  Future<void> _exportDatabase(BuildContext context, WidgetRef ref) async {
    // 先执行 checkpoint 确保 WAL 数据写入主数据库文件
    try {
      final db = ref.read(databaseProvider);
      await db.checkpoint();
    } catch (e) {
      // checkpoint 失败不影响导出，继续执行
      debugPrint('Checkpoint 警告: $e');
    }

    final result = await ExportService.exportDatabase();
    if (context.mounted) {
      ToastManager().show(
        context,
        result != null ? '导出成功：$result' : '导出失败或取消',
        type: result != null ? ToastType.success : ToastType.warning,
      );
    }
  }

  /// 导入数据库
  Future<void> _importDatabase(BuildContext context, WidgetRef ref) async {
    // 确认对话框
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('导入数据库'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('导入将覆盖现有数据。'),
            SizedBox(height: 8),
            Text(
              '• 当前数据会自动备份\n• 导入后需要重启应用',
              style: TextStyle(fontSize: 13, color: AmberColors.textSecondary),
            ),
            SizedBox(height: 12),
            Text(
              '确定要继续吗？',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AmberColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确定导入'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    // 显示加载指示器
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在导入数据库...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // 1. 先执行 checkpoint 确保当前数据完整
      final db = ref.read(databaseProvider);
      await db.checkpoint();

      // 2. 关闭数据库连接
      await db.close();

      // 3. 执行导入
      final result = await ExportService.importDatabase();

      // 关闭加载指示器
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (!context.mounted) return;

      if (result.cancelled) {
        // 用户取消，重新打开数据库（通过 invalidate provider）
        ref.invalidate(databaseProvider);
        return;
      }

      if (result.success) {
        // 清除本地同步状态，下次同步时会触发"首次同步"流程
        // 让用户选择是从云端恢复还是上传到云端
        await SyncStateService.clearState();

        // 显示成功对话框，提示重启
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('导入成功'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('数据库已导入成功！'),
                if (result.backupPath != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '原数据已备份到：\n${result.backupPath}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AmberColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  '请立即重启应用以加载新数据。',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AmberColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  // 退出应用
                  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
                    exit(0);
                  } else {
                    SystemNavigator.pop();
                  }
                },
                child: const Text('立即重启'),
              ),
            ],
          ),
        );
      } else {
        // 导入失败，重新打开数据库
        ref.invalidate(databaseProvider);
        ToastManager().show(
          context,
          result.errorMessage ?? '导入失败',
          type: ToastType.error,
        );
      }
    } catch (e) {
      // 关闭加载指示器
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // 尝试恢复数据库连接
      ref.invalidate(databaseProvider);

      if (context.mounted) {
        ToastManager().show(
          context,
          '导入失败: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
    ToastManager().show(
      context,
      '功能正在开发中',
      type: ToastType.error,
      position: ToastPosition.top,
    );
  }

  Future<void> _importJson(BuildContext context, WidgetRef ref) async {
    ToastManager().show(
      context,
      '功能正在开发中',
      type: ToastType.error,
      position: ToastPosition.top,
    );
  }
}
