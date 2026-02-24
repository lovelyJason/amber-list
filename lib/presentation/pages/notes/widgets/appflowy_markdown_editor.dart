import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/services/task_image_service.dart';

/// AppFlowy Markdown 编辑器包装组件
///
/// 设计哲学：
/// - 使用 AppFlowy Editor 替代自研的 Markdown 编辑器
/// - 支持 Markdown 格式导入导出
/// - 提供与原编辑器相同的 API 接口，便于无缝切换
/// - 支持斜线命令、快捷键、引用块等富文本功能
/// - 异步初始化，避免复杂笔记解析阻塞 UI
class AppFlowyMarkdownEditor extends StatefulWidget {
  /// 初始 Markdown 内容
  final String initialContent;

  /// 内容变化回调
  final ValueChanged<String>? onChanged;

  /// 是否显示工具栏
  final bool showToolbar;

  /// 关联笔记点击回调
  final VoidCallback? onLinkNoteTap;

  /// 关联任务点击回调
  final VoidCallback? onLinkTaskTap;

  /// 斜线命令关联任务回调
  ///
  /// 返回 Map{'id': taskId, 'title': taskTitle}，
  /// 由 note_detail_panel 负责弹出选择器并创建数据库关联
  final Future<Map<String, String>?> Function()? onSlashLinkTask;

  /// 附件点击回调
  final VoidCallback? onAttachmentTap;

  /// 标签点击回调
  final VoidCallback? onTagsTap;

  const AppFlowyMarkdownEditor({
    super.key,
    this.initialContent = '',
    this.onChanged,
    this.showToolbar = true,
    this.onLinkNoteTap,
    this.onLinkTaskTap,
    this.onSlashLinkTask,
    this.onAttachmentTap,
    this.onTagsTap,
  });

  @override
  State<AppFlowyMarkdownEditor> createState() => AppFlowyMarkdownEditorState();
}

class AppFlowyMarkdownEditorState extends State<AppFlowyMarkdownEditor> {
  EditorState? _editorState;
  EditorScrollController? _scrollController;

  /// 是否显示工具栏
  bool _showToolbar = true;

  /// 是否正在加载（异步解析 Markdown 中）
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _showToolbar = widget.showToolbar;
    _initEditorAsync();
  }

  /// 异步初始化编辑器（避免阻塞 UI）
  ///
  /// 设计哲学：
  /// - markdownToDocument 是同步的重操作，复杂笔记解析耗时明显
  /// - 使用 Future.microtask 将解析推迟到下一帧，先让 UI 渲染出骨架
  /// - 显示加载状态，给用户即时反馈
  Future<void> _initEditorAsync() async {
    // 先让 UI 渲染出来，再解析 Markdown
    await Future.microtask(() {});

    // 从 Markdown 创建文档
    final document = widget.initialContent.isNotEmpty
        ? markdownToDocument(widget.initialContent)
        : Document.blank(withInitialText: true);

    if (!mounted) return;

    final editorState = EditorState(document: document);
    final scrollController = EditorScrollController(
      editorState: editorState,
    );

    // 监听文档变化
    editorState.transactionStream.listen((_) {
      _onDocumentChanged();
    });

    setState(() {
      _editorState = editorState;
      _scrollController = scrollController;
      _isLoading = false;
    });
  }

  /// 文档变化时触发回调
  void _onDocumentChanged() {
    if (widget.onChanged != null) {
      widget.onChanged!(content);
    }
  }

  /// 获取当前 Markdown 内容
  String get content {
    final state = _editorState;
    if (state == null) return widget.initialContent;
    return documentToMarkdown(state.document);
  }

  /// 设置 Markdown 内容
  set content(String markdown) {
    final document = markdown.isNotEmpty
        ? markdownToDocument(markdown)
        : Document.blank(withInitialText: true);
    _editorState = EditorState(document: document);
    setState(() {});
  }

  /// 切换工具栏显示
  void toggleToolbar() {
    setState(() {
      _showToolbar = !_showToolbar;
    });
  }

  /// 获取 EditorState（供外部调用格式化方法）
  EditorState? get editorState => _editorState;

  /// 切换加粗
  void toggleBold() => _editorState?.toggleAttribute('bold');

  /// 切换斜体
  void toggleItalic() => _editorState?.toggleAttribute('italic');

  /// 切换下划线
  void toggleUnderline() => _editorState?.toggleAttribute('underline');

  /// 切换删除线
  void toggleStrikethrough() => _editorState?.toggleAttribute('strikethrough');

  /// 切换代码
  void toggleCode() => _editorState?.toggleAttribute('code');

  /// 转换为标题（level: 1-6）
  void formatHeading(int level) {
    final state = _editorState;
    if (state == null) return;

    final selection = state.selection;
    if (selection == null) return;

    final node = state.getNodeAtPath(selection.start.path);
    if (node == null) return;

    final transaction = state.transaction;
    transaction.updateNode(node, {
      'type': HeadingBlockKeys.type,
      HeadingBlockKeys.level: level,
    });
    state.apply(transaction);
  }

  /// 转换为段落
  void formatParagraph() {
    final state = _editorState;
    if (state == null) return;

    final selection = state.selection;
    if (selection == null) return;

    final node = state.getNodeAtPath(selection.start.path);
    if (node == null) return;

    final transaction = state.transaction;
    transaction.updateNode(node, {'type': ParagraphBlockKeys.type});
    state.apply(transaction);
  }

  /// 转换为无序列表
  void formatBulletList() {
    final state = _editorState;
    if (state == null) return;

    final selection = state.selection;
    if (selection == null) return;

    final node = state.getNodeAtPath(selection.start.path);
    if (node == null) return;

    final transaction = state.transaction;
    transaction.updateNode(node, {'type': BulletedListBlockKeys.type});
    state.apply(transaction);
  }

  /// 转换为有序列表
  void formatNumberedList() {
    final state = _editorState;
    if (state == null) return;

    final selection = state.selection;
    if (selection == null) return;

    final node = state.getNodeAtPath(selection.start.path);
    if (node == null) return;

    final transaction = state.transaction;
    transaction.updateNode(node, {'type': NumberedListBlockKeys.type});
    state.apply(transaction);
  }

  /// 转换为待办事项
  void formatTodoList() {
    final state = _editorState;
    if (state == null) return;

    final selection = state.selection;
    if (selection == null) return;

    final node = state.getNodeAtPath(selection.start.path);
    if (node == null) return;

    final transaction = state.transaction;
    transaction.updateNode(node, {
      'type': TodoListBlockKeys.type,
      TodoListBlockKeys.checked: false,
    });
    state.apply(transaction);
  }

  /// 转换为引用块
  void formatQuote() {
    final state = _editorState;
    if (state == null) return;

    final selection = state.selection;
    if (selection == null) return;

    final node = state.getNodeAtPath(selection.start.path);
    if (node == null) return;

    final transaction = state.transaction;
    transaction.updateNode(node, {'type': QuoteBlockKeys.type});
    state.apply(transaction);
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    _editorState?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 加载中显示骨架屏
    if (_isLoading || _editorState == null || _scrollController == null) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AmberDimens.spacingMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 模拟几行文本的加载骨架
            for (int i = 0; i < 5; i++) ...[
              Container(
                height: 14,
                width: i == 4 ? 150 : double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AmberColors.divider.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final editorState = _editorState!;
    final scrollController = _scrollController!;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AmberDimens.spacingMd,
      ),
      // 使用 AppFlowy 自带的 FloatingToolbar（选中文字时悬浮显示）
      child: FloatingToolbar(
        items: [
          paragraphItem,
          ...headingItems,
          ...markdownFormatItems,
          quoteItem,
          bulletedListItem,
          numberedListItem,
          linkItem,
          buildTextColorItem(),
          buildHighlightColorItem(),
        ],
        editorState: editorState,
        editorScrollController: scrollController,
        textDirection: TextDirection.ltr,
        style: FloatingToolbarStyle(
          backgroundColor: Colors.white,
          toolbarActiveColor: AmberColors.primary,
          toolbarIconColor: AmberColors.textSecondary,
          toolbarShadowColor: Colors.black.withValues(alpha: 0.1),
          toolbarElevation: 8,
        ),
        child: AppFlowyEditor(
          editorState: editorState,
          editorScrollController: scrollController,
          editorStyle: _buildEditorStyle(context),
          blockComponentBuilders: _buildBlockComponentBuilders(),
          characterShortcutEvents: _buildCharacterShortcuts(),
          commandShortcutEvents: _buildCommandShortcuts(),
        ),
      ),
    );
  }

  /// 构建编辑器样式
  EditorStyle _buildEditorStyle(BuildContext context) {
    return EditorStyle.desktop(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      cursorColor: AmberColors.primary,
      selectionColor: AmberColors.primary.withValues(alpha: 0.3),
      textStyleConfiguration: TextStyleConfiguration(
        text: const TextStyle(
          fontSize: 14,
          color: AmberColors.textPrimary,
          height: 1.5,
        ),
        bold: const TextStyle(fontWeight: FontWeight.w700),
        italic: const TextStyle(fontStyle: FontStyle.italic),
        underline: const TextStyle(decoration: TextDecoration.underline),
        strikethrough: const TextStyle(decoration: TextDecoration.lineThrough),
        href: const TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: AmberColors.textSecondary,
          backgroundColor: AmberColors.divider,
        ),
      ),
    );
  }

  /// 构建块组件（标题、引用、列表等）
  Map<String, BlockComponentBuilder> _buildBlockComponentBuilders() {
    final builders = standardBlockComponentBuilderMap;

    // 统一的块配置：减少默认 padding
    final compactConfig = BlockComponentConfiguration(
      padding: (_) => const EdgeInsets.symmetric(vertical: 2),
    );

    // 自定义引用块样式（琥珀色竖线）
    builders[QuoteBlockKeys.type] = QuoteBlockComponentBuilder(
      configuration: compactConfig,
    );

    // 自定义分割线样式（柔和的颜色）
    builders[DividerBlockKeys.type] = DividerBlockComponentBuilder(
      configuration: compactConfig,
      lineColor: AmberColors.divider.withValues(alpha: 0.7),
      height: 1,
    );

    // 无序列表
    // 圆点图标需要垂直居中对齐文字
    builders[BulletedListBlockKeys.type] = BulletedListBlockComponentBuilder(
      configuration: compactConfig,
      iconBuilder: (context, node) {
        // 文字行高 14 * 1.5 = 21px，圆点 6px
        // (21 - 6) / 2 ≈ 7.5：用 top≈7 让圆点与正文第一行更贴合
        return const Padding(
          padding: EdgeInsets.only(right: 8, top: 7),
          child: Icon(
            Icons.circle,
            size: 6,
            color: AmberColors.textSecondary,
          ),
        );
      },
    );

    // 有序列表
    // 注意：AppFlowy 内部行布局会影响 icon 与正文的垂直对齐，这里只做轻微微调，避免序号与正文错位
    builders[NumberedListBlockKeys.type] = NumberedListBlockComponentBuilder(
      configuration: compactConfig,
      iconBuilder: (context, node, direction) {
        final index = _getNumberedListIndex(node);
        // AppFlowy 内部会对 icon 区域做额外的垂直布局处理，导致序号与正文第一行不在同一水平线上。
        // 这里用轻微的 translate 微调（避免负 padding）。
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Transform.translate(
            offset: const Offset(0, -2),
            child: Text(
              '$index.',
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AmberColors.textSecondary,
              ),
            ),
          ),
        );
      },
    );

    // 任务列表（复选框）
    // 文字行高 14 * 1.5 = 21px，复选框 18px
    // 使用 Transform.translate 微调垂直位置，让复选框与文字第一行居中对齐
    builders[TodoListBlockKeys.type] = TodoListBlockComponentBuilder(
      configuration: compactConfig,
      iconBuilder: (context, node, onCheck) {
        final checked = node.attributes[TodoListBlockKeys.checked] ?? false;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Transform.translate(
            offset: const Offset(0, -1), // 往上微调 1px
            child: GestureDetector(
              onTap: onCheck,
              child: Icon(
                checked ? Icons.check_box : Icons.check_box_outline_blank,
                size: 18, // 稍微缩小，更协调
                color: checked ? AmberColors.primary : AmberColors.textSecondary,
              ),
            ),
          ),
        );
      },
    );

    return builders;
  }

  /// 构建字符快捷方式（输入触发）
  ///
  /// 包含标准 Markdown 快捷语法 + 自定义斜线命令菜单
  /// 斜线命令菜单包含标准项（标题、列表等）+ "关联任务"项
  List<CharacterShortcutEvent> _buildCharacterShortcuts() {
    // 过滤掉标准事件中的默认 slashCommand，用自定义版本替换
    final filtered = standardCharacterShortcutEvents
        .where((e) => e.key != 'show the slash menu')
        .toList();

    return [
      ...filtered,
      // 自定义斜线命令：标准项 + 关联任务
      customSlashCommand(
        [
          ...standardSelectionMenuItems,
          _buildLinkTaskMenuItem(),
        ],
        style: SelectionMenuStyle.light,
      ),
    ];
  }

  /// 构建"关联任务"斜线命令菜单项
  SelectionMenuItem _buildLinkTaskMenuItem() {
    return SelectionMenuItem(
      getName: () => '关联任务',
      icon: (editorState, isSelected, style) => Icon(
        Icons.add_task_outlined,
        size: 18,
        color: isSelected ? AmberColors.primary : AmberColors.textSecondary,
      ),
      keywords: ['link', 'task', '关联', '任务'],
      handler: (editorState, menuService, context) async {
        final callback = widget.onSlashLinkTask;
        if (callback == null) return;

        final result = await callback();
        if (result == null) return;

        final title = result['title'] ?? '';
        final id = result['id'] ?? '';
        if (title.isEmpty || id.isEmpty) return;

        // 在当前光标位置插入任务链接
        final linkText = '[$title](task:$id)';
        final selection = editorState.selection;
        if (selection != null && selection.isCollapsed) {
          final transaction = editorState.transaction;
          transaction.insertText(
            editorState.getNodeAtPath(selection.start.path)!,
            selection.start.offset,
            linkText,
          );
          await editorState.apply(transaction);
        }
      },
    );
  }

  /// 构建命令快捷方式（组合键触发）
  ///
  /// 包含标准快捷键 + 自定义粘贴图片命令
  /// 粘贴图片命令会检查剪切板是否有图片，有则插入 Markdown 图片语法
  List<CommandShortcutEvent> _buildCommandShortcuts() {
    // 过滤掉标准的粘贴命令（key 是 'paste the content'），用自定义版本替换
    final filtered = standardCommandShortcutEvents
        .where((e) => !e.key.contains('paste'))
        .toList();

    return [
      // 自定义粘贴命令放在前面，优先匹配
      _buildPasteImageCommand(),
      ...filtered,
    ];
  }

  /// 构建粘贴图片命令
  ///
  /// 逻辑：
  /// 1. 先检查剪切板是否有图片
  /// 2. 有图片则保存到本地并插入 Markdown 图片语法
  /// 3. 没有图片则执行默认粘贴（文本）
  ///
  /// 注意：AppFlowy 的 handler 必须是同步返回 KeyEventResult，
  /// 异步逻辑需要用 IIFE 包裹
  CommandShortcutEvent _buildPasteImageCommand() {
    return CommandShortcutEvent(
      key: 'paste the content',
      getDescription: () => 'Paste content (supports images)',
      command: 'ctrl+v',
      macOSCommand: 'cmd+v',
      handler: (editorState) {
        final selection = editorState.selection;
        if (selection == null) {
          return KeyEventResult.ignored;
        }

        // 异步逻辑用 IIFE 包裹
        () async {
          // 检查剪切板是否有图片
          final hasImage = await TaskImageService.hasImageInClipboard();

          if (hasImage) {
            // 粘贴图片
            final imagePath = await TaskImageService.pasteImageFromClipboard();
            if (imagePath != null) {
              final currentSelection = editorState.selection;
              if (currentSelection != null && currentSelection.isCollapsed) {
                // 插入 Markdown 图片语法
                final imageMarkdown = '![image]($imagePath)';
                final transaction = editorState.transaction;
                transaction.insertText(
                  editorState.getNodeAtPath(currentSelection.start.path)!,
                  currentSelection.start.offset,
                  imageMarkdown,
                );
                await editorState.apply(transaction);
                // 手动触发 onChanged 回调，确保父组件即时更新
                _onDocumentChanged();
              }
              return; // 图片粘贴成功，不再执行文本粘贴
            }
          }

          // 没有图片，执行默认文本粘贴
          final data = await AppFlowyClipboard.getData();
          final text = data.text;
          final html = data.html;
          if (html != null && html.isNotEmpty) {
            // 尝试粘贴 HTML
            final nodes = htmlToDocument(html).root.children.toList();
            if (nodes.isNotEmpty) {
              // 简化处理：直接插入纯文本
              if (text != null && text.isNotEmpty) {
                await editorState.insertTextAtCurrentSelection(text);
              }
              return;
            }
          }
          if (text != null && text.isNotEmpty) {
            await editorState.insertTextAtCurrentSelection(text);
          }
        }();

        return KeyEventResult.handled;
      },
    );
  }

  /// 获取有序列表的序号
  /// 通过遍历前面的兄弟节点来计算当前节点的序号
  int _getNumberedListIndex(Node node) {
    int index = 1;
    Node? previous = node.previous;
    while (previous != null && previous.type == NumberedListBlockKeys.type) {
      index++;
      previous = previous.previous;
    }
    return index;
  }
}
