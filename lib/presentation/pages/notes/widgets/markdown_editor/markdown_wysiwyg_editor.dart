import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/constants/constants.dart';
import 'editor_toolbar.dart';
import 'heading_indicator.dart';
import 'line_plus_menu.dart';
import 'markdown_editor_controller.dart';
import 'slash_command_menu.dart';

/// Markdown 所见即所得编辑器
///
/// 设计哲学:
/// - 基于原生 TextField 实现，性能优异
/// - 左侧显示行首菜单和标题层级指示器
/// - 底部固定工具栏，支持常用格式化操作
/// - 支持快捷键（Cmd+B 粗体，Cmd+I 斜体等）
/// - 链接自动高亮可点击
class MarkdownWysiwygEditor extends StatefulWidget {
  /// 初始内容
  final String initialContent;

  /// 内容变化回调
  final ValueChanged<String>? onChanged;

  /// 是否只读
  final bool readOnly;

  /// 是否显示工具栏
  final bool showToolbar;

  /// 关联笔记回调
  final VoidCallback? onLinkNoteTap;

  /// 关联任务回调
  final VoidCallback? onLinkTaskTap;

  /// 附件回调
  final VoidCallback? onAttachmentTap;

  /// 标签回调
  final VoidCallback? onTagsTap;

  /// 提示文字
  final String hintText;

  const MarkdownWysiwygEditor({
    super.key,
    this.initialContent = '',
    this.onChanged,
    this.readOnly = false,
    this.showToolbar = true,
    this.onLinkNoteTap,
    this.onLinkTaskTap,
    this.onAttachmentTap,
    this.onTagsTap,
    this.hintText = '开始输入内容，或使用 / 快速插入...',
  });

  @override
  State<MarkdownWysiwygEditor> createState() => MarkdownWysiwygEditorState();
}

class MarkdownWysiwygEditorState extends State<MarkdownWysiwygEditor> {
  late MarkdownEditorController _controller;
  late FocusNode _focusNode;
  late ScrollController _scrollController;
  bool _isFullscreen = false;
  bool _showToolbar = false;

  /// 当前光标所在行的标题级别（0 = 非标题）
  int _currentHeadingLevel = 0;

  /// 当前光标的 Y 坐标（精确位置）
  double _cursorY = 0;

  /// 文本区域的实际宽度（用于 TextPainter 计算换行）
  double _textAreaWidth = 1000;

  /// 是否按住了 Cmd/Ctrl 键（用于链接点击检测）
  bool _isModifierPressed = false;

  /// 上一次文本长度，用于检测是否输入了新字符
  int _previousTextLength = 0;

  /// 获取当前内容（供外部调用）
  String get content => _controller.text;

  /// 设置内容（供外部调用）
  set content(String value) {
    _controller.text = value;
  }

  /// 获取编辑器控制器（供外部调用格式化操作）
  MarkdownEditorController get editorController => _controller;

  /// 显示/隐藏工具栏
  void toggleToolbar() {
    setState(() {
      _showToolbar = !_showToolbar;
    });
  }

  /// 显示工具栏
  void showToolbar() {
    setState(() {
      _showToolbar = true;
    });
  }

  /// 隐藏工具栏
  void hideToolbar() {
    setState(() {
      _showToolbar = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _controller = MarkdownEditorController(text: widget.initialContent);
    _controller.onCursorChanged = _onCursorChanged;
    _controller.addListener(_onTextChanged);
    _previousTextLength = widget.initialContent.length;
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    // 监听滚动以更新悬浮组件位置
    _scrollController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 文本变化监听，检测斜线命令
  void _onTextChanged() {
    final currentLength = _controller.text.length;
    final cursorPos = _controller.selection.baseOffset;

    // 检测是否输入了 `/`（文本增加1个字符且光标前是 `/`）
    if (currentLength == _previousTextLength + 1 &&
        cursorPos > 0 &&
        cursorPos <= _controller.text.length &&
        _controller.text[cursorPos - 1] == '/') {
      // 延迟一帧确保渲染完成后再显示菜单
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showSlashCommandMenu();
        }
      });
    }

    _previousTextLength = currentLength;
  }

  /// 显示斜线命令菜单
  void _showSlashCommandMenu() {
    // 计算光标在屏幕上的位置
    final cursorRect = _getCursorRect();
    if (cursorRect == null) return;

    SlashCommandMenu.show(
      context: context,
      controller: _controller,
      cursorRect: cursorRect,
      onLinkNoteTap: widget.onLinkNoteTap,
      onLinkTaskTap: widget.onLinkTaskTap,
      onAttachmentTap: widget.onAttachmentTap,
      onTagsTap: widget.onTagsTap,
    );
  }

  /// 获取光标在屏幕上的位置（全局坐标）
  Rect? _getCursorRect() {
    final cursorPos = _controller.selection.baseOffset;
    if (cursorPos < 0) return null;

    try {
      // 使用 TextPainter 计算光标位置
      final textPainter = TextPainter(
        text: TextSpan(
          text: _controller.text,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AmberColors.textPrimary,
          ),
        ),
        textDirection: TextDirection.ltr,
        strutStyle: _strutStyle,
      );
      textPainter.layout(maxWidth: _textAreaWidth);

      // 获取光标位置（相对于文本区域）
      final caretOffset = textPainter.getOffsetForCaret(
        TextPosition(offset: cursorPos),
        Rect.zero,
      );

      // 获取编辑器在屏幕上的位置
      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) return null;

      final editorOffset = renderBox.localToGlobal(Offset.zero);

      // 考虑滚动偏移和左侧 padding
      final scrollOffset =
          _scrollController.hasClients ? _scrollController.offset : 0.0;
      const leftPadding = AmberDimens.spacingMd;
      const topPadding = 4.0; // TextField contentPadding.vertical

      // 计算光标在屏幕上的全局位置
      final globalX = editorOffset.dx + leftPadding + caretOffset.dx;
      final globalY =
          editorOffset.dy + topPadding + caretOffset.dy - scrollOffset;

      // 返回光标位置的矩形（宽度为0，高度为行高）
      const cursorHeight = 21.0; // 普通行高
      return Rect.fromLTWH(globalX, globalY, 0, cursorHeight);
    } catch (e) {
      return null;
    }
  }

  /// 光标位置变化处理
  void _onCursorChanged() {
    // 更新当前行的标题级别
    final newLevel = _controller.currentLineInfo?.headingLevel ?? 0;

    // 计算光标 Y 位置
    // 注意：在 _onCursorChanged 中我们没有 LayoutBuilder 的 constraints，
    // 但我们需要更新状态。这里使用默认宽度或上次记录的宽度。
    // 为了简化，我们改回无参数调用，内部使用默认宽度。
    // 实际渲染时，HeadingIndicator 会使用 LayoutBuilder 计算的准确位置（其实是 build 时重新计算吗？不，build 时依靠 _cursorY 状态）
    // 这是一个架构上的小妥协：光标位置状态更新依赖估算宽度，但对单行文本垂直位置影响极小。
    final newCursorY = _calculateCursorY();

    // 只有值变化时才 setState
    if (newLevel != _currentHeadingLevel || newCursorY != _cursorY) {
      setState(() {
        _currentHeadingLevel = newLevel;
        _cursorY = newCursorY;
      });
    }

    // 通知内容变化
    widget.onChanged?.call(_controller.text);
  }

  /// 统一的 StrutStyle，确保 TextField 和 TextPainter 渲染一致
  /// 注意：不要使用 forceStrutHeight: true，因为标题行高不同，强制行高会导致光标位置计算严重偏差（偏小），
  /// 进而导致后续行的指示器位置偏高。
  static const _strutStyle = StrutStyle(fontSize: 14, height: 1.5, leading: 0);

  /// 计算光标的精确 Y 坐标
  /// 使用 controller 的 buildTextSpan 获取实际渲染的 TextSpan，确保位置计算准确
  double _calculateCursorY() {
    final lineInfo = _controller.currentLineInfo;
    if (lineInfo == null) return 0;

    try {
      // 使用 controller 的 buildTextSpan 获取实际渲染的 TextSpan
      // 这样可以确保标题等特殊样式的位置计算准确
      final textSpan = _controller.buildTextSpan(
        context: context,
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: AmberColors.textPrimary,
        ),
        withComposing: false,
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        strutStyle: _strutStyle,
      );

      // 使用实际文本区域宽度（关键！）
      textPainter.layout(maxWidth: _textAreaWidth);

      // 获取当前行开头位置的光标位置
      final caretOffset = textPainter.getOffsetForCaret(
        TextPosition(offset: lineInfo.lineStart),
        Rect.zero,
      );

      return caretOffset.dy;
    } catch (e) {
      // 降级：简单按行数计算（不考虑自动换行）
      final text = _controller.text;
      final beforeCursor = text.substring(0, lineInfo.lineStart);
      final lineCount = '\n'.allMatches(beforeCursor).length;
      return lineCount * 21.0; // 普通行高 21px
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyEvent,
      child: Shortcuts(
        shortcuts: _buildShortcuts(),
        child: Actions(
          actions: _buildActions(),
          child: Focus(
            autofocus: true,
            child: _isFullscreen
                ? _buildFullscreenEditor()
                : _buildNormalEditor(),
          ),
        ),
      ),
    );
  }

  /// 处理键盘事件，检测 Cmd/Ctrl 键状态
  void _handleKeyEvent(KeyEvent event) {
    final isDown = event is KeyDownEvent;
    final isUp = event is KeyUpEvent;

    if (event.logicalKey == LogicalKeyboardKey.metaLeft ||
        event.logicalKey == LogicalKeyboardKey.metaRight ||
        event.logicalKey == LogicalKeyboardKey.controlLeft ||
        event.logicalKey == LogicalKeyboardKey.controlRight) {
      setState(() {
        _isModifierPressed = isDown
            ? true
            : (isUp ? false : _isModifierPressed);
      });
    }
  }

  /// 构建普通编辑器（非全屏）
  Widget _buildNormalEditor() {
    return Column(
      children: [
        // 编辑区域
        Expanded(
          child: _buildEditorArea(),
        ),
        // 底部工具栏（点击 A 图标后显示）
        if (_showToolbar && !widget.readOnly) _buildToolbar(),
      ],
    );
  }

  /// 构建全屏编辑器
  Widget _buildFullscreenEditor() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // 顶部操作栏
            _buildFullscreenHeader(),
            // 编辑区域
            Expanded(
              child: _buildEditorArea(),
            ),
            // 底部工具栏（全屏模式始终显示）
            if (!widget.readOnly) _buildToolbar(),
          ],
        ),
      ),
    );
  }

  /// 构建全屏模式顶部栏
  Widget _buildFullscreenHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AmberDimens.spacingMd,
        vertical: AmberDimens.spacingSm,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AmberColors.divider),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _isFullscreen = false),
            tooltip: '退出全屏',
          ),
          const Spacer(),
          Text(
            '全屏编辑',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AmberColors.textPrimary,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48), // 占位，保持标题居中
        ],
      ),
    );
  }
  Widget _buildEditorArea() {
    // TextField contentPadding.vertical = 4，文字从这个位置开始
    const textFieldPaddingTop = 4.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 计算文本区域实际可用宽度 = 总宽度 - 左padding(16)
        final textMaxWidth = constraints.maxWidth - AmberDimens.spacingMd;

        // 更新存储的宽度值（给 _calculateCursorY 用）
        _textAreaWidth = textMaxWidth;
        // 直接用当前宽度计算光标位置（不依赖缓存的 _cursorY）
        final cursorY = _calculateCursorY();

        // 考虑滚动偏移量
        final scrollOffset = _scrollController.hasClients
            ? _scrollController.offset
            : 0.0;

        // 从 LineInfo 获取当前行的渲染参数
        final lineInfo = _controller.currentLineInfo;
        final verticalOffset = lineInfo?.indicatorVerticalOffset ?? 0.0;

        // 最终 Top = TextField padding + 光标Y位置 + 垂直居中偏移 - 滚动偏移
        final topPosition =
            textFieldPaddingTop + cursorY + verticalOffset - scrollOffset;

        return GestureDetector(
          onTap: () {
            _focusNode.requestFocus();
          },
          onTapUp: _isModifierPressed ? _handleModifierClick : null,
          child: Stack(
            children: [
              // 编辑器主体（带左边距）
              Container(
                color: Colors.white,
                padding: const EdgeInsets.only(left: AmberDimens.spacingMd),
                child: _buildTextField(),
              ),
              // 左侧标题级别指示器
              if (_currentHeadingLevel > 0 &&
                  _controller.currentLineInfo != null)
                Positioned(
                  left: 2,
                  top: topPosition,
                  child: HeadingIndicator(
                    lineInfo: _controller.currentLineInfo!,
                    controller: _controller,
                  ),
                ),
              // 空行时显示加号菜单（排除引用行）
              if (_currentHeadingLevel == 0 &&
                  _controller.currentLineInfo != null &&
                  _controller.currentLineInfo!.canShowPlusMenu &&
                  _controller.currentLineInfo!.isQuote != true)
                Positioned(
                  left: 0,
                  top: topPosition,
                  child: LinePlusMenu(
                    controller: _controller,
                    onLinkNoteTap: widget.onLinkNoteTap,
                    onLinkTaskTap: widget.onLinkTaskTap,
                    onAttachmentTap: widget.onAttachmentTap,
                    onTagsTap: widget.onTagsTap,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 处理 Cmd/Ctrl + 点击（用于打开链接）
  /// 检测点击位置是否在链接上，如果是则打开链接
  void _handleModifierClick(TapUpDetails details) {
    // 获取当前光标位置的文本
    final cursorPos = _controller.selection.baseOffset;
    if (cursorPos < 0) return;

    // 在光标附近查找链接
    final linkUrl = _findLinkAtPosition(cursorPos);
    if (linkUrl != null) {
      _launchUrl(linkUrl);
    }
  }

  /// 在指定位置查找链接
  /// 返回链接 URL，如果没有找到返回 null
  /// 支持 Markdown 链接 [文字](url) 和纯 URL（https://...）
  String? _findLinkAtPosition(int position) {
    final text = _controller.text;
    if (text.isEmpty) return null;

    // Markdown 链接：[文字](url)
    final markdownLinkPattern = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
    for (final match in markdownLinkPattern.allMatches(text)) {
      if (position >= match.start && position <= match.end) {
        return match.group(2); // 返回 URL
      }
    }

    // 纯 URL：https://... 或 http://...
    final urlPattern = RegExp(r'https?://[^\s\u4e00-\u9fa5]+');
    for (final match in urlPattern.allMatches(text)) {
      if (position >= match.start && position <= match.end) {
        return match.group(0); // 返回整个 URL
      }
    }

    return null;
  }

  /// 打开链接（跳转浏览器）
  Future<void> _launchUrl(String url) async {
    // 处理内部链接
    if (url.startsWith('note:') || url.startsWith('task:')) {
      // TODO: 内部链接跳转
      return;
    }

    // 外部链接，跳转浏览器
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// 构建文本输入框
  Widget _buildTextField() {
    // 根据当前行的标题级别动态调整光标高度
    // 这样光标才能和标题文字的高度匹配
    final cursorHeight = _getCursorHeightForCurrentLine();

    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      readOnly: widget.readOnly,
      maxLines: null,
      expands: true,
      scrollController: _scrollController,
      textAlignVertical: TextAlignVertical.top,
      strutStyle: _strutStyle, // 使用统一的 StrutStyle
      cursorHeight: cursorHeight, // 动态光标高度
      cursorWidth: 2, // 光标宽度固定 2px
      cursorColor: AmberColors.primary, // 琥珀色光标
      style: const TextStyle(
        fontSize: 14,
        height: 1.5, // 紧凑行高，避免间距过大
        color: AmberColors.textPrimary,
      ),
      decoration: InputDecoration(
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        filled: false,
        hintText: widget.hintText,
        hintStyle: TextStyle(color: AmberColors.textDisabled),
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        isCollapsed: true,
      ),
      onTap: () {
        // 防止点击TextField也触发GestureDetector的onTap
      },
    );
  }

  /// 获取光标高度（固定值）
  /// 光标高度始终保持一致，不随标题级别变化
  double _getCursorHeightForCurrentLine() {
    // 从 LineInfo 获取标准光标高度（统一 18px）
    return _controller.currentLineInfo?.cursorHeight ?? 18.0;
  }

  /// 构建底部工具栏
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.all(AmberDimens.spacingMd),
      child: Center(
        child: EditorToolbar(
          controller: _controller,
          isFullscreen: _isFullscreen,
          onFullscreenToggle: () => setState(() => _isFullscreen = !_isFullscreen),
          onAttachmentTap: widget.onAttachmentTap ?? _showAttachmentNotSupported,
          onLinkNoteTap: widget.onLinkNoteTap,
          onLinkTaskTap: widget.onLinkTaskTap,
        ),
      ),
    );
  }

  /// 显示附件暂不支持提示
  void _showAttachmentNotSupported() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('附件功能暂不支持'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 构建快捷键映射
  Map<ShortcutActivator, Intent> _buildShortcuts() {
    return {
      // Cmd/Ctrl + B: 粗体
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.keyB,
      ): const _BoldIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyB,
      ): const _BoldIntent(),

      // Cmd/Ctrl + I: 斜体
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.keyI,
      ): const _ItalicIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyI,
      ): const _ItalicIntent(),

      // Cmd/Ctrl + K: 链接
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.keyK,
      ): const _LinkIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyK,
      ): const _LinkIntent(),

      // Cmd/Ctrl + U: 下划线
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.keyU,
      ): const _UnderlineIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyU,
      ): const _UnderlineIntent(),

      // Cmd/Ctrl + Shift + S: 删除线
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.shift,
        LogicalKeyboardKey.keyS,
      ): const _StrikethroughIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.shift,
        LogicalKeyboardKey.keyS,
      ): const _StrikethroughIntent(),
    };
  }

  /// 构建快捷键动作
  Map<Type, Action<Intent>> _buildActions() {
    return {
      _BoldIntent: CallbackAction<_BoldIntent>(
        onInvoke: (_) {
          _controller.toggleBold();
          return null;
        },
      ),
      _ItalicIntent: CallbackAction<_ItalicIntent>(
        onInvoke: (_) {
          _controller.toggleItalic();
          return null;
        },
      ),
      _LinkIntent: CallbackAction<_LinkIntent>(
        onInvoke: (_) {
          _showLinkDialog();
          return null;
        },
      ),
      _UnderlineIntent: CallbackAction<_UnderlineIntent>(
        onInvoke: (_) {
          _controller.toggleUnderline();
          return null;
        },
      ),
      _StrikethroughIntent: CallbackAction<_StrikethroughIntent>(
        onInvoke: (_) {
          _controller.toggleStrikethrough();
          return null;
        },
      ),
    };
  }

  /// 显示链接对话框
  void _showLinkDialog() {
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
              _controller.insertLink(displayText, urlController.text);
              Navigator.pop(context);
            },
            child: const Text('插入'),
          ),
        ],
      ),
    );
  }
}

// 快捷键 Intent 定义
class _BoldIntent extends Intent {
  const _BoldIntent();
}

class _ItalicIntent extends Intent {
  const _ItalicIntent();
}

class _LinkIntent extends Intent {
  const _LinkIntent();
}

class _UnderlineIntent extends Intent {
  const _UnderlineIntent();
}

class _StrikethroughIntent extends Intent {
  const _StrikethroughIntent();
}
