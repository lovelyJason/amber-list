import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../providers/providers.dart';
import '../../data/services/sync/sync_config.dart';
import '../../data/services/sync/providers/oss/qiniu_oss_client.dart';
import 'common/toast/toast_manager.dart';
import 'sync_conflict_dialog.dart';

/// ============================================================
/// 七牛云 OSS 配置组件
/// ============================================================
/// 内嵌在设置页面的七牛云配置区域，支持：
/// - AK/SK/Bucket/Region 配置
/// - 连接测试
/// - 手动同步触发
/// - 同步状态显示
/// ============================================================

class QiniuOssConfigSection extends ConsumerStatefulWidget {
  const QiniuOssConfigSection({super.key});

  @override
  ConsumerState<QiniuOssConfigSection> createState() => _QiniuOssConfigSectionState();
}

class _QiniuOssConfigSectionState extends ConsumerState<QiniuOssConfigSection> {
  final _formKey = GlobalKey<FormState>();
  final _accessKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final _bucketController = TextEditingController();
  final _customDomainController = TextEditingController();

  bool _isExpanded = false;
  bool _isTesting = false;
  bool _hasSecretKeyInKeychain = false;
  String? _originalSecretKeyPlaceholder;
  QiniuRegion _selectedRegion = QiniuRegion.z0;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  /// 加载现有配置
  void _loadConfig() async {
    final config = ref.read(qiniuConfigProvider);
    if (config != null && config.isConfigured) {
      _accessKeyController.text = config.accessKey;
      _bucketController.text = config.bucket;
      _selectedRegion = config.region;
      _customDomainController.text = config.customDomain ?? '';

      // SecretKey 从系统钥匙串加载（如果有则显示占位符）
      final secretKey = await SyncConfigService.getQiniuSecretKey(config.accessKey);
      if (secretKey != null) {
        print('[QiniuConfig] ✅ 从钥匙串读取到 SecretKey');
        _hasSecretKeyInKeychain = true;
        _originalSecretKeyPlaceholder = '••••••••••••••••';
        _secretKeyController.text = _originalSecretKeyPlaceholder!;
      } else {
        print('[QiniuConfig] ⚠️ 钥匙串中没有找到 SecretKey');
        _hasSecretKeyInKeychain = false;
      }

      if (mounted) {
        setState(() {
          _isExpanded = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _accessKeyController.dispose();
    _secretKeyController.dispose();
    _bucketController.dispose();
    _customDomainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncStateProvider);
    final syncType = ref.watch(syncTypeProvider);
    final qiniuConfig = ref.watch(qiniuConfigProvider);

    // isConfigured: 是否已配置（有账密信息）
    final isConfigured = qiniuConfig != null && qiniuConfig.isConfigured;
    // isActive: 当前是否激活七牛云同步
    final isActive = syncType == SyncType.qiniuOss;
    final showSyncing = isActive && syncState.isSyncing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏 - 显示同步状态
        ListTile(
          leading: Icon(
            isConfigured ? Icons.cloud_done_outlined : Icons.cloud_outlined,
            color: AmberColors.primary,
          ),
          title: const Text('七牛云 OSS 同步'),
          subtitle: _buildStatusSubtitle(syncState, isConfigured, isActive),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 同步菜单按钮（只在当前激活时显示）
              if (isConfigured && isActive)
                showSyncing
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : PopupMenuButton<String>(
                        icon: const Icon(Icons.sync),
                        tooltip: '同步选项',
                        onSelected: (value) {
                          if (value == 'sync') {
                            _manualSync();
                          } else if (value == 'force_download') {
                            _forceDownloadFromCloud();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'sync',
                            child: ListTile(
                              leading: Icon(Icons.sync),
                              title: Text('同步'),
                              subtitle: Text('双向同步本地和云端数据'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'force_download',
                            child: ListTile(
                              leading: Icon(Icons.cloud_download_outlined),
                              title: Text('从云端恢复'),
                              subtitle: Text('用云端数据覆盖本地'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
              // 展开/收起按钮
              GestureDetector(
                onTap: () {
                  setState(() => _isExpanded = !_isExpanded);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 配置表单 - 可展开/收起
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.all(AmberDimens.spacingMd),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Access Key
                  TextFormField(
                    controller: _accessKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Access Key',
                      hintText: '七牛云 AK',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.key_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入 Access Key';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AmberDimens.spacingMd),

                  // Secret Key
                  TextFormField(
                    controller: _secretKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Secret Key',
                      hintText: '七牛云 SK（敏感信息，加密存储）',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入 Secret Key';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AmberDimens.spacingMd),

                  // Bucket
                  TextFormField(
                    controller: _bucketController,
                    decoration: const InputDecoration(
                      labelText: 'Bucket 名称',
                      hintText: '存储空间名称',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.storage_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入 Bucket 名称';
                      }
                      return null;
                    },
                  ),
                  // 私有空间安全提示
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AmberDimens.spacingXs,
                      left: AmberDimens.spacingXs,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.security_outlined,
                          size: 14,
                          color: AmberColors.warning,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '请确保 Bucket 为私有空间，公共空间会导致数据泄露',
                            style: TextStyle(
                              fontSize: 12,
                              color: AmberColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AmberDimens.spacingMd),

                  // 区域选择
                  DropdownButtonFormField<QiniuRegion>(
                    value: _selectedRegion,
                    decoration: const InputDecoration(
                      labelText: '存储区域',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    items: QiniuRegion.allRegions.map((region) {
                      return DropdownMenuItem(
                        value: region,
                        child: Text('${region.displayName} (${region.code})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedRegion = value);
                      }
                    },
                  ),
                  const SizedBox(height: AmberDimens.spacingMd),

                  // 自定义域名（可选）
                  TextFormField(
                    controller: _customDomainController,
                    decoration: const InputDecoration(
                      labelText: '自定义域名（可选）',
                      hintText: 'https://cdn.example.com',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.language_outlined),
                    ),
                  ),

                  // 七牛云注册链接
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () async {
                        const url = 'https://portal.qiniu.com/';
                        try {
                          if (Platform.isWindows) {
                            await Process.run('start', [url], runInShell: true);
                          } else if (Platform.isMacOS) {
                            await Process.run('open', [url]);
                          }
                        } catch (e) {
                          debugPrint('Could not launch $url: $e');
                        }
                      },
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text(
                        '打开七牛云控制台',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: AmberDimens.spacingLg),

                  // 操作按钮
                  Row(
                    children: [
                      // 测试连接
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isTesting ? null : _testConnection,
                          icon: _isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.wifi_tethering),
                          label: Text(_isTesting ? '测试中...' : '测试连接'),
                        ),
                      ),
                      const SizedBox(width: AmberDimens.spacingMd),
                      // 保存配置
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveConfig,
                          icon: const Icon(Icons.save),
                          label: const Text('保存配置'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AmberColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 删除配置按钮（仅在已配置时显示）
                  if (isConfigured) ...[
                    const SizedBox(height: AmberDimens.spacingMd),
                    TextButton.icon(
                      onPressed: _deleteConfig,
                      icon: const Icon(Icons.delete_outline, color: AmberColors.warning),
                      label: const Text(
                        '删除同步配置',
                        style: TextStyle(color: AmberColors.warning),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// 构建状态副标题
  /// [isActive] 当前是否激活七牛云同步（用于判断是否显示同步状态）
  Widget _buildStatusSubtitle(SyncState syncState, bool isConfigured, bool isActive) {
    if (!isConfigured) {
      return const Text('未配置 - 点击配置七牛云 OSS 同步');
    }

    // 未激活时，只显示"已配置（未激活）"
    if (!isActive) {
      return const Text(
        '已配置（未激活）',
        style: TextStyle(color: AmberColors.textSecondary),
      );
    }

    // 激活状态下，显示同步进度
    if (syncState.isSyncing) {
      return const Text('同步中...', style: TextStyle(color: AmberColors.info));
    }

    if (syncState.lastError != null) {
      return Text(
        '同步失败: ${syncState.lastError}',
        style: const TextStyle(color: AmberColors.warning),
      );
    }

    if (syncState.lastSyncTime != null) {
      final timeAgo = _formatTimeAgo(syncState.lastSyncTime!);
      return Text('上次同步: $timeAgo');
    }

    return const Text('已配置，等待同步');
  }

  /// 格式化时间为 "xx分钟前"
  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }

  /// 测试七牛云连接
  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isTesting = true);

    try {
      final testConfig = QiniuOssConfig(
        accessKey: _accessKeyController.text.trim(),
        bucket: _bucketController.text.trim(),
        regionCode: _selectedRegion.code,
        customDomain: _customDomainController.text.trim().isNotEmpty
            ? _customDomainController.text.trim()
            : null,
      );

      // 判断使用哪个 SecretKey 测试
      final currentSecretKey = _secretKeyController.text.trim();
      String? secretKeyToTest;

      if (_hasSecretKeyInKeychain && currentSecretKey == _originalSecretKeyPlaceholder) {
        // 使用钥匙串里的 SecretKey
        secretKeyToTest = await SyncConfigService.getQiniuSecretKey(testConfig.accessKey);
      } else {
        // 使用用户输入的 SecretKey
        secretKeyToTest = currentSecretKey;
      }

      if (secretKeyToTest == null || secretKeyToTest.isEmpty) {
        if (mounted) {
          ToastManager().show(
            context,
            '请输入 Secret Key',
            type: ToastType.error,
          );
        }
        return;
      }

      final success = await ref.read(syncStateProvider.notifier).testQiniuConnection(
        testConfig,
        secretKeyToTest,
      );

      if (mounted) {
        ToastManager().show(
          context,
          success ? '连接成功!' : '连接失败，请检查配置',
          type: success ? ToastType.success : ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  /// 保存配置并启用同步
  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    final config = QiniuOssConfig(
      accessKey: _accessKeyController.text.trim(),
      bucket: _bucketController.text.trim(),
      regionCode: _selectedRegion.code,
      customDomain: _customDomainController.text.trim().isNotEmpty
          ? _customDomainController.text.trim()
          : null,
      syncIntervalMinutes: 30,
      autoSync: true,
    );

    // 判断 SecretKey 是否被修改
    final currentSecretKey = _secretKeyController.text.trim();
    String? secretKeyToSave;

    if (_hasSecretKeyInKeychain && currentSecretKey == _originalSecretKeyPlaceholder) {
      // SecretKey 框没被修改（还是占位符），使用钥匙串里的旧 SecretKey
      secretKeyToSave = await SyncConfigService.getQiniuSecretKey(config.accessKey);
      print('[QiniuConfig] 使用钥匙串中的现有 SecretKey');
    } else {
      // SecretKey 框被修改了，使用新 SecretKey
      secretKeyToSave = currentSecretKey;
      print('[QiniuConfig] 使用用户输入的新 SecretKey');
    }

    if (secretKeyToSave == null || secretKeyToSave.isEmpty) {
      if (mounted) {
        ToastManager().show(
          context,
          '请输入 Secret Key',
          type: ToastType.error,
        );
      }
      return;
    }

    await ref.read(syncStateProvider.notifier).saveQiniuConfig(config, secretKeyToSave);

    if (mounted) {
      ToastManager().show(
        context,
        '配置已保存，自动同步已启用（每30分钟）',
        type: ToastType.success,
      );
    }
  }

  /// 手动触发同步
  Future<void> _manualSync() async {
    // 设置冲突决策回调（在同步过程中弹窗让用户选择）
    ref.read(syncStateProvider.notifier).onConflictDetected = (conflicts) async {
      if (!mounted) return null;
      // 弹出冲突决策弹窗
      return showSyncConflictDialog(context, conflicts: conflicts);
    };

    final success = await ref.read(syncStateProvider.notifier).manualSync();

    if (mounted) {
      if (success) {
        ref.read(soundServiceProvider).playSuccess();
      }
      ToastManager().show(
        context,
        success ? '同步完成' : '同步失败，请查看错误信息',
        type: success ? ToastType.success : ToastType.error,
      );
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AmberColors.warning,
            ),
            child: const Text('确认恢复'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await ref.read(syncStateProvider.notifier).manualSync(
      forceDownload: true,
    );

    if (mounted) {
      if (success) {
        ref.read(soundServiceProvider).playSuccess();
      }
      ToastManager().show(
        context,
        success ? '已从云端恢复数据' : '恢复失败，请查看错误信息',
        type: success ? ToastType.success : ToastType.error,
      );
    }
  }

  /// 删除同步配置
  Future<void> _deleteConfig() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除同步配置'),
        content: const Text('确定要删除七牛云 OSS 同步配置吗？\n删除后将停止自动同步，但本地数据不会丢失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AmberColors.warning,
              foregroundColor: Colors.white,
            ),
            child: const Text('确定删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(syncStateProvider.notifier).deleteQiniuConfig();
      _accessKeyController.clear();
      _secretKeyController.clear();
      _bucketController.clear();
      _customDomainController.clear();
      _hasSecretKeyInKeychain = false;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已删除同步配置'),
            backgroundColor: AmberColors.warning,
          ),
        );
      }
    }
  }
}
