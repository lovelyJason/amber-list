import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/constants/constants.dart';
import '../../../providers/app_state.dart';
import '../../../../data/models/models.dart';
import '../../../providers/note_task_link_provider.dart';
import '../../../widgets/common/toast/toast_manager.dart';
import '../notes_provider.dart';
import 'markdown_editor/link_picker_dialog.dart';
import 'appflowy_markdown_editor.dart';
import 'embedded_task_card.dart';
import '../../../widgets/task_image_preview.dart';

/// 笔记详情编辑面板
///
/// 设计哲学：
/// - 类似 VSCode 的编辑器面板，支持快捷键保存（Cmd+S / Ctrl+S）
/// - 未保存状态通过圆点指示器提示
/// - 新建空笔记关闭时自动删除
class NoteDetailPanel extends ConsumerStatefulWidget {
  final Note note;
  final VoidCallback onClose;

  /// 是否为新建笔记（用于判断关闭时是否删除空笔记）
  final bool isNewNote;

  const NoteDetailPanel({
    super.key,
    required this.note,
    required this.onClose,
    this.isNewNote = false,
  });

  @override
  ConsumerState<NoteDetailPanel> createState() => _NoteDetailPanelState();
}

class _NoteDetailPanelState extends ConsumerState<NoteDetailPanel> {
  late TextEditingController _titleController;

  /// Markdown 编辑器的 Key，用于获取编辑器状态
  final GlobalKey<AppFlowyMarkdownEditorState> _editorKey = GlobalKey();

  /// 更多菜单按钮的 Key，用于定位弹出菜单位置
  final GlobalKey _moreButtonKey = GlobalKey();

  /// 是否有未保存的修改（类似 VSCode 文件未保存状态）
  bool _isDirty = false;

  /// 是否展开底部格式化工具栏
  bool _isToolbarExpanded = false;

  /// 记录初始内容，用于判断是否有变化
  late String _initialTitle;
  late String _initialContent;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _initialTitle = widget.note.title;
    _initialContent = widget.note.content;

    // 监听标题变化
    _titleController.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    super.dispose();
  }

  /// 标题变化时检查是否有修改
  void _onTitleChanged() {
    _checkDirtyState();
  }

  /// 内容变化时检查是否有修改（由编辑器回调触发）
  void _onContentChanged(String content) {
    _checkDirtyState();
  }

  /// 检查是否有未保存的修改
  void _checkDirtyState() {
    final currentTitle = _titleController.text;
    final currentContent = _editorKey.currentState?.content ?? _initialContent;
    final isDirty =
        currentTitle != _initialTitle || currentContent != _initialContent;

    if (isDirty != _isDirty) {
      setState(() {
        _isDirty = isDirty;
      });
    }
  }

  /// 判断笔记是否为空（标题为默认值且内容为空）
  bool _isEmptyNote() {
    final title = _titleController.text.trim();
    final content = _editorKey.currentState?.content.trim() ?? '';
    // 标题是默认的"新建笔记"且内容为空，视为空笔记
    return (title.isEmpty || title == '新建笔记') && content.isEmpty;
  }

  /// 关闭面板，如果是新建的空笔记则自动删除
  void _handleClose() {
    if (widget.isNewNote && _isEmptyNote()) {
      // 空笔记，静默删除不提示
      ref.read(notesProvider.notifier).deleteNote(widget.note.id);
    }
    widget.onClose();
  }

  /// 保存笔记（手动触发保存，同时更新标题和内容，不关闭编辑界面）
  ///
  /// 返回 true 表示保存成功，false 表示被阻止（内容保护触发）。
  bool _saveNote() {
    final content = _editorKey.currentState?.content ?? widget.note.content;

    if (_initialContent.length > 50 &&
        content.length < _initialContent.length * 0.3) {
      debugPrint(
        '[NoteDetailPanel] Content truncation detected! '
        'old=${_initialContent.length} new=${content.length}. '
        'Refusing to save.',
      );
      if (mounted) {
        ToastManager()
            .show(context, '检测到内容异常缩减，已阻止保存', type: ToastType.error);
      }
      return false;
    }

    final updatedNote = widget.note.copyWith(
      title: _titleController.text,
      content: content,
      updatedAt: DateTime.now(),
    );
    ref.read(notesProvider.notifier).updateNote(updatedNote);

    _initialTitle = _titleController.text;
    _initialContent = content;
    if (mounted) {
      setState(() => _isDirty = false);
      ToastManager().show(context, '已保存', type: ToastType.success);
    }
    return true;
  }

  /// 显示删除确认对话框
  Future<void> _showDeleteConfirmDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除笔记'),
        content: Text('确定要删除笔记"${widget.note.title}"吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              '取消',
              style: TextStyle(color: AmberColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(notesProvider.notifier).deleteNote(widget.note.id);
      widget.onClose();
    }
  }

  /// 显示更多菜单（删除等操作）
  ///
  /// 使用 GlobalKey 获取按钮的 RenderBox，确保菜单在按钮下方弹出
  void _showMoreMenu() {
    final RenderBox? button =
        _moreButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (button == null) return;

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    // 获取按钮在全局坐标系中的位置
    final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);

    // 菜单在按钮左下方弹出（避免超出屏幕右边界）
    final position = RelativeRect.fromLTRB(
      buttonPosition.dx - 100, // 向左偏移，让菜单不超出右边界
      buttonPosition.dy + button.size.height + 4, // 按钮下方 4px
      overlay.size.width - buttonPosition.dx - button.size.width,
      0,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('删除笔记', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'delete') {
        _showDeleteConfirmDialog();
      }
    });
  }

  /// 处理关联笔记（插入笔记链接到编辑器）
  void _handleLinkNote() async {
    final selectedNote = await showNoteLinkPicker(context);

    if (selectedNote != null &&
        selectedNote.id != widget.note.id &&
        _editorKey.currentState != null) {
      final controller = _editorKey.currentState!;
      final linkText = '[${selectedNote.title}](note:${selectedNote.id})';
      controller.content = '${controller.content}\n$linkText';
    }
  }

  /// 处理关联任务
  ///
  /// 弹出任务选择器，选择后：
  /// 1. 在数据库中创建关联关系
  /// 2. 在编辑器内容中插入任务链接文本
  void _handleLinkTask() async {
    final selectedTask = await showTaskLinkPicker(context);

    if (selectedTask != null && _editorKey.currentState != null) {
      // 创建数据库关联
      final repo = ref.read(noteTaskLinkRepositoryProvider);
      await repo.linkNoteToTask(widget.note.id, selectedTask.id);

      // 插入任务链接，格式：[任务标题](task:任务ID)
      final controller = _editorKey.currentState!;
      final linkText = '[${selectedTask.title}](task:${selectedTask.id})';
      controller.content = '${controller.content}\n$linkText';

      if (mounted) {
        ToastManager().show(context, '已关联任务', type: ToastType.success);
      }
    }
  }

  /// 斜线命令关联任务回调
  ///
  /// 弹出任务选择器，创建数据库关联，返回任务信息供编辑器插入链接
  Future<Map<String, String>?> _handleSlashLinkTask() async {
    final selectedTask = await showTaskLinkPicker(context);
    if (selectedTask == null) return null;

    // 创建数据库关联
    final repo = ref.read(noteTaskLinkRepositoryProvider);
    await repo.linkNoteToTask(widget.note.id, selectedTask.id);

    if (mounted) {
      ToastManager().show(context, '已关联任务', type: ToastType.success);
    }

    return {'id': selectedTask.id, 'title': selectedTask.title};
  }

  /// 处理附件（暂不支持）
  void _handleAttachment() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('附件功能暂不支持'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 处理标签
  void _handleTags() {
    // TODO: 实现标签选择/编辑功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('标签功能开发中'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 处理图片删除
  ///
  /// 删除图片文件后，更新编辑器内容（移除对应的 Markdown 图片语法）
  void _handleImageDeleted(String imagePath, String newContent) {
    final editorState = _editorKey.currentState;
    if (editorState != null) {
      editorState.content = newContent;
      _checkDirtyState();
      setState(() {}); // 刷新图片预览区域
    }
  }

  @override
  Widget build(BuildContext context) {
    // 使用 Shortcuts + Actions 实现 Cmd+S / Ctrl+S 保存快捷键
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS):
            const _SaveNoteIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS):
            const _SaveNoteIntent(),
      },
      child: Actions(
        actions: {
          _SaveNoteIntent: CallbackAction<_SaveNoteIntent>(
            onInvoke: (_) {
              _saveNote();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部
              _buildHeader(),
              // 内容区域
              Expanded(child: _buildContent()),
              // 图片预览区域（解析 Markdown 图片语法显示缩略图）
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AmberDimens.spacingMd,
                ),
                child: TaskImagePreview(
                  description: _editorKey.currentState?.content ?? widget.note.content,
                  onImageDeleted: _handleImageDeleted,
                ),
              ),
              // 关联任务列表
              _buildLinkedTasksSection(),
              // 底部固定按钮栏
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建头部工具栏
  Widget _buildHeader() {
    return DragToMoveArea(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AmberDimens.spacingLg,
          vertical: AmberDimens.spacingSm,
        ),
        child: Row(
          children: [
            // 左侧：未保存指示器（类似 VSCode 文件名旁的圆点）
            if (_isDirty)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                  color: AmberColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            if (_isDirty)
              Text(
                '未保存',
                style: TextStyle(
                  fontSize: 12,
                  color: AmberColors.textSecondary,
                ),
              ),
            const Spacer(),
            // 关闭按钮
            IconButton(
              onPressed: _handleClose,
              icon: const Icon(Icons.close, size: 20),
              color: AmberColors.textSecondary,
              tooltip: '关闭',
              visualDensity: VisualDensity.compact,
            ),
            // 保存并关闭按钮（对钩 = 保存 + 退出编辑界面）
            IconButton(
              onPressed: () {
                if (_saveNote()) widget.onClose();
              },
              icon: const Icon(Icons.check, size: 20),
              color: AmberColors.success,
              tooltip: '保存并关闭',
              visualDensity: VisualDensity.compact,
            ),
            // 置顶按钮
            IconButton(
              onPressed: () =>
                  ref.read(notesProvider.notifier).togglePin(widget.note.id),
              icon: Icon(
                widget.note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                size: 20,
              ),
              color: widget.note.isPinned
                  ? AmberColors.primary
                  : AmberColors.textSecondary,
              tooltip: widget.note.isPinned ? '取消置顶' : '置顶',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建内容区域
  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题区域（回车跳转到内容编辑器）
        TextField(
          controller: _titleController,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _editorKey.currentState?.requestFocus(),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.2,
            color: AmberColors.textPrimary,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            filled: false,
            fillColor: Colors.transparent,
            hoverColor: Colors.transparent,
            hintText: '笔记标题',
            hintStyle: TextStyle(color: AmberColors.textDisabled),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: AmberDimens.spacingMd,
              vertical: 0,
            ),
          ),
        ),
        const SizedBox(height: AmberDimens.spacingMd),
        // 标签区域
        if (widget.note.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AmberDimens.spacingMd,
            ),
            child: Wrap(
              spacing: 8,
              children: widget.note.tags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AmberColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AmberColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        const SizedBox(height: AmberDimens.spacingSm),
        // AppFlowy Markdown 编辑器
        Expanded(
          child: AppFlowyMarkdownEditor(
            key: _editorKey,
            initialContent: widget.note.content,
            showToolbar: true,
            onChanged: _onContentChanged,
            onLinkNoteTap: _handleLinkNote,
            onLinkTaskTap: _handleLinkTask,
            onSlashLinkTask: _handleSlashLinkTask,
            onAttachmentTap: _handleAttachment,
            onTagsTap: _handleTags,
          ),
        ),
      ],
    );
  }

  /// 构建关联任务区域
  ///
  /// 显示当前笔记关联的所有任务，支持取消关联
  Widget _buildLinkedTasksSection() {
    final linkedTasksAsync = ref.watch(linkedTasksProvider(widget.note.id));

    return linkedTasksAsync.when(
      data: (List<Task> tasks) {
        if (tasks.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AmberDimens.spacingMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(height: 1, color: AmberColors.divider),
              const SizedBox(height: AmberDimens.spacingSm),
              Row(
                children: [
                  const Icon(Icons.link, size: 14, color: AmberColors.textDisabled),
                  const SizedBox(width: 4),
                  Text(
                    '关联任务 (${tasks.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AmberColors.textDisabled,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ...tasks.map((task) => _buildLinkedTaskItem(task)),
              const SizedBox(height: AmberDimens.spacingSm),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  /// 构建单个关联任务项
  Widget _buildLinkedTaskItem(Task task) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: EmbeddedTaskCard(
        task: task,
        onTap: () => ref.read(appNavProvider.notifier).navigateToTask(task.id),
        onUnlink: () async {
          final repo = ref.read(noteTaskLinkRepositoryProvider);
          await repo.unlinkNoteFromTask(widget.note.id, task.id);
          if (mounted) {
            ToastManager().show(context, '已取消关联', type: ToastType.info);
          }
        },
      ),
    );
  }

  /// 构建底部工具栏
  ///
  /// 设计：右对齐，点击格式化按钮在上方弹出工具栏
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AmberDimens.spacingMd,
        vertical: AmberDimens.spacingSm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 展开时在上方显示格式化工具栏
          if (_isToolbarExpanded)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标题
                    IconButton(
                      onPressed: _showHeadingMenu,
                      icon: const Icon(Icons.title),
                      iconSize: 20,
                      color: AmberColors.textSecondary,
                      tooltip: '标题',
                      visualDensity: VisualDensity.compact,
                    ),
                    // 加粗
                    IconButton(
                      onPressed: () => _editorKey.currentState?.toggleBold(),
                      icon: const Icon(Icons.format_bold),
                      iconSize: 20,
                      color: AmberColors.textSecondary,
                      tooltip: '加粗',
                      visualDensity: VisualDensity.compact,
                    ),
                    // 斜体
                    IconButton(
                      onPressed: () => _editorKey.currentState?.toggleItalic(),
                      icon: const Icon(Icons.format_italic),
                      iconSize: 20,
                      color: AmberColors.textSecondary,
                      tooltip: '斜体',
                      visualDensity: VisualDensity.compact,
                    ),
                    _buildDivider(),
                    // 待办
                    IconButton(
                      onPressed: () =>
                          _editorKey.currentState?.formatTodoList(),
                      icon: const Icon(Icons.check_box_outlined),
                      iconSize: 20,
                      color: AmberColors.textSecondary,
                      tooltip: '待办',
                      visualDensity: VisualDensity.compact,
                    ),
                    // 无序列表
                    IconButton(
                      onPressed: () =>
                          _editorKey.currentState?.formatBulletList(),
                      icon: const Icon(Icons.format_list_bulleted),
                      iconSize: 20,
                      color: AmberColors.textSecondary,
                      tooltip: '无序列表',
                      visualDensity: VisualDensity.compact,
                    ),
                    // 有序列表
                    IconButton(
                      onPressed: () =>
                          _editorKey.currentState?.formatNumberedList(),
                      icon: const Icon(Icons.format_list_numbered),
                      iconSize: 20,
                      color: AmberColors.textSecondary,
                      tooltip: '有序列表',
                      visualDensity: VisualDensity.compact,
                    ),
                    _buildDivider(),
                    // 下划线
                    IconButton(
                      onPressed: () =>
                          _editorKey.currentState?.toggleUnderline(),
                      icon: const Icon(Icons.format_underlined),
                      iconSize: 20,
                      color: AmberColors.textSecondary,
                      tooltip: '下划线',
                      visualDensity: VisualDensity.compact,
                    ),
                    // 删除线
                    IconButton(
                      onPressed: () =>
                          _editorKey.currentState?.toggleStrikethrough(),
                      icon: const Icon(Icons.format_strikethrough),
                      iconSize: 20,
                      color: AmberColors.textSecondary,
                      tooltip: '删除线',
                      visualDensity: VisualDensity.compact,
                    ),
                    // 引用
                    IconButton(
                      onPressed: () => _editorKey.currentState?.formatQuote(),
                      icon: const Icon(Icons.format_quote),
                      iconSize: 20,
                      color: AmberColors.textSecondary,
                      tooltip: '引用',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
          // 底部固定按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 关联任务按钮
              IconButton(
                onPressed: _handleLinkTask,
                icon: const Icon(Icons.add_task_outlined),
                iconSize: 20,
                color: AmberColors.textSecondary,
                tooltip: '关联任务',
                visualDensity: VisualDensity.compact,
              ),
              // 格式化按钮
              IconButton(
                onPressed: () =>
                    setState(() => _isToolbarExpanded = !_isToolbarExpanded),
                icon: Icon(_isToolbarExpanded
                    ? Icons.text_format
                    : Icons.text_format_outlined),
                iconSize: 20,
                color: _isToolbarExpanded
                    ? AmberColors.primary
                    : AmberColors.textSecondary,
                tooltip: '格式化',
                visualDensity: VisualDensity.compact,
              ),
              // 更多菜单
              IconButton(
                key: _moreButtonKey,
                onPressed: _showMoreMenu,
                icon: const Icon(Icons.more_horiz),
                iconSize: 20,
                color: AmberColors.textSecondary,
                tooltip: '更多',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建工具栏分隔线
  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AmberColors.divider,
    );
  }

  /// 显示标题级别菜单
  void _showHeadingMenu() {
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    if (button == null) return;

    showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        100,
        button.size.height - 150,
        100,
        0,
      ),
      items: [
        const PopupMenuItem(value: 1, child: Text('标题 1')),
        const PopupMenuItem(value: 2, child: Text('标题 2')),
        const PopupMenuItem(value: 3, child: Text('标题 3')),
        const PopupMenuItem(value: 0, child: Text('正文')),
      ],
    ).then((value) {
      if (value == null) return;
      if (value == 0) {
        _editorKey.currentState?.formatParagraph();
      } else {
        _editorKey.currentState?.formatHeading(value);
      }
    });
  }
}

/// 保存笔记的 Intent（用于 Cmd+S / Ctrl+S 快捷键）
class _SaveNoteIntent extends Intent {
  const _SaveNoteIntent();
}
