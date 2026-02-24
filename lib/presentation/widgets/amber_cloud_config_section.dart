import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/constants.dart';
import '../../data/repositories/amber_cloud_repository.dart';
import '../../data/services/activation/activation_service.dart';
import '../../data/services/sync/sync_config.dart';
import '../providers/providers.dart';
import 'common/toast/toast_manager.dart';
import 'database_repair_dialog.dart';

/// ============================================================
/// 琥珀云配置组件
/// ============================================================
/// 琥珀云托管服务的配置入口，特点：
/// - 无需用户输入服务器地址、密钥
/// - 自动使用已激活的激活码进行认证
/// - 一键启用/禁用
///
/// 前提条件：用户必须已激活 App（有有效的激活码）
/// ============================================================

/// 琥珀云配置状态
enum AmberCloudStatus {
  /// 未激活（需要先激活 App）
  notActivated,

  /// 已激活但未配置（可以启用）
  ready,

  /// 已配置且已登录
  connected,

  /// Token 已过期（需要重新登录）
  expired,

  /// 连接中/测试中
  connecting,
}

class AmberCloudConfigSection extends ConsumerStatefulWidget {
  const AmberCloudConfigSection({super.key});

  @override
  ConsumerState<AmberCloudConfigSection> createState() =>
      _AmberCloudConfigSectionState();
}

class _AmberCloudConfigSectionState
    extends ConsumerState<AmberCloudConfigSection> {
  AmberCloudStatus _status = AmberCloudStatus.notActivated;
  bool _isLoading = false;
  String? _activationCode;
  final AmberCloudRepository _repository = AmberCloudRepository();

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  /// 检查当前状态
  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);

    try {
      // 1. 检查是否已激活
      final code = await ActivationService.getActivationCode();
      if (code == null || code.isEmpty) {
        // 未激活：如果当前同步类型是琥珀云，自动切回"不同步"
        await _resetSyncTypeIfAmberCloud();
        setState(() {
          _status = AmberCloudStatus.notActivated;
          _isLoading = false;
        });
        return;
      }

      _activationCode = code;

      // 2. 检查是否已登录琥珀云
      final isLoggedIn = await _repository.isLoggedIn();
      if (isLoggedIn) {
        setState(() {
          _status = AmberCloudStatus.connected;
          _isLoading = false;
        });
      } else {
        // 未登录：如果当前同步类型是琥珀云，自动切回"不同步"
        await _resetSyncTypeIfAmberCloud();
        setState(() {
          _status = AmberCloudStatus.ready;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[AmberCloudConfig] 检查状态失败: $e');
      // 异常：如果当前同步类型是琥珀云，自动切回"不同步"
      await _resetSyncTypeIfAmberCloud();
      setState(() {
        _status = AmberCloudStatus.notActivated;
        _isLoading = false;
      });
    }
  }

  /// 如果当前同步类型是琥珀云，自动切回"不同步"
  Future<void> _resetSyncTypeIfAmberCloud() async {
    final currentSyncType = ref.read(syncTypeProvider);
    if (currentSyncType == SyncType.amberCloud) {
      debugPrint('[AmberCloudConfig] 激活码失效，自动切换到"不同步"');
      await ref.read(syncStateProvider.notifier).switchSyncType(null);
    }
  }

  /// 启用琥珀云同步
  Future<void> _enableAmberCloud() async {
    if (_activationCode == null) {
      ToastManager().show(context, '请先激活 App', type: ToastType.error);
      return;
    }

    setState(() {
      _status = AmberCloudStatus.connecting;
      _isLoading = true;
    });

    try {
      // 使用激活码获取 Token
      final result = await _repository.getToken(_activationCode!);

      if (result.success) {
        // 切换同步类型到琥珀云
        await ref
            .read(syncStateProvider.notifier)
            .enableAmberCloud();

        setState(() {
          _status = AmberCloudStatus.connected;
          _isLoading = false;
        });

        if (mounted) {
          ToastManager().show(
            context,
            '琥珀云同步已启用',
            type: ToastType.success,
          );
        }
      } else {
        setState(() {
          _status = AmberCloudStatus.ready;
          _isLoading = false;
        });

        if (mounted) {
          ToastManager().show(
            context,
            result.message ?? '启用失败',
            type: ToastType.error,
          );
        }
      }
    } catch (e) {
      debugPrint('[AmberCloudConfig] 启用失败: $e');
      setState(() {
        _status = AmberCloudStatus.ready;
        _isLoading = false;
      });

      if (mounted) {
        ToastManager().show(context, '启用失败: $e', type: ToastType.error);
      }
    }
  }

  /// 禁用琥珀云同步
  Future<void> _disableAmberCloud() async {
    setState(() => _isLoading = true);

    try {
      // 清除 Token
      await _repository.clearToken();

      // 切换到"不同步"
      await ref.read(syncStateProvider.notifier).switchSyncType(null);

      setState(() {
        _status = AmberCloudStatus.ready;
        _isLoading = false;
      });

      if (mounted) {
        ToastManager().show(context, '琥珀云同步已禁用', type: ToastType.success);
      }
    } catch (e) {
      debugPrint('[AmberCloudConfig] 禁用失败: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ToastManager().show(context, '禁用失败: $e', type: ToastType.error);
      }
    }
  }

  /// 测试连接
  Future<void> _testConnection() async {
    setState(() => _isLoading = true);

    try {
      final result = await _repository.testConnection();

      if (mounted) {
        if (result.success) {
          ToastManager().show(context, '连接正常', type: ToastType.success);
        } else {
          ToastManager().show(
            context,
            result.message ?? '连接失败',
            type: ToastType.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ToastManager().show(context, '测试失败: $e', type: ToastType.error);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 手动同步（双向同步）
  Future<void> _manualSync() async {
    setState(() => _isLoading = true);

    try {
      final success = await ref.read(syncStateProvider.notifier).manualSync();

      if (mounted) {
        if (success) {
          ref.read(soundServiceProvider).playSuccess();
          ToastManager().show(context, '同步完成', type: ToastType.success);
        } else {
          // 读取实际错误信息
          final syncState = ref.read(syncStateProvider);

          // 检测到数据库损坏，弹出修复弹窗
          if (syncState.isDatabaseCorrupted) {
            final repaired = await showDatabaseRepairDialog(context, ref);
            if (repaired && mounted) {
              ToastManager().show(context, '数据库已修复', type: ToastType.success);
            }
          } else {
            final errorMsg = syncState.lastError ?? '同步失败';
            ToastManager().show(context, errorMsg, type: ToastType.error);
          }
        }
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 强制从云端恢复数据
  /// 会先弹窗确认，因为这会覆盖本地数据
  Future<void> _forceDownloadFromCloud() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('从云端恢复'),
        content: const Text(
          '⚠️ 此操作会用云端数据完全覆盖本地数据！\n\n'
          '适用场景：\n'
          '• 本地数据被误删或损坏\n'
          '• 换设备后想恢复数据\n'
          '• 本地显示"已是最新"但数据不对\n\n'
          '确定要继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('确认恢复'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final success = await ref.read(syncStateProvider.notifier).manualSync(
        forceDownload: true,
      );

      if (mounted) {
        if (success) {
          ref.read(soundServiceProvider).playSuccess();
          ToastManager().show(context, '已从云端恢复数据', type: ToastType.success);
        } else {
          // 读取实际错误信息
          final syncState = ref.read(syncStateProvider);
          final errorMsg = syncState.lastError ?? '恢复失败';
          ToastManager().show(context, errorMsg, type: ToastType.error);
        }
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AmberDimens.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          _buildHeader(),
          const SizedBox(height: AmberDimens.spacingMd),

          // 状态展示
          _buildStatusCard(),

          // 操作按钮
          if (_status != AmberCloudStatus.notActivated) ...[
            const SizedBox(height: AmberDimens.spacingMd),
            _buildActions(),
          ],
        ],
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AmberDimens.spacingSm),
          decoration: BoxDecoration(
            color: AmberColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AmberDimens.radiusSm),
          ),
          child: const Icon(
            Icons.cloud_outlined,
            color: AmberColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: AmberDimens.spacingSm),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '琥珀云托管',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '官方托管服务，无需配置，开箱即用',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建状态卡片
  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(AmberDimens.spacingMd),
      decoration: BoxDecoration(
        color: _getStatusBackgroundColor(),
        borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
        border: Border.all(color: _getStatusBorderColor()),
      ),
      child: Row(
        children: [
          _buildStatusIcon(),
          const SizedBox(width: AmberDimens.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusTitle(),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: _getStatusTextColor(),
                  ),
                ),
                Text(
                  _getStatusSubtitle(),
                  style: TextStyle(
                    fontSize: 12,
                    color: _getStatusTextColor().withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActions() {
    if (_status == AmberCloudStatus.connected) {
      return Column(
        children: [
          // 第一行：同步和从云端恢复
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _manualSync,
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('同步'),
                ),
              ),
              const SizedBox(width: AmberDimens.spacingSm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _forceDownloadFromCloud,
                  icon: const Icon(Icons.cloud_download_outlined, size: 18),
                  label: const Text('从云端恢复'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AmberDimens.spacingSm),
          // 第二行：测试连接和禁用
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _testConnection,
                  icon: const Icon(Icons.wifi_tethering, size: 18),
                  label: const Text('测试连接'),
                ),
              ),
              const SizedBox(width: AmberDimens.spacingSm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _disableAmberCloud,
                  icon: const Icon(Icons.cloud_off_outlined, size: 18),
                  label: const Text('禁用'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (_status == AmberCloudStatus.ready ||
        _status == AmberCloudStatus.expired) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _enableAmberCloud,
          icon: const Icon(Icons.cloud_done_outlined, size: 18),
          label: Text(_status == AmberCloudStatus.expired ? '重新登录' : '启用琥珀云'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AmberColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    // 未激活状态
    return Container(
      padding: const EdgeInsets.all(AmberDimens.spacingSm),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AmberDimens.radiusSm),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange, size: 18),
          SizedBox(width: AmberDimens.spacingSm),
          Expanded(
            child: Text(
              '请先在「关于」页面激活 App',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (_status) {
      case AmberCloudStatus.notActivated:
        return const Icon(Icons.lock_outline, color: Colors.grey);
      case AmberCloudStatus.ready:
        return const Icon(Icons.cloud_queue_outlined, color: Colors.blue);
      case AmberCloudStatus.connected:
        return const Icon(Icons.cloud_done_outlined, color: AmberColors.success);
      case AmberCloudStatus.expired:
        return const Icon(Icons.cloud_off_outlined, color: Colors.orange);
      case AmberCloudStatus.connecting:
        return const Icon(Icons.cloud_sync_outlined, color: Colors.blue);
    }
  }

  String _getStatusTitle() {
    switch (_status) {
      case AmberCloudStatus.notActivated:
        return '未激活';
      case AmberCloudStatus.ready:
        return '准备就绪';
      case AmberCloudStatus.connected:
        return '已连接';
      case AmberCloudStatus.expired:
        return 'Token 已过期';
      case AmberCloudStatus.connecting:
        return '连接中...';
    }
  }

  String _getStatusSubtitle() {
    switch (_status) {
      case AmberCloudStatus.notActivated:
        return '需要先激活 App 才能使用琥珀云';
      case AmberCloudStatus.ready:
        return '点击启用开始使用琥珀云同步';
      case AmberCloudStatus.connected:
        return '数据将自动同步到琥珀云';
      case AmberCloudStatus.expired:
        return '请重新登录以恢复同步';
      case AmberCloudStatus.connecting:
        return '正在连接琥珀云服务器...';
    }
  }

  Color _getStatusBackgroundColor() {
    switch (_status) {
      case AmberCloudStatus.notActivated:
        return Colors.grey.withValues(alpha: 0.1);
      case AmberCloudStatus.ready:
        return Colors.blue.withValues(alpha: 0.1);
      case AmberCloudStatus.connected:
        return AmberColors.success.withValues(alpha: 0.1);
      case AmberCloudStatus.expired:
        return Colors.orange.withValues(alpha: 0.1);
      case AmberCloudStatus.connecting:
        return Colors.blue.withValues(alpha: 0.1);
    }
  }

  Color _getStatusBorderColor() {
    switch (_status) {
      case AmberCloudStatus.notActivated:
        return Colors.grey.withValues(alpha: 0.3);
      case AmberCloudStatus.ready:
        return Colors.blue.withValues(alpha: 0.3);
      case AmberCloudStatus.connected:
        return AmberColors.success.withValues(alpha: 0.3);
      case AmberCloudStatus.expired:
        return Colors.orange.withValues(alpha: 0.3);
      case AmberCloudStatus.connecting:
        return Colors.blue.withValues(alpha: 0.3);
    }
  }

  Color _getStatusTextColor() {
    switch (_status) {
      case AmberCloudStatus.notActivated:
        return Colors.grey;
      case AmberCloudStatus.ready:
        return Colors.blue;
      case AmberCloudStatus.connected:
        return AmberColors.success;
      case AmberCloudStatus.expired:
        return Colors.orange;
      case AmberCloudStatus.connecting:
        return Colors.blue;
    }
  }
}
