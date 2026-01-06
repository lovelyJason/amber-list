import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/constants.dart';
import '../../../../data/services/export_service.dart';
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
              onTap: () => _exportDatabase(context),
            ),
            SettingsTile(
              icon: Icons.file_upload_outlined,
              title: '导入数据库',
              subtitle: '从SQLite数据库文件恢复数据',
              onTap: () => _importDatabase(context),
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

  // ===== 导出导入逻辑（从原SettingsContent迁移） =====

  Future<void> _exportDatabase(BuildContext context) async {
    final result = await ExportService.exportDatabase();
    if (context.mounted) {
      ToastManager().show(
        context,
        result != null ? '导出成功：$result' : '导出失败或取消',
        type: result != null ? ToastType.success : ToastType.warning,
      );
    }
  }

  Future<void> _importDatabase(BuildContext context) async {
    // 确认对话框
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('导入数据库'),
        content: const Text('导入将覆盖现有数据，当前数据会自动备份。确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确定导入'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await ExportService.importDatabase();
    if (context.mounted) {
      ToastManager().show(
        context,
        result ? '导入成功，请重启应用' : '导入失败或取消',
        type: result ? ToastType.success : ToastType.warning,
      );
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
