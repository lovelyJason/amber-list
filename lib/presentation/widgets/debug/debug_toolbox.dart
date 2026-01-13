import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/constants.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/services/splash_service.dart';
import '../../../data/datasources/local/database.dart' show AppDatabase;
import '../../providers/providers.dart';
import '../common/toast/toast_manager.dart';
import 'prefs_editor.dart';
import 'sticky_note_debugger.dart';

/// ============================================================
/// 调试工具箱弹窗
/// ============================================================
/// Debug 模式下可用的调试工具集合，包含：
/// - 便签注册表监控
/// - SharedPreferences 编辑器
/// - Splash 屏幕预览
/// - 恢复出厂设置
/// - 激活码生成器
/// - 重置自动顺延检查状态
///
/// 使用方式：showDebugToolbox(context, ref)
/// ============================================================

/// 显示调试工具箱弹窗
void showDebugToolbox(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (context) => _DebugToolboxDialog(ref: ref),
  );
}

/// 调试工具箱弹窗 Widget
class _DebugToolboxDialog extends StatelessWidget {
  final WidgetRef ref;

  const _DebugToolboxDialog({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 320,
        // 最大高度限制，超出部分滚动
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏（固定不滚动）
            _buildHeader(context),
            const SizedBox(height: 24),
            // 选项列表（可滚动）
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 便签注册表监控
                    _buildDebugOption(
                      context,
                      icon: Icons.sticky_note_2_rounded,
                      label: '便签注册表监控',
                      description: '查看便签窗口状态与进程',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (context) => const Dialog(
                            backgroundColor: Colors.transparent,
                            child: StickyNoteDebugger(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // SharedPreferences 编辑器
                    _buildDebugOption(
                      context,
                      icon: Icons.settings_applications_rounded,
                      label: 'SharedPreferences Editor',
                      description: '查看和修改本地配置 (Prefs)',
                      color: Colors.blueGrey,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PrefsEditor()),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // Splash 屏幕预览
                    _buildDebugOption(
                      context,
                      icon: Icons.screen_lock_portrait_rounded,
                      label: 'Splash 屏幕预览',
                      description: '显示启动 Splash 屏幕 3 秒',
                      color: Colors.amber,
                      onTap: () async {
                        Navigator.pop(context);
                        await SplashService.showSplash(duration: 3000);
                      },
                    ),
                    const SizedBox(height: 12),
                    // 恢复出厂设置
                    _buildDebugOption(
                      context,
                      icon: Icons.restore_page,
                      label: '恢复出厂设置',
                      description: '清空所有数据、配置，恢复初始安装状态',
                      color: Colors.red,
                      onTap: () => _showFactoryResetConfirm(context),
                    ),
                    const SizedBox(height: 12),
                    // 激活码生成器
                    _buildDebugOption(
                      context,
                      icon: Icons.vpn_key_rounded,
                      label: '生成激活码',
                      description: '生成应用激活码（仅生成）',
                      color: Colors.purple,
                      onTap: () {
                        Navigator.pop(context);
                        _showActivationCodeGenerator(context);
                      },
                    ),
                    const SizedBox(height: 12),
                    // 重置自动顺延检查状态
                    _buildAutoPostponeResetOption(context),
                    const SizedBox(height: 12),
                    // 测试系统通知
                    _buildDebugOption(
                      context,
                      icon: Icons.notifications_active_rounded,
                      label: '测试系统通知',
                      description: '发送一条测试通知（模拟积压提醒）',
                      color: Colors.blue,
                      onTap: () async {
                        Navigator.pop(context);
                        // 使用随机 ID 确保每次都能弹出新通知（仅测试用）
                        await NotificationService.instance.showTestNotification(
                          backlogCount: 3,
                          topTaskTitle: '测试任务标题 ${DateTime.now().second}s',
                        );
                        if (context.mounted) {
                          ToastManager().show(
                            context,
                            '已发送测试通知',
                            type: ToastType.success,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AmberColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.build_circle,
            color: AmberColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          '调试工具箱',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AmberColors.textPrimary,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.close,
            size: 20,
            color: AmberColors.textSecondary,
          ),
          style: IconButton.styleFrom(
            backgroundColor: AmberColors.sidebarBackground,
            padding: const EdgeInsets.all(8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  /// 构建调试选项卡片
  Widget _buildDebugOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AmberColors.divider),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AmberColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AmberColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AmberColors.textDisabled,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建"重置自动顺延检查状态"选项
  /// 使用 Consumer 动态读取当前检查日期
  Widget _buildAutoPostponeResetOption(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final settings = ref.watch(taskManagementSettingsProvider);
        final lastDate = settings.lastAutoPostponeDate;

        return _buildDebugOption(
          context,
          icon: Icons.update_disabled_rounded,
          label: '重置自动顺延检查',
          description: lastDate != null ? '上次检查: $lastDate' : '从未检查过',
          color: Colors.teal,
          onTap: () {
            ref
                .read(taskManagementSettingsProvider.notifier)
                .clearLastAutoPostponeDate();
            Navigator.pop(context);
            ToastManager().show(
              context,
              '已重置，重启 App 后将重新执行自动顺延检查',
              type: ToastType.success,
            );
          },
        );
      },
    );
  }

  /// 显示恢复出厂设置确认弹窗
  Future<void> _showFactoryResetConfirm(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ 恢复出厂设置'),
        content: const Text(
          '此操作将清除所有数据和设置：\n\n'
          '• 所有任务、笔记、番茄钟记录\n'
          '• 所有设置和偏好配置\n'
          '• 云同步配置和登录状态\n'
          '• 激活状态\n\n'
          '应用将恢复到首次安装时的状态。\n'
          '此操作无法撤销！',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确认重置'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      Navigator.pop(context); // 关闭工具箱弹窗
      await _performFactoryReset(context);
    }
  }

  /// 执行出厂重置
  ///
  /// 清除所有本地数据和配置，恢复到首次安装状态：
  /// 1. 关闭数据库连接
  /// 2. 删除数据库文件（包括 WAL 和 SHM）
  /// 3. 清除 SharedPreferences（所有设置和配置）
  /// 4. 刷新所有 Provider，重新创建数据库
  Future<void> _performFactoryReset(BuildContext context) async {
    try {
      // 1. 关闭数据库连接
      await ref.read(databaseProvider).close();

      // 2. 删除数据库文件（包括 WAL 和 SHM 文件）
      final dbPath = await AppDatabase.getDatabasePath();
      final dbFile = File(dbPath);
      final walFile = File('$dbPath-wal');
      final shmFile = File('$dbPath-shm');

      if (await dbFile.exists()) {
        await dbFile.delete();
        debugPrint('[FactoryReset] 已删除数据库文件: $dbPath');
      }
      if (await walFile.exists()) {
        await walFile.delete();
        debugPrint('[FactoryReset] 已删除 WAL 文件');
      }
      if (await shmFile.exists()) {
        await shmFile.delete();
        debugPrint('[FactoryReset] 已删除 SHM 文件');
      }

      // 3. 清除所有 SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('[FactoryReset] 已清除 SharedPreferences');

      // 4. 刷新关键 Provider，让它们重新从空状态开始
      ref.invalidate(databaseProvider);
      ref.invalidate(taskProvider);
      ref.invalidate(tagsProvider);
      ref.invalidate(syncTypeProvider);
      ref.invalidate(syncConfigProvider);
      ref.invalidate(activationProvider);
      ref.invalidate(displaySettingsProvider);
      ref.invalidate(userProfileProvider);

      if (context.mounted) {
        ToastManager().show(
          context,
          '已恢复出厂设置，请重启应用',
          type: ToastType.success,
          position: ToastPosition.top,
        );
      }
    } catch (e) {
      debugPrint('[FactoryReset] 重置失败: $e');
      if (context.mounted) {
        ToastManager().show(
          context,
          '重置失败: $e',
          type: ToastType.error,
          position: ToastPosition.top,
        );
      }
    }
  }

  /// 显示激活码生成器弹窗
  void _showActivationCodeGenerator(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _ActivationCodeGeneratorDialog(),
    );
  }
}

/// 激活码生成器弹窗
class _ActivationCodeGeneratorDialog extends StatefulWidget {
  const _ActivationCodeGeneratorDialog();

  @override
  State<_ActivationCodeGeneratorDialog> createState() =>
      _ActivationCodeGeneratorDialogState();
}

class _ActivationCodeGeneratorDialogState
    extends State<_ActivationCodeGeneratorDialog> {
  late String _code;

  @override
  void initState() {
    super.initState();
    _code = _generateActivationCode();
  }

  /// 生成激活码
  /// 格式：AMBER-XXXXX-XXXXX-XXXXX（琥珀前缀 + 15位随机码）
  String _generateActivationCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // 去掉容易混淆的字符 I/1, O/0
    final random = DateTime.now().millisecondsSinceEpoch;
    final buffer = StringBuffer('AMBER-');

    for (var i = 0; i < 3; i++) {
      if (i > 0) buffer.write('-');
      for (var j = 0; j < 5; j++) {
        final index = (random ~/ (i * 5 + j + 1) +
                DateTime.now().microsecondsSinceEpoch +
                i * j) %
            chars.length;
        buffer.write(chars[index]);
      }
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头部图标
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade400, Colors.purple.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.vpn_key_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '激活码生成器',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AmberColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击刷新按钮生成新的激活码',
              style: TextStyle(
                fontSize: 13,
                color: AmberColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            // 激活码展示区
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.purple.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: SelectableText(
                _code,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  fontFamily: 'monospace',
                  color: Colors.purple.shade700,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 操作按钮
            Row(
              children: [
                // 刷新按钮
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _code = _generateActivationCode();
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('刷新'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      side: BorderSide(color: Colors.purple.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 复制按钮
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _code));
                      ToastManager().show(
                        context,
                        '激活码已复制',
                        type: ToastType.success,
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('复制'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 关闭按钮
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
