import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../providers/providers.dart';
import '../../data/services/sync/sync_config.dart';
import 'common/toast/toast_manager.dart';
import 'common/dialogs/data_conflict_dialog.dart';
import 'dart:io';
import '../../core/utils/sound_service.dart';

/// ============================================================
/// WebDAV 配置组件
/// ============================================================
/// 内嵌在设置页面的 WebDAV 配置区域,支持:
/// - 服务器地址/用户名/密码配置
/// - 连接测试
/// - 手动同步触发
/// - 同步状态显示

class WebDavConfigSection extends ConsumerStatefulWidget {
  const WebDavConfigSection({super.key});

  @override
  ConsumerState<WebDavConfigSection> createState() => _WebDavConfigSectionState();
}

class _WebDavConfigSectionState extends ConsumerState<WebDavConfigSection> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isExpanded = false;
  bool _isTesting = false;
  bool _hasPasswordInKeychain = false; // 标记钥匙串里是否有密码
  String? _originalPasswordPlaceholder; // 原始密码占位符

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  /// 加载现有配置
  void _loadConfig() async {
    final config = ref.read(syncConfigProvider);
    if (config != null && config.isConfigured) {
      _serverController.text = config.serverUrl;
      _usernameController.text = config.username;
      // 密码从系统钥匙串加载(如果有则显示占位符)
      final password = await SyncConfigService.getPassword(config.username);
      if (password != null) {
        print('[WebDavConfig] ✅ 从钥匙串读取到密码，长度=${password.length}');
        _hasPasswordInKeychain = true;
        _originalPasswordPlaceholder = '••••••••'; // 显示8个圆点表示已保存密码
        _passwordController.text = _originalPasswordPlaceholder!;
      } else {
        print('[WebDavConfig] ⚠️ 钥匙串中没有找到密码');
        _hasPasswordInKeychain = false;
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
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncStateProvider);
    final isConfigured = ref.watch(syncConfigProvider) != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏 - 显示同步状态
        ListTile(
          leading: Icon(
            isConfigured ? Icons.cloud_done_outlined : Icons.cloud_outlined,
            color: AmberColors.primary,
          ),
          title: const Text('WebDAV 同步'),
          subtitle: _buildStatusSubtitle(syncState, isConfigured),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 手动同步按钮
              if (isConfigured)
                IconButton(
                  icon: syncState.isSyncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  tooltip: '手动同步',
                  onPressed: syncState.isSyncing ? null : _manualSync,
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
                  // 服务器地址
                  TextFormField(
                    controller: _serverController,
                    decoration: const InputDecoration(
                      labelText: '服务器地址',
                      hintText: 'https://dav.jianguoyun.com/dav/',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.dns_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入服务器地址';
                      }
                      if (!value.startsWith('http://') && !value.startsWith('https://')) {
                        return '服务器地址必须以 http:// 或 https:// 开头';
                      }
                      return null;
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () async {
                        const url = 'https://www.jianguoyun.com/';
                        try {
                          if (Platform.isWindows) {
                            await Process.run('start', [url], runInShell: true);
                          } else if (Platform.isMacOS) {
                            await Process.run('open', [url]);
                          }
                        } catch (e) {
                          debugPrint('Could not launch \$url: \$e');
                        }
                      },
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text(
                        '注册/登录坚果云',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: AmberDimens.spacingMd),

                  // 用户名
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: '用户名',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入用户名';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AmberDimens.spacingMd),

                  // 密码
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: '密码',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入密码';
                      }
                      return null;
                    },
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

                  // 删除配置按钮(仅在已配置时显示)
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
  Widget _buildStatusSubtitle(SyncState syncState, bool isConfigured) {
    if (!isConfigured) {
      return const Text('未配置 - 点击配置 WebDAV 云同步');
    }

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

    return const Text('已配置,等待同步');
  }

  /// 格式化时间为 "xx分钟前"
  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }

  /// 测试 WebDAV 连接
  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isTesting = true);

    try {
      final testConfig = SyncConfig(
        serverUrl: _serverController.text.trim(),
        username: _usernameController.text.trim(),
        syncIntervalMinutes: 30,
        autoSync: true,
      );

      // 判断使用哪个密码测试
      final currentPassword = _passwordController.text.trim();
      String? passwordToTest;

      if (_hasPasswordInKeychain && currentPassword == _originalPasswordPlaceholder) {
        // 使用钥匙串里的密码
        passwordToTest = await SyncConfigService.getPassword(testConfig.username);
      } else {
        // 使用用户输入的密码
        passwordToTest = currentPassword;
      }

      if (passwordToTest == null || passwordToTest.isEmpty) {
        if (mounted) {
          ToastManager().show(
            context,
            '请输入密码',
            type: ToastType.error,
          );
        }
        return;
      }

      final success = await ref.read(syncStateProvider.notifier).testConnection(testConfig, passwordToTest);

      if (mounted) {
        ToastManager().show(
          context,
          success ? '连接成功!' : '连接失败,请检查配置',
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

    final config = SyncConfig(
      serverUrl: _serverController.text.trim(),
      username: _usernameController.text.trim(),
      syncIntervalMinutes: 30, // 每30分钟自动同步
      autoSync: true,
    );

    // 判断密码是否被修改
    final currentPassword = _passwordController.text.trim();
    String? passwordToSave;

    if (_hasPasswordInKeychain && currentPassword == _originalPasswordPlaceholder) {
      // 密码框没被修改（还是占位符），使用钥匙串里的旧密码
      passwordToSave = await SyncConfigService.getPassword(config.username);
      print('[WebDavConfig] 使用钥匙串中的现有密码');
    } else {
      // 密码框被修改了，使用新密码
      passwordToSave = currentPassword;
      print('[WebDavConfig] 使用用户输入的新密码');
    }

    if (passwordToSave == null || passwordToSave.isEmpty) {
      // 密码为空，提示错误
      if (mounted) {
        ToastManager().show(
          context,
          '请输入密码',
          type: ToastType.error,
        );
      }
      return;
    }

    await ref.read(syncStateProvider.notifier).saveConfig(config, passwordToSave);

    if (mounted) {
      ToastManager().show(
        context,
        '配置已保存,自动同步已启用(每30分钟)',
        type: ToastType.success,
      );
    }
  }

  /// 手动触发同步
  Future<void> _manualSync() async {
    final success = await ref.read(syncStateProvider.notifier).manualSync();
    
    // 检查冲突
    if (mounted) {
      final conflicts = ref.read(syncStateProvider).tagConflicts;
      if (conflicts.isNotEmpty) {
        for (var conflict in conflicts) {
          if (!mounted) break;

          final useLocal = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => DataConflictDialog(
              title: '标签冲突检测',
              description:
                  '检测到同名标签 "${conflict.local['name']}"，但ID不同。\n'
                  '这通常发生在多端创建了同名标签时。\n'
                  '请选择保留哪一份数据？',
              localData: conflict.local,
              remoteData: conflict.remote,
              localLabel:
                  '保留本地 (ID: ...${(conflict.local['id'] as String).substring(0, 4)})',
              remoteLabel:
                  '使用远程 (ID: ...${(conflict.remote['id'] as String).substring(0, 4)})',
            ),
          );

          // 如果用户点击背景关闭，默认为 null，视为保留本地（不处理）
          final choice = useLocal ?? true;

          await ref
              .read(tagsProvider.notifier)
              .resolveConflict(
                conflict.local,
                conflict.remote,
                useRemote: !choice,
              );
        }

        // 解决完冲突后，可能需要强制刷新一下 UI 或重新 sync
        // 重新刷新列表即可
        ref.invalidate(tagsProvider);
      }
    
      if (success) {
        ref.read(soundServiceProvider).playSuccess();
      }
      ToastManager().show(
        context,
        success ? '同步完成' : '同步失败,请查看错误信息',
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
        content: const Text('确定要删除 WebDAV 同步配置吗?\n删除后将停止自动同步,但本地数据不会丢失。'),
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
      await ref.read(syncStateProvider.notifier).deleteConfig();
      _serverController.clear();
      _usernameController.clear();
      _passwordController.clear();

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
