import 'dart:async';
import 'dart:math';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/services/task_image_service.dart';
import 'clickable_image_block_component.dart';
import 'note_priority_utils.dart';

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
  StreamSubscription? _transactionSub;
  final FocusNode _focusNode = FocusNode();

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
    final document = _editableDocumentFromMarkdown(widget.initialContent);

    if (!mounted) return;

    _applyDocument(document, setLoading: false);
  }

  Document _editableDocumentFromMarkdown(String markdown) {
    var normalized = _normalizeMarkdownForImageBlocks(markdown);
    normalized = _stripPriorityBoldMarkers(normalized);
    if (normalized.trim().isEmpty) {
      return Document.blank(withInitialText: true);
    }
    final document = markdownToDocument(normalized);
    if (document.root.children.isEmpty) {
      document.insert([0], [paragraphNode()]);
    }
    return document;
  }

  /// 兼容旧数据：去掉优先级标记周围残留的 bold **
  String _stripPriorityBoldMarkers(String input) {
    return input.replaceAllMapped(
      RegExp(r'\*\*([①-⑨]) ?\*\*'),
      (m) => '${m.group(1)} ',
    );
  }

  String _normalizeMarkdownForImageBlocks(String input) {
    var s = input;

    // Legacy data may have image markdown glued to surrounding text or list items
    // due to missing line breaks, making the markdown decoder treat it as plain text.
    // Ensure images become standalone blocks by inserting blank lines around them.

    // a) Ensure there is a blank line BEFORE an image if previous char isn't '\n'
    s = s.replaceAllMapped(
      RegExp(r'([^\n])(!\[[^\]]*\]\([^)]+\))'),
      (m) => '${m.group(1)}\n\n${m.group(2)}',
    );

    // b) Ensure there is a blank line AFTER an image if next char isn't '\n'
    s = s.replaceAllMapped(
      RegExp(r'(!\[[^\]]*\]\([^)]+\))([^\n])'),
      (m) => '${m.group(1)}\n\n${m.group(2)}',
    );

    // c) If an image line is indented, de-indent it (helps parser produce <p><img/></p>)
    s = s.replaceAllMapped(
      RegExp(r'^[ \t]+(!\[[^\]]*\]\([^)]+\))[ \t]*$', multiLine: true),
      (m) => m.group(1) ?? '',
    );

    return s;
  }

  void _applyDocument(Document document, {required bool setLoading}) {
    _transactionSub?.cancel();
    _scrollController?.dispose();
    _editorState?.dispose();

    final editorState = EditorState(document: document);
    final scrollController = EditorScrollController(editorState: editorState);

    _transactionSub = editorState.transactionStream.listen((_) {
      _onDocumentChanged();
    });

    setState(() {
      _editorState = editorState;
      _scrollController = scrollController;
      if (setLoading) {
        _isLoading = true;
      } else {
        _isLoading = false;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
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
    final markdown = documentToMarkdown(
      state.document,
      customParsers: const [_ImageNodeParserWithBlankLines()],
    );
    if (markdown.trim().isEmpty) return '';
    return _fixUnbalancedInlineMarkers(markdown);
  }

  /// 修复 markdown 中有问题的 `~~` 删除线标记
  ///
  /// AppFlowy 的 DeltaMarkdownEncoder 的两类问题：
  /// 1. 相邻 TextInsert 的 `~~~~`（关闭+开启）→ 直接移除以合并
  /// 2. 含换行的 TextInsert 导致 `~~` 跨行（GFM 不支持）→
  ///    将跨行 `~~...~~` 拆分为每行独立的 `~~line~~`
  static String _fixUnbalancedInlineMarkers(String markdown) {
    var result = markdown;

    // 合并相邻删除线：~~text1~~~~text2~~ → ~~text1text2~~
    while (result.contains('~~~~')) {
      result = result.replaceAll('~~~~', '');
    }

    // 修复跨行 ~~：跟踪状态，确保每行独立配对
    final lines = result.split('\n');
    final fixed = <String>[];
    var inCrossLine = false;

    for (var line in lines) {
      final count = '~~'.allMatches(line).length;

      if (inCrossLine) {
        if (count.isOdd) {
          // 找到另一半闭合 ~~，在行首补开启 ~~
          line = '~~$line';
          inCrossLine = false;
        } else if (count == 0 && line.trim().isNotEmpty) {
          // 中间行无 ~~，整行包裹
          line = '~~$line~~';
        }
        // count 为偶数且 >0：行内自身已平衡，不额外处理
      } else {
        if (count.isOdd) {
          // 开启了跨行 ~~，在行尾补闭合 ~~
          line = '$line~~';
          inCrossLine = true;
        }
      }

      fixed.add(line);
    }
    return fixed.join('\n');
  }

  /// 设置 Markdown 内容
  set content(String markdown) {
    final document = _editableDocumentFromMarkdown(markdown);
    _applyDocument(document, setLoading: false);
  }

  /// 切换工具栏显示
  void toggleToolbar() {
    setState(() {
      _showToolbar = !_showToolbar;
    });
  }

  /// 获取 EditorState（供外部调用格式化方法）
  EditorState? get editorState => _editorState;

  /// 将焦点移到编辑器并把光标放在文档开头
  void requestFocus() {
    _focusNode.requestFocus();
    final es = _editorState;
    if (es != null && es.document.root.children.isNotEmpty) {
      final first = es.document.root.children.first;
      es.updateSelectionWithReason(
        Selection.collapsed(Position(path: first.path, offset: 0)),
        reason: SelectionUpdateReason.uiEvent,
      );
    }
  }

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

  void _handleRightClick(BuildContext context, Offset globalPosition) {
    final es = _editorState;
    if (es == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      NotePriority.showPriorityMenu(context, globalPosition, es);
    });
  }

  @override
  void dispose() {
    _transactionSub?.cancel();
    _scrollController?.dispose();
    _editorState?.dispose();
    _focusNode.dispose();
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
      padding: EdgeInsets.zero,
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
          toolbarElevation: 0,
        ),
        toolbarBuilder: _buildConstrainedToolbar,
        child: Listener(
          onPointerDown: (event) {
            if (event.buttons == kSecondaryMouseButton) {
              _handleRightClick(context, event.position);
            }
          },
          child: AppFlowyEditor(
            editorState: editorState,
            editorScrollController: scrollController,
            editorStyle: _buildEditorStyle(context),
            blockComponentBuilders: _buildBlockComponentBuilders(),
            characterShortcutEvents: _buildCharacterShortcuts(),
            commandShortcutEvents: _buildCommandShortcuts(),
            autoFocus: true,
            focusNode: _focusNode,
          ),
        ),
      ),
    );
  }

  /// 自定义 FloatingToolbar 定位，防止工具栏超出右边界
  ///
  /// AppFlowy 默认实现将工具栏定位在选区的全局 left 坐标处（root overlay），
  /// 当编辑器位于右侧面板时，选区全局 left 值偏大，工具栏会溢出屏幕右侧。
  /// 这里将工具栏水平位置钳制在编辑器范围内。
  Widget _buildConstrainedToolbar(
    BuildContext context,
    Widget child,
    VoidCallback onDismiss,
    bool isMetricsChanged,
  ) {
    final es = _editorState;
    if (es == null) return const SizedBox.shrink();

    final rects = es.selectionRects();
    if (rects.isEmpty) return const SizedBox.shrink();

    final editorBox = es.renderBox;
    if (editorBox == null) return const SizedBox.shrink();

    final editorOffset = editorBox.localToGlobal(Offset.zero);
    final editorSize = editorBox.size;

    final visibleRects = rects.where((r) => r.top >= editorOffset.dy);
    if (visibleRects.isEmpty) return const SizedBox.shrink();
    final rect = visibleRects.reduce((a, b) => a.top <= b.top ? a : b);

    const toolbarHeight = 32.0;
    final topY =
        rect.top >= toolbarHeight ? rect.top - toolbarHeight : rect.bottom;

    final screenWidth = MediaQuery.of(context).size.width;

    final availableWidth = max(200.0, min(editorSize.width, screenWidth - editorOffset.dx - 8));

    return Positioned(
      top: max(0, topY),
      left: editorOffset.dx,
      child: Container(
        width: availableWidth,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: _HorizontalScrollToolbar(child: child),
      ),
    );
  }

  /// 构建编辑器样式
  EditorStyle _buildEditorStyle(BuildContext context) {
    return EditorStyle.desktop(
      padding: const EdgeInsets.only(
        left: AmberDimens.spacingMd,
        right: 64,
      ),
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

    // 图片：支持点击放大预览
    builders[ImageBlockKeys.type] = ClickableImageBlockComponentBuilder(
      configuration: compactConfig,
    );

    // 统一通过外部包装来挂载左侧优先级悬浮图标
    final wrappedBuilders = <String, BlockComponentBuilder>{};
    for (final entry in builders.entries) {
      wrappedBuilders[entry.key] = _PriorityWrapperBuilder(entry.value);
    }
    return wrappedBuilders;
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
      // 修复：当光标在图片后第一个字符处时，左箭头应能落在图片末尾
      _buildArrowLeftOverImageCommand(),
      // 修复：当光标在图片上/图片前后时，右箭头不应抛错
      _buildArrowRightOverImageCommand(),
      // 自定义粘贴命令放在前面，优先匹配
      _buildPasteImageCommand(),
      ...filtered,
    ];
  }

  CommandShortcutEvent _buildArrowLeftOverImageCommand() {
    return CommandShortcutEvent(
      key: 'move cursor left over image block',
      getDescription: () => 'Arrow-left over image block',
      command: 'arrow left',
      handler: (editorState) {
        final selection = editorState.selection;
        if (selection == null || !selection.isCollapsed) {
          return KeyEventResult.ignored;
        }

        final node = editorState.getNodeAtPath(selection.end.path);
        if (node == null) return KeyEventResult.ignored;

        // Case 1: 当前选中的是图片块。AppFlowy 默认 arrow-left 会对 delta==null 抛错；
        // 我们直接把光标移动到上一可选节点末尾，避免 UnimplementedError。
        if (node.type == ImageBlockKeys.type || node.delta == null) {
          final prevEnd = node
              .previousNodeWhere((e) => e.selectable != null)
              ?.selectable
              ?.end();
          if (prevEnd != null) {
            editorState.updateSelectionWithReason(
              Selection.collapsed(prevEnd),
              reason: SelectionUpdateReason.uiEvent,
            );
            return KeyEventResult.handled;
          }
          return KeyEventResult.handled;
        }

        // 只在“当前块的最开头”处理，否则走默认行为
        if (selection.endIndex != 0) {
          return KeyEventResult.ignored;
        }

        // 段落/列表项开头：如果前一个 block 是图片，让光标落在图片末尾
        final previous = node.previous;
        if (previous == null || previous.type != ImageBlockKeys.type) {
          return KeyEventResult.ignored;
        }

        final pos = previous.selectable?.end() ??
            Position(path: previous.path, offset: 1);
        editorState.updateSelectionWithReason(
          Selection.collapsed(pos),
          reason: SelectionUpdateReason.uiEvent,
        );
        return KeyEventResult.handled;
      },
    );
  }

  CommandShortcutEvent _buildArrowRightOverImageCommand() {
    return CommandShortcutEvent(
      key: 'move cursor right over image block',
      getDescription: () => 'Arrow-right over image block',
      command: 'arrow right',
      handler: (editorState) {
        final selection = editorState.selection;
        if (selection == null || !selection.isCollapsed) {
          return KeyEventResult.ignored;
        }

        final node = editorState.getNodeAtPath(selection.end.path);
        if (node == null) return KeyEventResult.ignored;

        // Case 1: 当前选中的是图片块（或任何 delta==null 的块）
        // 默认 arrow-right 会对 delta==null 抛错；直接移动到下一个可选节点开头。
        if (node.type == ImageBlockKeys.type || node.delta == null) {
          final nextStart = node
              .nextNodeWhere((e) => e.selectable != null)
              ?.selectable
              ?.start();
          if (nextStart != null) {
            editorState.updateSelectionWithReason(
              Selection.collapsed(nextStart),
              reason: SelectionUpdateReason.uiEvent,
            );
            return KeyEventResult.handled;
          }
          return KeyEventResult.handled;
        }

        // Case 2: 光标在文本块末尾，且下一个 block 是图片：让光标落在图片开头
        final deltaLength = node.delta?.length ?? 0;
        final isAtEnd = selection.endIndex >= deltaLength;
        if (isAtEnd) {
          final next = node.next;
          if (next != null && next.type == ImageBlockKeys.type) {
            final pos = next.selectable?.start() ??
                Position(path: next.path, offset: 0);
            editorState.updateSelectionWithReason(
              Selection.collapsed(pos),
              reason: SelectionUpdateReason.uiEvent,
            );
            return KeyEventResult.handled;
          }
        }

        return KeyEventResult.ignored;
      },
    );
  }

  /// 构建粘贴图片命令
  ///
  /// 逻辑：
  /// 1. 先检查剪切板是否有图片
  /// 2. 有图片则保存到本地并插入 Image Block（立刻预览）
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
                final transaction = editorState.transaction;
                final node =
                    editorState.getNodeAtPath(currentSelection.start.path);
                final insertedImage = imageNode(url: imagePath);

                if (node == null) return;

                final delta = node.delta;
                final isEmptyTextNode =
                    delta != null && delta.toPlainText().trim().isEmpty;

                // 空段落：替换为图片块，并在后面补一个空段落继续输入
                if (node.type == ParagraphBlockKeys.type &&
                    isEmptyTextNode &&
                    currentSelection.startIndex == 0) {
                  transaction.insertNode(currentSelection.end.path.next, insertedImage);
                  transaction.deleteNode(node);
                  transaction.insertNode(
                    currentSelection.end.path.next,
                    paragraphNode(),
                  );
                  transaction.afterSelection = Selection.collapsed(
                    Position(path: currentSelection.end.path.next, offset: 0),
                  );
                } else {
                  // 非空文本/列表等：把图片块插到当前块后面，不打断当前输入
                  transaction.insertNode(currentSelection.end.path.next, insertedImage);
                  transaction.afterSelection = currentSelection;
                }
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
            final nodes = htmlToDocument(html).root.children.toList();
            if (nodes.isNotEmpty) {
              if (text != null && text.isNotEmpty) {
                await _insertTextOrLink(editorState, text);
              }
              return;
            }
          }
          if (text != null && text.isNotEmpty) {
            await _insertTextOrLink(editorState, text);
          }
        }();

        return KeyEventResult.handled;
      },
    );
  }

  /// 粘贴文本时自动检测 URL 并以链接样式插入
  Future<void> _insertTextOrLink(EditorState state, String text) async {
    final trimmed = text.trim();
    if (_looksLikeUrl(trimmed)) {
      final sel = state.selection;
      if (sel != null && sel.isCollapsed) {
        final node = state.getNodeAtPath(sel.start.path);
        if (node != null && node.delta != null) {
          final transaction = state.transaction;
          transaction.insertText(
            node,
            sel.start.offset,
            trimmed,
            attributes: {'href': trimmed},
          );
          await state.apply(transaction);
          return;
        }
      }
    }
    await state.insertTextAtCurrentSelection(text);
  }

  static bool _looksLikeUrl(String text) {
    if (text.isEmpty || text.contains('\n')) return false;
    final uri = Uri.tryParse(text);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  /// 获取有序列表的序号
  /// 通过遍历前面的兄弟节点来计算当前节点的序号。
  ///
  /// 注意：AppFlowy 的 numbered_list 节点支持 `NumberedListBlockKeys.number`
  /// 作为“起始编号”。例如用户输入 `4. ` 作为一个新列表的第一项时，
  /// 该属性会被写入为 4；渲染时必须优先尊重这个起始值，而不是强制从 1 开始。
  int _getNumberedListIndex(Node node) {
    // 支持“在列表中间插入图片/分割线等块”后继续编号：
    // 把 image 视为透明分隔符，向上回溯最近的 numbered_list 来确定序号。
    Node? previous = node.previous;
    while (previous != null &&
        previous.type != NumberedListBlockKeys.type &&
        previous.type == ImageBlockKeys.type) {
      previous = previous.previous;
    }

    // 如果上一条不是有序列表（且不是透明块），则这是一个新的列表起点
    if (previous == null || previous.type != NumberedListBlockKeys.type) {
      return (node.attributes[NumberedListBlockKeys.number] as int?) ?? 1;
    }

    int level = 1;
    int? startNumber;
    while (previous != null) {
      if (previous.type == NumberedListBlockKeys.type) {
        startNumber = previous.attributes[NumberedListBlockKeys.number] as int?;
        level++;
        previous = previous.previous;
        continue;
      }
      if (previous.type == ImageBlockKeys.type) {
        previous = previous.previous;
        continue;
      }
      break;
    }

    if (startNumber != null) return startNumber + level - 1;
    return level;
  }
}

/// 横向可滚动工具栏容器
///
/// - 鼠标垂直滚轮 → 转换为横向滚动
/// - 触控板横向滑动 → 原生支持
/// - 右侧渐变遮罩提示可滚动
class _HorizontalScrollToolbar extends StatefulWidget {
  final Widget child;
  const _HorizontalScrollToolbar({required this.child});

  @override
  State<_HorizontalScrollToolbar> createState() =>
      _HorizontalScrollToolbarState();
}

class _HorizontalScrollToolbarState extends State<_HorizontalScrollToolbar> {
  final _controller = ScrollController();
  bool _showFade = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    final atEnd = _controller.position.pixels >=
        _controller.position.maxScrollExtent - 4;
    if (atEnd == _showFade) setState(() => _showFade = !atEnd);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent && event.scrollDelta.dy != 0) {
          final pos = _controller.position;
          final target = (pos.pixels + event.scrollDelta.dy)
              .clamp(pos.minScrollExtent, pos.maxScrollExtent);
          _controller.jumpTo(target);
        }
      },
      child: Stack(
        children: [
          SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: widget.child,
          ),
          if (_showFade)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.85),
                        Colors.white,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageNodeParserWithBlankLines extends NodeParser {
  const _ImageNodeParserWithBlankLines();

  @override
  String get id => ImageBlockKeys.type;

  @override
  String transform(Node node, DocumentMarkdownEncoder? encoder) {
    final url = node.attributes[ImageBlockKeys.url];
    if (url == null) return '';

    // AppFlowy 的默认 ImageNodeParser 不带换行，多个 block 会被拼接在一起，
    // 导致 markdown 重新解析时图片无法被识别为独立 block（从而“重开后图片不见”）。
    // 这里强制在图片前后加空行，确保 markdown parser 会生成独立的 <p><img/></p>。
    final prefix = node.previous == null ? '' : '\n\n';
    final suffix = node.next == null ? '' : '\n\n';
    return '$prefix![]($url)$suffix';
  }
}

/// 统一的左侧悬浮优先级图标包装器
///
/// 通过重写 [BlockComponentBuilder] 实现在原有段落、列表上附加悬浮（Positioned）渲染的优先级图标，
/// 而不影响底层引擎对光标和 inline delta 文字本身的处理。
class _PriorityWrapperBuilder extends BlockComponentBuilder {
  final BlockComponentBuilder baseBuilder;
  _PriorityWrapperBuilder(this.baseBuilder);

  @override
  BlockComponentConfiguration get configuration => baseBuilder.configuration;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    return _PriorityWrapperWidget(
      baseBuilder.build(blockComponentContext),
      key: blockComponentContext.node.key,
    );
  }

  @override
  BlockComponentValidate get validate => baseBuilder.validate;
}

class _PriorityWrapperWidget extends StatelessWidget with BlockComponentWidget {
  final BlockComponentWidget childWidget;

  const _PriorityWrapperWidget(this.childWidget, {super.key});

  @override
  bool get showActions => childWidget.showActions;

  @override
  Node get node => childWidget.node;

  @override
  BlockComponentConfiguration get configuration => childWidget.configuration;

  @override
  BlockComponentActionBuilder? get actionBuilder => childWidget.actionBuilder;

  @override
  BlockComponentActionTrailingBuilder? get actionTrailingBuilder => childWidget.actionTrailingBuilder;

  @override
  Widget build(BuildContext context) {
    // 解析当前这段是否有优先级，如果有，则在左侧悬挂图标
    final priority = NotePriority.getPriority(node);
    
    // 如果没有或不是文本行（或者图片块之类的没有标号），走默认渲染
    if (priority <= 0) {
      return childWidget;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        childWidget,
        Positioned(
          right: -50,
          top: -4,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: NotePriority.color(priority).withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/icons/priority_$priority.png',
                fit: BoxFit.cover,
                errorBuilder: (_, e, s) => const SizedBox(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

