import 'package:flutter/material.dart';

import '../../../../../core/constants/constants.dart';
import 'markdown_editor_controller.dart';

/// 行首加号菜单
///
/// 设计哲学:
/// - 当光标在空行时，在行首显示 + 按钮
/// - 点击弹出格式选择菜单（标题、列表、复选框等）
/// - 类似 Notion 的 Block 菜单设计
class LinePlusMenu extends StatefulWidget {
  final MarkdownEditorController controller;
  final VoidCallback? onLinkNoteTap;
  final VoidCallback? onLinkTaskTap;
  final VoidCallback? onAttachmentTap;
  final VoidCallback? onTagsTap;

  const LinePlusMenu({
    super.key,
    required this.controller,
    this.onLinkNoteTap,
    this.onLinkTaskTap,
    this.onAttachmentTap,
    this.onTagsTap,
  });

  @override
  State<LinePlusMenu> createState() => _LinePlusMenuState();
}

class _LinePlusMenuState extends State<LinePlusMenu> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // 类似 Notion 的加号按钮：圆形背景 + 加号图标，hover 时变深
    return GestureDetector(
      onTap: () => _showMenu(context),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          width: 20,
          height: 14, // 与光标高度一致
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _isHovered
                ? AmberColors.divider
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            Icons.add,
            size: 16,
            color: _isHovered
                ? AmberColors.textSecondary
                : AmberColors.textDisabled,
          ),
        ),
      ),
    );
  }

  /// 显示菜单
  void _showMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero);
    // 菜单宽度约 160px，往左偏移让菜单在分割线左侧展示
    const menuWidth = 160.0;

    showMenu<_MenuAction>(
      context: context,
      // 菜单在按钮左侧弹出，但右边缘稍微越过分割线几个像素
      position: RelativeRect.fromLTRB(
        offset.dx - menuWidth + 16, // 菜单右边缘越过加号按钮约 16px
        offset.dy, // 顶部与按钮对齐
        offset.dx + 16, // right 对应左边缘位置
        0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      items: [
        _buildMenuItem(
          _MenuAction.h1,
          'H₁',
          '一级标题',
          isText: true,
        ),
        _buildMenuItem(
          _MenuAction.h2,
          'H₂',
          '二级标题',
          isText: true,
        ),
        _buildMenuItem(
          _MenuAction.h3,
          'H₃',
          '三级标题',
          isText: true,
        ),
        const PopupMenuDivider(),
        _buildMenuItem(
          _MenuAction.bulletList,
          null,
          '无序列表',
          icon: Icons.format_list_bulleted,
        ),
        _buildMenuItem(
          _MenuAction.numberedList,
          null,
          '有序列表',
          icon: Icons.format_list_numbered,
        ),
        _buildMenuItem(
          _MenuAction.checkbox,
          null,
          '检查项',
          icon: Icons.check_box_outlined,
        ),
        _buildMenuItem(
          _MenuAction.quote,
          null,
          '引用',
          icon: Icons.format_quote,
        ),
        _buildMenuItem(
          _MenuAction.divider,
          null,
          '水平分割线',
          icon: Icons.horizontal_rule,
        ),
        const PopupMenuDivider(),
        _buildMenuItem(
          _MenuAction.attachment,
          null,
          '附件',
          icon: Icons.attach_file,
        ),
        _buildMenuItem(
          _MenuAction.tags,
          null,
          '标签',
          icon: Icons.label_outline,
        ),
        _buildMenuItem(
          _MenuAction.linkNoteOrTask,
          null,
          '关联任务/笔记',
          icon: Icons.link,
        ),
      ],
    ).then((action) {
      if (action == null) return;
      _handleAction(context, action);
    });
  }

  /// 构建菜单项
  PopupMenuItem<_MenuAction> _buildMenuItem(
    _MenuAction action,
    String? label,
    String title, {
    IconData? icon,
    bool isText = false,
  }) {
    return PopupMenuItem<_MenuAction>(
      value: action,
      height: 32, // 更紧凑的行高
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
  void _handleAction(BuildContext context, _MenuAction action) {
    switch (action) {
      case _MenuAction.h1:
        widget.controller.insertHeading(1);
        break;
      case _MenuAction.h2:
        widget.controller.insertHeading(2);
        break;
      case _MenuAction.h3:
        widget.controller.insertHeading(3);
        break;
      case _MenuAction.bulletList:
        widget.controller.insertBulletList();
        break;
      case _MenuAction.numberedList:
        widget.controller.insertNumberedList();
        break;
      case _MenuAction.checkbox:
        widget.controller.insertCheckbox();
        break;
      case _MenuAction.quote:
        widget.controller.insertQuote();
        break;
      case _MenuAction.divider:
        widget.controller.insertDivider();
        break;
      case _MenuAction.attachment:
        if (widget.onAttachmentTap != null) {
          widget.onAttachmentTap!();
        } else {
          _showNotSupportedMessage(context, '附件功能');
        }
        break;
      case _MenuAction.tags:
        widget.onTagsTap?.call();
        break;
      case _MenuAction.linkNoteOrTask:
        _showLinkTypeMenu(context);
        break;
    }
  }

  /// 显示关联类型选择菜单
  void _showLinkTypeMenu(BuildContext context) {
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
                widget.onLinkNoteTap?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.task_alt),
              title: const Text('任务'),
              onTap: () {
                Navigator.pop(context);
                widget.onLinkTaskTap?.call();
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
  void _showNotSupportedMessage(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature暂不支持'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// 菜单操作类型
enum _MenuAction {
  h1,
  h2,
  h3,
  bulletList,
  numberedList,
  checkbox,
  quote,
  divider,
  attachment,
  tags,
  linkNoteOrTask,
}
