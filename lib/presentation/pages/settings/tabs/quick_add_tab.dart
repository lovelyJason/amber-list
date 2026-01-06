import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/services/quick_add/quick_add_service.dart';
import '../../../providers/providers.dart';
import '../../../providers/quick_add_settings_provider.dart';
import '../../../widgets/common/toast/toast_manager.dart';
import '../widgets/settings_section.dart';

/// 闪念胶囊设置标签页
/// 配置全局快捷键唤出闪念胶囊窗口
class QuickAddTab extends ConsumerStatefulWidget {
  const QuickAddTab({super.key});

  @override
  ConsumerState<QuickAddTab> createState() => _QuickAddTabState();
}

class _QuickAddTabState extends ConsumerState<QuickAddTab> {
  /// 是否正在录制快捷键
  bool _isRecording = false;

  /// 临时存储录制的快捷键
  QuickAddSettings? _recordedSettings;

  /// 焦点节点（用于监听键盘输入）
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(quickAddSettingsProvider);

    return ListView(
      padding: const EdgeInsets.all(AmberDimens.spacingLg),
      children: [
        // 快捷键配置区域
        SettingsSection(
          title: '全局快捷键',
          children: [
            // 当前快捷键显示
            _buildHotKeyTile(settings),
          ],
        ),
        const SizedBox(height: AmberDimens.spacingMd),
        // 说明文字
        _buildHelpText(),
      ],
    );
  }

  /// 构建快捷键配置项
  Widget _buildHotKeyTile(QuickAddSettings settings) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _isRecording ? _handleKeyEvent : null,
      child: ListTile(
        leading: Icon(
          Icons.keyboard_outlined,
          color: AmberColors.primary,
          size: 24,
        ),
        title: const Text(
          '唤出快捷键',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AmberColors.textPrimary,
          ),
        ),
        subtitle: Text(
          _isRecording ? '请按下快捷键组合...' : '按下快捷键快速打开闪念胶囊',
          style: TextStyle(
            fontSize: 12,
            color: _isRecording ? AmberColors.primary : AmberColors.textSecondary,
          ),
        ),
        trailing: _buildHotKeyButton(settings),
        onTap: _startRecording,
      ),
    );
  }

  /// 构建快捷键按钮
  Widget _buildHotKeyButton(QuickAddSettings settings) {
    final displayText = _isRecording
        ? (_recordedSettings?.displayText ?? '...')
        : settings.displayText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _isRecording
            ? AmberColors.primary.withValues(alpha: 0.15)
            : AmberColors.cardBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _isRecording ? AmberColors.primary : Colors.grey.shade300,
          width: _isRecording ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            displayText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: Platform.isMacOS ? '.SF Pro Text' : null,
              color: _isRecording ? AmberColors.primary : AmberColors.textPrimary,
            ),
          ),
          if (_isRecording) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AmberColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建帮助说明
  Widget _buildHelpText() {
    return Container(
      padding: const EdgeInsets.all(AmberDimens.spacingMd),
      decoration: BoxDecoration(
        color: AmberColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: AmberColors.primary,
          ),
          const SizedBox(width: AmberDimens.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '使用提示',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AmberColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• 点击快捷键区域开始录制新的快捷键\n'
                  '• 按下组合键后松开即可保存\n'
                  '• 建议使用 ${Platform.isMacOS ? "Control" : "Ctrl"} + Shift + 字母键\n'
                  '• 修改后立即生效，无需重启应用',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: AmberColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 开始录制快捷键
  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordedSettings = null;
    });
    _focusNode.requestFocus();
  }

  /// 处理键盘事件
  void _handleKeyEvent(KeyEvent event) {
    if (!_isRecording) return;

    // 只处理按键按下事件
    if (event is! KeyDownEvent) return;

    // 获取修饰键状态
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isMeta = HardwareKeyboard.instance.isMetaPressed;

    // 忽略单独的修饰键
    if (_isModifierKey(event.physicalKey)) {
      return;
    }

    // 必须至少有一个修饰键
    if (!isCtrl && !isShift && !isAlt && !isMeta) {
      return;
    }

    // 获取主键标签
    final keyLabel = _getKeyLabel(event.physicalKey);
    if (keyLabel == null) return;

    // 创建新设置
    final newSettings = QuickAddSettings(
      keyLabel: keyLabel,
      useCtrl: isCtrl,
      useShift: isShift,
      useAlt: isAlt,
      useMeta: isMeta,
    );

    // 更新 UI
    setState(() {
      _recordedSettings = newSettings;
    });

    // 延迟保存，让用户看到效果
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _saveAndApplyHotKey(newSettings);
      }
    });
  }

  /// 判断是否是修饰键
  bool _isModifierKey(PhysicalKeyboardKey key) {
    return key == PhysicalKeyboardKey.controlLeft ||
        key == PhysicalKeyboardKey.controlRight ||
        key == PhysicalKeyboardKey.shiftLeft ||
        key == PhysicalKeyboardKey.shiftRight ||
        key == PhysicalKeyboardKey.altLeft ||
        key == PhysicalKeyboardKey.altRight ||
        key == PhysicalKeyboardKey.metaLeft ||
        key == PhysicalKeyboardKey.metaRight;
  }

  /// 获取按键标签
  String? _getKeyLabel(PhysicalKeyboardKey key) {
    // 字母键 A-Z
    if (key.usbHidUsage >= 0x00070004 && key.usbHidUsage <= 0x0007001D) {
      final charCode = 65 + (key.usbHidUsage - 0x00070004); // A=65
      return String.fromCharCode(charCode);
    }

    // 数字键 0-9
    if (key.usbHidUsage >= 0x0007001E && key.usbHidUsage <= 0x00070027) {
      if (key.usbHidUsage == 0x00070027) return '0';
      return String.fromCharCode(49 + (key.usbHidUsage - 0x0007001E)); // 1-9
    }

    // 特殊键
    if (key == PhysicalKeyboardKey.space) return 'Space';
    if (key == PhysicalKeyboardKey.enter) return 'Enter';
    if (key == PhysicalKeyboardKey.tab) return 'Tab';
    if (key == PhysicalKeyboardKey.escape) return 'Esc';

    return null;
  }

  /// 保存并应用新的快捷键
  Future<void> _saveAndApplyHotKey(QuickAddSettings newSettings) async {
    // 保存到 Provider
    await ref.read(quickAddSettingsProvider.notifier).updateSettings(newSettings);

    // 获取 QuickAddService 并重新注册热键
    final quickAddService = ref.read(quickAddServiceProvider);
    await quickAddService.registerHotKey(newSettings.toHotKey());

    // 结束录制状态
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordedSettings = null;
      });

      // 显示成功提示
      ToastManager().show(
        context,
        '快捷键已更新为 ${newSettings.displayText}',
        type: ToastType.success,
      );
    }
  }
}
