import 'package:flutter/material.dart';

import '../../../../../core/constants/constants.dart';
import 'markdown_editor_controller.dart';

/// 斜线命令菜单
///
/// 设计哲学：
/// - 输入 `/` 时在光标位置弹出快捷命令菜单
/// - 功能与加号菜单一致，但位置跟随光标
/// - 智能判断位置：底部空间不足时向上弹出
class SlashCommandMenu {
  /// 显示斜线命令菜单
  ///
  /// [context] 上下文
  /// [controller] 编辑器控制器
  /// [cursorRect] 光标在屏幕上的位置（全局坐标）
  /// [onLinkNoteTap] 关联笔记回调
  /// [onLinkTaskTap] 关联任务回调
  /// [onAttachmentTap] 附件回调
  /// [onTagsTap] 标签回调
  static Future<void> show({
    required BuildContext context,
    required MarkdownEditorController controller,
    required Rect cursorRect,
    VoidCallback? onLinkNoteTap,
    VoidCallback? onLinkTaskTap,
    VoidCallback? onAttachmentTap,
    VoidCallback? onTagsTap,
  }) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final screenHeight = overlay.size.height;

    // 菜单高度估算（13项 * 32px + 2分割线 * 8px ≈ 430px）
    const menuHeight = 430.0;
    const menuWidth = 180.0;

    // 判断菜单应该向上还是向下弹出
    // 如果光标位置 + 菜单高度 > 屏幕高度 - 50px（留点余量），则向上弹出
    final shouldShowAbove = cursorRect.bottom + menuHeight > screenHeight - 50;

    // 计算菜单位置
    final double top;
    final double bottom;

    // 行高，用于计算紧贴位置
    const lineHeight = 21.0;

    if (shouldShowAbove) {
      // 向上弹出：菜单底部紧贴斜线上方
      top = 0;
      bottom = screenHeight - cursorRect.top + 2;
    } else {
      // 向下弹出：菜单顶部紧贴斜线下方（光标位置 + 行高 + 小间距）
      top = cursorRect.top + lineHeight + 2;
      bottom = 0;
    }

    final action = await showMenu<_SlashAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        cursorRect.left,
        top,
        overlay.size.width - cursorRect.left - menuWidth,
        bottom,
      ),
      elevation: 16,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      surfaceTintColor: Colors.transparent,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      constraints: const BoxConstraints(maxWidth: menuWidth),
      popUpAnimationStyle: AnimationStyle.noAnimation,
      items: [
        _buildMenuItem(_SlashAction.h1, 'H₁', '一级标题', isText: true),
        _buildMenuItem(_SlashAction.h2, 'H₂', '二级标题', isText: true),
        _buildMenuItem(_SlashAction.h3, 'H₃', '三级标题', isText: true),
        const PopupMenuDivider(),
        _buildMenuItem(_SlashAction.bulletList, null, '无序列表',
            icon: Icons.format_list_bulleted),
        _buildMenuItem(_SlashAction.numberedList, null, '有序列表',
            icon: Icons.format_list_numbered),
        _buildMenuItem(_SlashAction.checkbox, null, '检查项',
            icon: Icons.check_box_outlined),
        _buildMenuItem(_SlashAction.quote, null, '引用',
            icon: Icons.format_quote),
        _buildMenuItem(_SlashAction.divider, null, '水平分割线',
            icon: Icons.horizontal_rule),
        const PopupMenuDivider(),
        _buildMenuItem(_SlashAction.attachment, null, '附件',
            icon: Icons.attach_file),
        _buildMenuItem(_SlashAction.subTask, null, '子任务',
            icon: Icons.subdirectory_arrow_right),
        _buildMenuItem(_SlashAction.tags, null, '标签',
            icon: Icons.label_outline),
        _buildMenuItem(_SlashAction.linkNoteOrTask, null, '关联任务/笔记',
            icon: Icons.link),
      ],
    );

    if (action == null) return;

    // 检查 context 是否仍然有效
    if (!context.mounted) return;

    // 先删除输入的 `/`
    _deleteSlashChar(controller);

    // 刷新行信息（删除 `/` 后需要更新，否则 insert 方法无法正确获取行信息）
    controller.refreshLineInfo();

    // 然后执行对应操作
    _handleAction(context, controller, action,
        onLinkNoteTap: onLinkNoteTap,
        onLinkTaskTap: onLinkTaskTap,
        onAttachmentTap: onAttachmentTap,
        onTagsTap: onTagsTap);
  }

  /// 删除光标前的 `/` 字符
  static void _deleteSlashChar(MarkdownEditorController controller) {
    final cursorPos = controller.selection.baseOffset;
    if (cursorPos <= 0) return;

    // 检查光标前一个字符是否是 `/`
    final text = controller.text;
    if (cursorPos <= text.length && text[cursorPos - 1] == '/') {
      controller.value = controller.value.copyWith(
        text: text.substring(0, cursorPos - 1) + text.substring(cursorPos),
        selection: TextSelection.collapsed(offset: cursorPos - 1),
      );
    }
  }

  /// 构建菜单项
  static PopupMenuItem<_SlashAction> _buildMenuItem(
    _SlashAction action,
    String? label,
    String title, {
    IconData? icon,
    bool isText = false,
  }) {
    return PopupMenuItem<_SlashAction>(
      value: action,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: isText
                ? Text(
                    label ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AmberColors.textSecondary,
                    ),
                  )
                : Icon(
                    icon,
                    size: 16,
                    color: AmberColors.textSecondary,
                  ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// 处理菜单操作
  static void _handleAction(
    BuildContext context,
    MarkdownEditorController controller,
    _SlashAction action, {
    VoidCallback? onLinkNoteTap,
    VoidCallback? onLinkTaskTap,
    VoidCallback? onAttachmentTap,
    VoidCallback? onTagsTap,
  }) {
    switch (action) {
      case _SlashAction.h1:
        controller.insertHeading(1);
        break;
      case _SlashAction.h2:
        controller.insertHeading(2);
        break;
      case _SlashAction.h3:
        controller.insertHeading(3);
        break;
      case _SlashAction.bulletList:
        controller.insertBulletList();
        break;
      case _SlashAction.numberedList:
        controller.insertNumberedList();
        break;
      case _SlashAction.checkbox:
        controller.insertCheckbox();
        break;
      case _SlashAction.quote:
        controller.insertQuote();
        break;
      case _SlashAction.divider:
        controller.insertDivider();
        break;
      case _SlashAction.attachment:
        if (onAttachmentTap != null) {
          onAttachmentTap();
        } else {
          _showNotSupportedMessage(context, '附件功能');
        }
        break;
      case _SlashAction.subTask:
        _showNotSupportedMessage(context, '子任务功能');
        break;
      case _SlashAction.tags:
        onTagsTap?.call();
        break;
      case _SlashAction.linkNoteOrTask:
        _showLinkTypeMenu(context, onLinkNoteTap, onLinkTaskTap);
        break;
    }
  }

  /// 显示关联类型选择菜单
  static void _showLinkTypeMenu(
    BuildContext context,
    VoidCallback? onLinkNoteTap,
    VoidCallback? onLinkTaskTap,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关联到'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('笔记'),
              onTap: () {
                Navigator.pop(context);
                onLinkNoteTap?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.task_alt),
              title: const Text('任务'),
              onTap: () {
                Navigator.pop(context);
                onLinkTaskTap?.call();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// 显示暂不支持提示
  static void _showNotSupportedMessage(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature暂不支持'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// 斜线命令操作类型
enum _SlashAction {
  h1,
  h2,
  h3,
  bulletList,
  numberedList,
  checkbox,
  quote,
  divider,
  attachment,
  subTask,
  tags,
  linkNoteOrTask,
}
