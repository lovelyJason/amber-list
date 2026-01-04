import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/constants.dart';
import '../../data/models/activation_code.dart';
import '../providers/activation_provider.dart';
import 'common/toast/toast_manager.dart';

/// ============================================================
/// 激活码输入对话框
/// ============================================================
/// 当用户点击需要激活的功能时弹出，让用户输入激活码
/// 支持显示激活状态、剩余天数等信息
/// ============================================================

class ActivationDialog extends ConsumerStatefulWidget {
  /// 是否显示关闭按钮（某些场景可能需要强制激活）
  final bool showCloseButton;

  /// 激活成功后的回调
  final VoidCallback? onActivated;

  const ActivationDialog({
    super.key,
    this.showCloseButton = true,
    this.onActivated,
  });

  /// 显示激活对话框
  static Future<bool?> show(
    BuildContext context, {
    bool showCloseButton = true,
    VoidCallback? onActivated,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: showCloseButton,
      builder: (context) => ActivationDialog(
        showCloseButton: showCloseButton,
        onActivated: onActivated,
      ),
    );
  }

  @override
  ConsumerState<ActivationDialog> createState() => _ActivationDialogState();
}

class _ActivationDialogState extends ConsumerState<ActivationDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 自动聚焦到输入框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 执行激活
  Future<void> _activate() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      ToastManager().show(context, '请输入激活码', type: ToastType.warning);
      return;
    }

    final success = await ref.read(activationProvider.notifier).activate(code);

    if (!mounted) return;

    if (success) {
      ToastManager().show(context, '激活成功！', type: ToastType.success);
      widget.onActivated?.call();
      Navigator.of(context).pop(true);
    }
    // 失败的错误信息会在 state.lastError 中，UI 会自动显示
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activationProvider);

    return PopScope(
      canPop: widget.showCloseButton && !state.isActivating,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AmberDimens.radiusLg),
        ),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(AmberDimens.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AmberColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.key_rounded,
                      color: AmberColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AmberDimens.spacingMd),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '激活应用',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '输入激活码解锁全部功能',
                          style: TextStyle(
                            fontSize: 13,
                            color: AmberColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 关闭按钮
                  if (widget.showCloseButton && !state.isActivating)
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close, size: 20),
                      color: AmberColors.textSecondary,
                      splashRadius: 20,
                    ),
                ],
              ),

              const SizedBox(height: AmberDimens.spacingLg),

              // 激活码输入框
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: !state.isActivating,
                decoration: InputDecoration(
                  hintText: '请输入激活码',
                  hintStyle: const TextStyle(color: AmberColors.textDisabled),
                  prefixIcon: Icon(
                    Icons.vpn_key_outlined,
                    color: AmberColors.textSecondary,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.grey.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
                    borderSide: BorderSide(
                      color: AmberColors.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AmberDimens.spacingMd,
                    vertical: AmberDimens.spacingMd,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 15,
                  letterSpacing: 1,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _activate(),
              ),

              // 错误提示
              if (state.lastError != null) ...[
                const SizedBox(height: AmberDimens.spacingSm),
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: AmberDimens.spacingXs),
                    Expanded(
                      child: Text(
                        state.lastError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: AmberDimens.spacingLg),

              // 激活按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: state.isActivating ? null : _activate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AmberColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AmberColors.primary.withValues(alpha: 0.6),
                    padding: const EdgeInsets.symmetric(
                      vertical: AmberDimens.spacingMd,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
                    ),
                  ),
                  child: state.isActivating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '激活',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: AmberDimens.spacingMd),

              // 获取激活码提示
              Center(
                child: TextButton(
                  onPressed: () {
                    // TODO: 打开获取激活码的链接或联系方式
                    ToastManager().show(
                      context,
                      '请联系开发者获取激活码',
                      type: ToastType.info,
                    );
                  },
                  child: const Text(
                    '如何获取激活码？',
                    style: TextStyle(
                      color: AmberColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// 激活状态显示组件
/// ============================================================
/// 用于在设置页面显示当前激活状态，支持查看和注销激活码
/// ============================================================

class ActivationStatusCard extends ConsumerWidget {
  const ActivationStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activationProvider);

    // 未激活状态
    if (!state.isActivated) {
      return _buildNotActivatedCard(context, ref);
    }

    // 已激活状态
    return _buildActivatedCard(context, ref, state);
  }

  /// 构建未激活卡片
  Widget _buildNotActivatedCard(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AmberDimens.spacingMd),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline,
              color: Colors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: AmberDimens.spacingMd),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '未激活',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '激活后解锁全部高级功能',
                  style: TextStyle(
                    fontSize: 12,
                    color: AmberColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => ActivationDialog.show(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AmberColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: AmberDimens.spacingMd,
                vertical: AmberDimens.spacingSm,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
              ),
            ),
            child: const Text('激活'),
          ),
        ],
      ),
    );
  }

  /// 构建已激活卡片
  Widget _buildActivatedCard(BuildContext context, WidgetRef ref, ActivationState state) {
    final code = state.activationCode;
    final isPermanent = state.isPermanent;
    final remainingDays = state.remainingDays;
    final isExpired = state.isExpired;

    // 根据状态决定颜色
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isExpired) {
      statusColor = Colors.red;
      statusText = '已过期';
      statusIcon = Icons.error_outline;
    } else if (isPermanent) {
      statusColor = AmberColors.success;
      statusText = '永久激活';
      statusIcon = Icons.verified;
    } else if (remainingDays <= 7) {
      statusColor = Colors.orange;
      statusText = '剩余 $remainingDays 天';
      statusIcon = Icons.schedule;
    } else {
      statusColor = AmberColors.success;
      statusText = '剩余 $remainingDays 天';
      statusIcon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.all(AmberDimens.spacingMd),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AmberDimens.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          statusText,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: statusColor,
                          ),
                        ),
                        if (code?.type != null) ...[
                          const SizedBox(width: AmberDimens.spacingSm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getTypeLabel(code!.type),
                              style: TextStyle(
                                fontSize: 10,
                                color: statusColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '激活码: ${_maskCode(code?.code ?? '')}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AmberColors.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              // 注销按钮
              TextButton(
                onPressed: () => _showDeactivateDialog(context, ref),
                style: TextButton.styleFrom(
                  foregroundColor: AmberColors.textSecondary,
                ),
                child: const Text('注销', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          // 过期提示
          if (isExpired) ...[
            const SizedBox(height: AmberDimens.spacingSm),
            Container(
              padding: const EdgeInsets.all(AmberDimens.spacingSm),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AmberDimens.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Colors.red,
                  ),
                  const SizedBox(width: AmberDimens.spacingXs),
                  const Expanded(
                    child: Text(
                      '激活码已过期，请重新激活',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ActivationDialog.show(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '重新激活',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 获取激活码类型标签
  String _getTypeLabel(ActivationCodeType type) {
    switch (type) {
      case ActivationCodeType.trial:
        return '试用版';
      case ActivationCodeType.pro:
        return '专业版';
      case ActivationCodeType.enterprise:
        return '企业版';
    }
  }

  /// 遮盖激活码中间部分
  String _maskCode(String code) {
    if (code.length <= 8) return code;
    final prefix = code.substring(0, 4);
    final suffix = code.substring(code.length - 4);
    return '$prefix****$suffix';
  }

  /// 显示注销确认对话框
  void _showDeactivateDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: AmberDimens.spacingSm),
            Text('确认注销'),
          ],
        ),
        content: const Text('注销后需要重新输入激活码才能使用高级功能，确定要注销吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref.read(activationProvider.notifier).deactivate();
              ToastManager().show(context, '已注销激活', type: ToastType.success);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认注销'),
          ),
        ],
      ),
    );
  }
}
