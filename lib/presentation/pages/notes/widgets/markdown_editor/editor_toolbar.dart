import 'package:flutter/material.dart';

import '../../../../../core/constants/constants.dart';
import 'markdown_editor_controller.dart';

/// Markdown 编辑器底部工具栏
///
/// 设计哲学:
/// - 固定在编辑器底部，类似 Notion 的浮动工具栏
/// - 支持基础格式化操作（粗体、斜体、标题等）
/// - 分组布局：左侧格式按钮 + 右侧更多操作
/// - 响应式设计：窄屏自动隐藏部分按钮
class EditorToolbar extends StatelessWidget {
  final MarkdownEditorController controller;
  final VoidCallback? onFullscreenToggle;
  final VoidCallback? onAttachmentTap;
  final VoidCallback? onLinkNoteTap;
  final VoidCallback? onLinkTaskTap;
  final bool isFullscreen;

  const EditorToolbar({
    super.key,
    required this.controller,
    this.onFullscreenToggle,
    this.onAttachmentTap,
    this.onLinkNoteTap,
    this.onLinkTaskTap,
    this.isFullscreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AmberDimens.spacingMd,
        vertical: AmberDimens.spacingSm,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
          // 全屏切换
          _buildToolButton(
            icon: isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
            tooltip: isFullscreen ? '退出全屏' : '全屏',
            onTap: onFullscreenToggle,
          ),
          _buildDivider(),

          // 标题
          _buildToolButton(
            icon: Icons.title,
            tooltip: '标题',
            label: 'H',
            onTap: () => _showHeadingMenu(context),
          ),

          // 粗体
          _buildToolButton(
            icon: Icons.format_bold,
            tooltip: '粗体 (⌘B)',
            onTap: controller.toggleBold,
          ),

          // 高亮
          _buildHighlightButton(
            tooltip: '高亮',
            onTap: controller.toggleHighlight,
          ),
          _buildDivider(),

          // 复选框
          _buildToolButton(
            icon: Icons.check_box_outlined,
            tooltip: '复选框',
            onTap: controller.insertCheckbox,
          ),

          // 无序列表
          _buildToolButton(
            icon: Icons.format_list_bulleted,
            tooltip: '无序列表',
            onTap: controller.insertBulletList,
          ),

          // 有序列表
          _buildToolButton(
            icon: Icons.format_list_numbered,
            tooltip: '有序列表',
            onTap: controller.insertNumberedList,
          ),
          _buildDivider(),

          // 斜体
          _buildToolButton(
            icon: Icons.format_italic,
            tooltip: '斜体 (⌘I)',
            onTap: controller.toggleItalic,
          ),

          // 下划线
          _buildToolButton(
            icon: Icons.format_underlined,
            tooltip: '下划线',
            onTap: controller.toggleUnderline,
          ),

          // 删除线
          _buildToolButton(
            icon: Icons.format_strikethrough,
            tooltip: '删除线',
            onTap: controller.toggleStrikethrough,
          ),

          // 表格
          _buildToolButton(
            icon: Icons.table_chart_outlined,
            tooltip: '表格',
            onTap: controller.insertTable,
          ),

          // 时间戳
          _buildToolButton(
            icon: Icons.access_time,
            tooltip: '时间戳',
            onTap: controller.insertTimestamp,
          ),
          _buildDivider(),

          // 链接
          _buildToolButton(
            icon: Icons.link,
            tooltip: '链接 (⌘K)',
            onTap: () => _showLinkDialog(context),
          ),

          // 代码块
          _buildToolButton(
            icon: Icons.code,
            tooltip: '代码块',
            onTap: () => controller.insertCodeBlock(),
          ),

          // 引用
          _buildToolButton(
            icon: Icons.format_quote,
            tooltip: '引用',
            onTap: controller.insertQuote,
          ),
          _buildDivider(),

          // 附件（暂不支持）
          _buildToolButton(
            icon: Icons.attach_file,
            tooltip: '附件',
            onTap: onAttachmentTap,
          ),
          ],
        ),
      ),
    );
  }

  /// 构建工具按钮
  Widget _buildToolButton({
    IconData? icon,
    String? label,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: label != null
              ? Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AmberColors.textSecondary,
                  ),
                )
              : Icon(
                  icon,
                  size: 20,
                  color: AmberColors.textSecondary,
                ),
        ),
      ),
    );
  }

  /// 构建高亮按钮（带黄色背景）
  Widget _buildHighlightButton({
    required String tooltip,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.yellow.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'A',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AmberColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建分隔线
  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: AmberColors.divider,
    );
  }

  /// 显示标题菜单
  void _showHeadingMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero);

    showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + 40,
        offset.dy - 200,
        offset.dx + 200,
        offset.dy,
      ),
      items: [
        _buildHeadingMenuItem(1, 'H1', '一级标题', 24),
        _buildHeadingMenuItem(2, 'H2', '二级标题', 20),
        _buildHeadingMenuItem(3, 'H3', '三级标题', 18),
        _buildHeadingMenuItem(4, 'H4', '四级标题', 16),
        _buildHeadingMenuItem(5, 'H5', '五级标题', 14),
        _buildHeadingMenuItem(6, 'H6', '六级标题', 12),
      ],
    ).then((level) {
      if (level != null) {
        controller.insertHeading(level);
      }
    });
  }

  /// 构建标题菜单项
  PopupMenuItem<int> _buildHeadingMenuItem(
    int level,
    String prefix,
    String label,
    double fontSize,
  ) {
    return PopupMenuItem<int>(
      value: level,
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              prefix,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: AmberColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  /// 显示链接对话框
  void _showLinkDialog(BuildContext context) {
    final textController = TextEditingController();
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('插入链接'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: '显示文字',
                hintText: '链接显示的文字',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: '链接地址',
                hintText: 'https://',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final displayText = textController.text.isEmpty
                  ? urlController.text
                  : textController.text;
              controller.insertLink(displayText, urlController.text);
              Navigator.pop(context);
            },
            child: const Text('插入'),
          ),
        ],
      ),
    );
  }
}
