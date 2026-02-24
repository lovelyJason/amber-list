import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/constants.dart';
import '../../core/services/task_image_service.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/models.dart';
import '../providers/providers.dart';
import '../pages/notes/widgets/markdown_editor/link_picker_dialog.dart';
import 'embedded_note_card.dart';
import 'task_image_preview.dart';

/// 任务详情面板
class TaskDetailPanel extends ConsumerStatefulWidget {
  final Task task;

  const TaskDetailPanel({super.key, required this.task});

  @override
  ConsumerState<TaskDetailPanel> createState() => _TaskDetailPanelState();
}

class _TaskDetailPanelState extends ConsumerState<TaskDetailPanel> {
  late TextEditingController _titleController;
  late TextEditingController _descController;

  /// FocusNode 用于监听标题输入框的失焦事件
  late FocusNode _titleFocusNode;
  /// FocusNode 用于监听描述输入框的失焦事件
  late FocusNode _descFocusNode;

  /// 记录原始标题值，用于判断是否有修改
  late String _originalTitle;
  /// 记录原始描述值，用于判断是否有修改
  late String _originalDesc;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descController = TextEditingController(text: widget.task.description ?? '');

    _originalTitle = widget.task.title;
    _originalDesc = widget.task.description ?? '';

    _titleFocusNode = FocusNode();
    _descFocusNode = FocusNode();

    // 监听标题输入框失焦事件，失焦时保存
    _titleFocusNode.addListener(_onTitleFocusChange);
    // 监听描述输入框失焦事件，失焦时保存
    _descFocusNode.addListener(_onDescFocusChange);
  }

  @override
  void didUpdateWidget(covariant TaskDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切换到不同任务时，重置输入框和原始值
    if (oldWidget.task.id != widget.task.id) {
      _titleController.text = widget.task.title;
      _descController.text = widget.task.description ?? '';
      _originalTitle = widget.task.title;
      _originalDesc = widget.task.description ?? '';
    }
  }

  @override
  void dispose() {
    // 移除监听器
    _titleFocusNode.removeListener(_onTitleFocusChange);
    _descFocusNode.removeListener(_onDescFocusChange);
    _titleFocusNode.dispose();
    _descFocusNode.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  /// 标题输入框失焦回调：失焦时保存标题
  void _onTitleFocusChange() {
    if (!_titleFocusNode.hasFocus) {
      _saveTitleIfChanged();
    }
  }

  /// 描述输入框失焦回调：失焦时保存描述
  void _onDescFocusChange() {
    if (!_descFocusNode.hasFocus) {
      _saveDescIfChanged();
    }
  }

  /// 保存标题（仅当有变化时）
  void _saveTitleIfChanged() {
    final newTitle = _titleController.text.trim();
    if (newTitle.isNotEmpty && newTitle != _originalTitle) {
      ref.read(taskProvider.notifier).updateTask(
        widget.task.copyWith(title: newTitle, updatedAt: DateTime.now()),
      );
      _originalTitle = newTitle; // 更新原始值，避免重复保存
    }
  }

  /// 保存描述（仅当有变化时）
  void _saveDescIfChanged() {
    final newDesc = _descController.text;
    if (newDesc != _originalDesc) {
      ref.read(taskProvider.notifier).updateTask(
        widget.task.copyWith(description: newDesc, updatedAt: DateTime.now()),
      );
      _originalDesc = newDesc; // 更新原始值，避免重复保存
    }
  }

  /// 处理粘贴快捷键（Cmd+V / Ctrl+V）
  ///
  /// 逻辑：
  /// 1. 先检查剪切板是否有图片
  /// 2. 有图片则保存图片并插入 Markdown 语法
  /// 3. 没有图片则让系统处理默认粘贴（文本）
  Future<void> _handlePasteShortcut() async {
    // 检查剪切板是否有图片
    final hasImage = await TaskImageService.hasImageInClipboard();

    if (hasImage) {
      // 粘贴图片
      final imagePath = await TaskImageService.pasteImageFromClipboard();
      if (imagePath != null) {
        // 在光标位置插入 Markdown 图片语法
        final cursorPos = _descController.selection.baseOffset;
        final currentText = _descController.text;

        // 智能换行：根据当前文本内容决定是否需要前置换行
        // - 如果文本为空，不加前置换行
        // - 如果光标在开头（cursorPos == 0），不加前置换行
        // - 如果光标前一个字符已经是换行符，不加前置换行
        // - 其他情况，加前置换行以分隔
        final bool needLeadingNewline = cursorPos > 0 &&
            cursorPos <= currentText.length &&
            currentText[cursorPos - 1] != '\n';

        final imageMarkdown =
            '${needLeadingNewline ? '\n' : ''}![image]($imagePath)\n';

        String newText;
        int insertedLength = imageMarkdown.length;

        if (cursorPos < 0 || cursorPos > currentText.length) {
          // 光标位置无效，追加到末尾
          final needNewlineAtEnd =
              currentText.isNotEmpty && !currentText.endsWith('\n');
          newText = currentText.isEmpty
              ? '![image]($imagePath)\n'
              : '$currentText${needNewlineAtEnd ? '\n' : ''}![image]($imagePath)\n';
          insertedLength = newText.length - currentText.length;
        } else {
          // 在光标位置插入
          newText = currentText.substring(0, cursorPos) +
              imageMarkdown +
              currentText.substring(cursorPos);
        }

        setState(() {
          _descController.text = newText;
          // 将光标移到插入内容之后
          _descController.selection = TextSelection.collapsed(
            offset: cursorPos < 0 ? newText.length : cursorPos + insertedLength,
          );
        });

        // 保存描述
        _saveDescIfChanged();
      }
    }
    // 如果没有图片，不做任何处理，让系统处理默认的文本粘贴
  }

  /// 是否为只读模式（已完成或已删除的任务）
  bool get _isReadOnly => widget.task.isCompleted || widget.task.isDeleted;

  @override
  Widget build(BuildContext context) {
    final taskLists = ref.watch(taskListProvider);
    final currentList = taskLists.where((l) => l.id == widget.task.listId).firstOrNull;

    return Container(
      width: AmberDimens.detailPanelWidth,
      color: AmberColors.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部
          _buildHeader(),
          const Divider(height: 1),
          // 内容
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AmberDimens.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题输入框：失焦或回车时保存，关闭时丢弃修改
                  // 已完成/已删除任务为只读模式
                  TextField(
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    readOnly: _isReadOnly,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _isReadOnly
                          ? AmberColors.textSecondary
                          : AmberColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: '任务标题',
                    ),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    // 回车键保存标题并移除焦点（只读模式下禁用）
                    onSubmitted: _isReadOnly ? null : (_) {
                      _saveTitleIfChanged();
                      _titleFocusNode.unfocus();
                    },
                  ),
                  const SizedBox(height: AmberDimens.spacingMd),
                  // 属性列表（只读模式下禁用点击）
                  _buildPropertyRow(
                    icon: Icons.calendar_today_outlined,
                    label: '截止日期',
                    value: widget.task.dueDate != null
                        ? DateFormat('yyyy年M月d日').format(widget.task.dueDate!)
                        : '未设置',
                    onTap: _isReadOnly
                        ? null
                        : () => _showDatePicker(context),
                  ),
                  _buildPropertyRow(
                    icon: Icons.list_rounded,
                    label: '清单',
                    value: currentList?.name ?? '收集箱',
                    valueColor: currentList?.color,
                    onTap: _isReadOnly
                        ? null
                        : () => _showListPicker(context, taskLists),
                  ),
                  _buildPropertyRow(
                    icon: Icons.flag_outlined,
                    label: '优先级',
                    value: _getPriorityText(widget.task.priority),
                    valueColor: _getPriorityColor(widget.task.priority),
                    onTap: _isReadOnly
                        ? null
                        : () => _showPriorityPicker(context),
                  ),
                  _buildPropertyRow(
                    icon: Icons.label_outline,
                    label: '标签',
                    value: widget.task.tags.isEmpty
                        ? '添加标签'
                        : widget.task.tags.join(', '),
                    onTap: _isReadOnly
                        ? null
                        : () {
                            _showTagsDialog(context);
                          },
                  ),
                  // 已完成任务显示完成时间
                  if (widget.task.isCompleted && widget.task.completedAt != null)
                    _buildPropertyRow(
                      icon: Icons.check_circle_outline,
                      label: '完成时间',
                      value: DateFormat('yyyy年M月d日 HH:mm').format(widget.task.completedAt!),
                      valueColor: AmberColors.success,
                      showArrow: false,
                    ),
                  const SizedBox(height: AmberDimens.spacingLg),
                  // 描述
                  const Text(
                    '描述',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AmberColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AmberDimens.spacingSm),
                  // 描述输入框：失焦时保存，关闭时丢弃修改
                  // 支持 Cmd+V / Ctrl+V 粘贴图片
                  // 已完成/已删除任务为只读模式
                  CallbackShortcuts(
                    bindings: <ShortcutActivator, VoidCallback>{
                      // macOS: Cmd+V, Windows/Linux: Ctrl+V
                      const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
                          _isReadOnly ? () {} : _handlePasteShortcut,
                      const SingleActivator(LogicalKeyboardKey.keyV, control: true):
                          _isReadOnly ? () {} : _handlePasteShortcut,
                    },
                    child: TextField(
                      controller: _descController,
                      focusNode: _descFocusNode,
                      readOnly: _isReadOnly,
                      maxLines: null,
                      minLines: 4,
                      decoration: InputDecoration(
                        hintText: _isReadOnly ? null : '添加描述... (支持粘贴图片)',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        // 移除默认内边距，让光标与"描述"标题左对齐
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      // 描述不需要 onSubmitted，因为多行文本回车是换行
                      // 只在失焦时通过 FocusNode 监听器保存
                    ),
                  ),
                  // 图片缩略图预览区
                  TaskImagePreview(
                    description: _descController.text,
                    readOnly: _isReadOnly,
                    onImageDeleted: (imagePath, newDescription) {
                      setState(() {
                        _descController.text = newDescription;
                      });
                      _saveDescIfChanged();
                    },
                  ),
                  // 关联笔记区域
                  _buildLinkedNotesSection(),
                ],
              ),
            ),
          ),
          // 底部操作栏
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AmberDimens.spacingMd,
        vertical: AmberDimens.spacingSm,
      ),
      child: Row(
        children: [
          const Text(
            '任务详情',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AmberColors.textSecondary,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              // 关闭面板，失焦时会自动保存修改
              ref.read(appNavProvider.notifier).closeDetailPanel();
            },
            icon: const Icon(Icons.close, size: 20),
            tooltip: '关闭',
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  /// 构建属性行
  /// - [showArrow] 控制是否显示右侧箭头，默认根据 onTap 是否为 null 决定
  Widget _buildPropertyRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    VoidCallback? onTap,
    bool? showArrow,
  }) {
    // 只读模式下不显示箭头，除非明确指定
    final shouldShowArrow = showArrow ?? (onTap != null);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AmberDimens.spacingSm),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AmberColors.textSecondary),
            const SizedBox(width: AmberDimens.spacingMd),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AmberColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? AmberColors.textPrimary,
              ),
            ),
            // 只读模式下隐藏箭头
            if (shouldShowArrow) ...[
              const SizedBox(width: AmberDimens.spacingXs),
              const Icon(Icons.chevron_right, size: 18, color: AmberColors.textDisabled),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建关联笔记区域
  ///
  /// 显示当前任务关联的所有笔记，支持关联/取消关联
  Widget _buildLinkedNotesSection() {
    final linkedNotesAsync = ref.watch(linkedNotesProvider(widget.task.id));

    return linkedNotesAsync.when(
      data: (List<Note> notes) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AmberDimens.spacingMd,
            vertical: AmberDimens.spacingSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 1, color: AmberColors.divider),
              const SizedBox(height: AmberDimens.spacingSm),
              Row(
                children: [
                  const Icon(Icons.description_outlined, size: 14, color: AmberColors.textDisabled),
                  const SizedBox(width: 4),
                  Text(
                    '关联笔记${notes.isEmpty ? '' : ' (${notes.length})'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AmberColors.textDisabled,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  // 添加关联按钮
                  InkWell(
                    onTap: _handleLinkNote,
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.add,
                        size: 16,
                        color: AmberColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                ...notes.map((note) => _buildLinkedNoteItem(note)),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  /// 构建单个关联笔记项
  Widget _buildLinkedNoteItem(Note note) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: EmbeddedNoteCard(
        note: note,
        onTap: () => ref.read(appNavProvider.notifier).navigateToNote(note.id),
        onUnlink: () {
          final repo = ref.read(noteTaskLinkRepositoryProvider);
          repo.unlinkNoteFromTask(note.id, widget.task.id);
        },
      ),
    );
  }

  /// 处理关联笔记（弹出笔记选择器）
  void _handleLinkNote() async {
    final selectedNote = await showNoteLinkPicker(context);

    if (selectedNote != null) {
      final repo = ref.read(noteTaskLinkRepositoryProvider);
      await repo.linkNoteToTask(selectedNote.id, widget.task.id);
    }
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(AmberDimens.spacingMd),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AmberColors.divider)),
      ),
      child: Row(
        children: [
          Text(
            '创建于 ${DateFormat('M月d日 HH:mm:ss').format(widget.task.createdAt)}',
            style: const TextStyle(
              fontSize: 12,
              color: AmberColors.textDisabled,
            ),
          ),
          const Spacer(),
          // 只读模式（已完成/已删除）下隐藏删除按钮
          if (!_isReadOnly)
            IconButton(
              onPressed: () {
                _deleteTask();
              },
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AmberColors.warning,
              tooltip: '删除任务',
              splashRadius: 18,
            ),
        ],
      ),
    );
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: widget.task.dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: const DatePickerThemeData(
              headerHeadlineStyle: TextStyle(
                fontSize: 16, // Smaller font size to prevent wrapping
                fontWeight: FontWeight.bold,
              ),
              headerHelpStyle: TextStyle(fontSize: 14),
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      // 规范化为 UTC 日期存储，确保跨设备同步时日期一致
      final normalizedDate = AmberDateUtils.normalizeToUtcDate(date);
      ref.read(taskProvider.notifier).updateTask(
        widget.task.copyWith(dueDate: normalizedDate, updatedAt: DateTime.now()),
      );
    }
  }

  void _showListPicker(BuildContext context, List<TaskList> lists) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          // 限制最大高度，防止清单过多时弹窗撑爆屏幕
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    ref
                        .read(taskProvider.notifier)
                        .updateTask(
                          widget.task.copyWith(
                            listId: null,
                            updatedAt: DateTime.now(),
                          ),
                        );
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.inbox_rounded,
                          size: 20,
                          color: AmberColors.textSecondary,
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          '收集箱',
                          style: TextStyle(
                            fontSize: 16,
                            color: AmberColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ...lists.map(
                  (list) => InkWell(
                    onTap: () {
                      ref
                          .read(taskProvider.notifier)
                          .updateTask(
                            widget.task.copyWith(
                              listId: list.id,
                              updatedAt: DateTime.now(),
                            ),
                          );
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          // 目录显示文件夹图标，普通清单显示颜色圆点
                          if (list.isFolder)
                            const Icon(
                              Icons.folder_outlined,
                              size: 20,
                              color: AmberColors.textSecondary,
                            )
                          else
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: list.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          SizedBox(width: list.isFolder ? 16 : 20),
                          Text(
                            list.name,
                            style: const TextStyle(
                              fontSize: 16,
                              color: AmberColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  void _showPriorityPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('设置优先级'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              ref
                  .read(taskProvider.notifier)
                  .updateTask(
                    widget.task.copyWith(
                      priority: TaskPriority.high,
                      updatedAt: DateTime.now(),
                    ),
                  );
              Navigator.pop(context);
            },
            child: const Row(
              children: [
                Icon(Icons.flag, color: AmberColors.priorityHigh, size: 18),
                SizedBox(width: 8),
                Text('高优先级'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              ref
                  .read(taskProvider.notifier)
                  .updateTask(
                    widget.task.copyWith(
                      priority: TaskPriority.medium,
                      updatedAt: DateTime.now(),
                    ),
                  );
              Navigator.pop(context);
            },
            child: const Row(
              children: [
                Icon(Icons.flag, color: AmberColors.priorityMedium, size: 18),
                SizedBox(width: 8),
                Text('中优先级'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              ref
                  .read(taskProvider.notifier)
                  .updateTask(
                    widget.task.copyWith(
                      priority: TaskPriority.low,
                      updatedAt: DateTime.now(),
                    ),
                  );
              Navigator.pop(context);
            },
            child: const Row(
              children: [
                Icon(Icons.flag, color: AmberColors.priorityLow, size: 18),
                SizedBox(width: 8),
                Text('低优先级'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              ref
                  .read(taskProvider.notifier)
                  .updateTask(
                    widget.task.copyWith(
                      priority: TaskPriority.none,
                      updatedAt: DateTime.now(),
                    ),
                  );
              Navigator.pop(context);
            },
            child: const Row(
              children: [
                Icon(
                  Icons.flag_outlined,
                  color: AmberColors.priorityNone,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text('无优先级'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _deleteTask() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务'),
        content: const Text('确定要删除这个任务吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AmberColors.warning,
            ),
            child: const Text('删除'),
            onPressed: () async {
              final success = await ref
                  .read(taskProvider.notifier)
                  .deleteTask(widget.task.id);

              if (!context.mounted) return;

              if (success) {
                ref.read(soundServiceProvider).playDelete();
                ref.read(appNavProvider.notifier).closeDetailPanel();
                Navigator.pop(context);
              } else {
                // 有番茄记录冲突
                Navigator.pop(context); // 先关闭当前对话框
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('无法删除'),
                    content: const Text(
                      '该任务有关联的番茄时钟记录。\n\n'
                      '请先前往番茄时钟页面删除相关记录，或选择"强制删除"移入垃圾桶。',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          ref
                              .read(taskProvider.notifier)
                              .forceDeleteTask(widget.task.id);
                          ref.read(soundServiceProvider).playDelete();
                          ref.read(appNavProvider.notifier).closeDetailPanel();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: const Text(
                          '强制删除',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  String _getPriorityText(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return '高';
      case TaskPriority.medium:
        return '中';
      case TaskPriority.low:
        return '低';
      case TaskPriority.none:
        return '无';
    }
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return AmberColors.priorityHigh;
      case TaskPriority.medium:
        return AmberColors.priorityMedium;
      case TaskPriority.low:
        return AmberColors.priorityLow;
      case TaskPriority.none:
        return AmberColors.priorityNone;
    }
  }
  void _showTagsDialog(BuildContext context) {
    final allTags = ref.read(tagsProvider);
    final selectedTags = List<String>.from(widget.task.tags);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('管理任务标签'),
          content: SizedBox(
            width: 300,
            child: allTags.isEmpty
                ? const Center(child: Text('暂无可用标签'))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allTags.map((tag) {
                      final isSelected = selectedTags.contains(tag.name);
                      final tagColor = tag.color; // Tag.color is Color

                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              selectedTags.remove(tag.name);
                            } else {
                              selectedTags.add(tag.name);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            // 选中时显示浅色背景，未选中显示灰色背景
                            color: isSelected
                                ? tagColor.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              // 选中时显示同色边框，未选中无边框
                              color: isSelected
                                  ? tagColor.withOpacity(0.3)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            tag.name,
                            style: TextStyle(
                              fontSize: 12,
                              // 选中时显示同色文字，未选中显示深灰文字
                              color: isSelected
                                  ? tagColor
                                  : AmberColors.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(taskProvider.notifier)
                    .updateTask(widget.task.copyWith(tags: selectedTags));
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
