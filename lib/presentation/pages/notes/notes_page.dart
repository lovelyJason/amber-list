import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart'; // Add import
import '../../../core/constants/constants.dart';
import '../../../data/models/models.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

/// 笔记状态Provider
final notesProvider = StateNotifierProvider<NotesNotifier, List<Note>>((ref) {
  return NotesNotifier();
});

class NotesNotifier extends StateNotifier<List<Note>> {
  NotesNotifier() : super(_mockNotes);

  static final _mockNotes = [
    Note(
      id: '1',
      title: '产品路线图 2024',
      content: '## Q1 目标\n- 完成核心功能开发\n- 用户测试\n\n## Q2 目标\n- 上线公测版本',
      tags: ['工作'],
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Note(
      id: '2',
      title: '设计灵感',
      content: '- 简约排版\n- 琥珀色调\n- 圆角设计\n- 柔和阴影',
      tags: ['灵感'],
      isPinned: true,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Note(
      id: '3',
      title: '购物清单',
      content: '- 牛奶\n- 面包\n- 鸡蛋\n- 咖啡豆',
      tags: ['生活'],
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Note(
      id: '4',
      title: '读书笔记：深入理解Flutter',
      content: '## 第一章\nFlutter是Google开发的跨平台框架...\n\n## 关键概念\n- Widget\n- State\n- BuildContext',
      tags: ['阅读', '技术'],
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Note(
      id: '5',
      title: '会议记录',
      content: '参会人员：\n- 张三\n- 李四\n\n讨论内容：\n1. 项目进度\n2. 下周计划',
      tags: ['工作', '会议'],
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];

  void addNote(Note note) {
    state = [note, ...state];
  }

  void updateNote(Note updated) {
    state = state.map((n) => n.id == updated.id ? updated : n).toList();
  }

  void deleteNote(String id) {
    state = state.where((n) => n.id != id).toList();
  }

  void togglePin(String id) {
    state = state.map((n) {
      if (n.id == id) {
        return n.copyWith(isPinned: !n.isPinned, updatedAt: DateTime.now());
      }
      return n;
    }).toList();
  }

  void reorderPinned(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final pinned = state.where((n) => n.isPinned).toList();
    final item = pinned.removeAt(oldIndex);
    pinned.insert(newIndex, item);

    // Merge back: pinned + unpinned
    final unpinned = state.where((n) => !n.isPinned).toList();
    state = [...pinned, ...unpinned];
  }

  void reorderRegular(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final unpinned = state.where((n) => !n.isPinned).toList();
    final item = unpinned.removeAt(oldIndex);
    unpinned.insert(newIndex, item);

    // Merge back: pinned + unpinned
    final pinned = state.where((n) => n.isPinned).toList();
    state = [...pinned, ...unpinned];
  }
}

/// 笔记页面
class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  String _searchQuery = '';
  bool _isGridView = true;
  String? _selectedNoteId;

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);
    final filteredNotes = _searchQuery.isEmpty
        ? notes
        : notes.where((n) =>
            n.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            n.content.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    // 分离置顶和普通笔记
    final pinnedNotes = filteredNotes.where((n) => n.isPinned).toList();
    final regularNotes = filteredNotes.where((n) => !n.isPinned).toList();

    return Row(
      children: [
        // 主内容区
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部工具栏
              _buildHeader(),
              // 笔记网格/列表
              Expanded(
                child: _isGridView
                    ? _buildGridView(pinnedNotes, regularNotes)
                    : _buildListView(pinnedNotes, regularNotes),
              ),
            ],
          ),
        ),
        // 详情面板
        if (_selectedNoteId != null)
          _buildDetailPanel(notes.firstWhere((n) => n.id == _selectedNoteId)),
      ],
    );
  }

  Widget _buildHeader() {
    return DragToMoveArea(
      child: Container(
        padding: const EdgeInsets.all(AmberDimens.spacingMd),
        child: Row(
          children: [
            const Text(
              '笔记',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            // 搜索框
            SizedBox(
              width: 200,
              child: TextField(
                decoration: InputDecoration(
                  hintText: '搜索笔记...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            const SizedBox(width: AmberDimens.spacingMd),
            // 视图切换
            IconButton(
              onPressed: () => setState(() => _isGridView = true),
              icon: Icon(
                Icons.grid_view,
                color: _isGridView
                    ? AmberColors.primary
                    : AmberColors.textSecondary,
              ),
              tooltip: '网格视图',
            ),
            IconButton(
              onPressed: () => setState(() => _isGridView = false),
              icon: Icon(
                Icons.view_list,
                color: !_isGridView
                    ? AmberColors.primary
                    : AmberColors.textSecondary,
              ),
              tooltip: '列表视图',
            ),
            const SizedBox(width: AmberDimens.spacingSm),
            // 新建笔记按钮
            ElevatedButton.icon(
              onPressed: _createNewNote,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新建笔记'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridView(List<Note> pinnedNotes, List<Note> regularNotes) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AmberDimens.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 置顶笔记
            if (pinnedNotes.isNotEmpty) ...[
              const Text(
                '置顶',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AmberColors.textDisabled,
                ),
              ),
              const SizedBox(height: AmberDimens.spacingSm),
              ReorderableGridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  mainAxisExtent: 180,
                  mainAxisSpacing: AmberDimens.spacingMd,
                  crossAxisSpacing: AmberDimens.spacingMd,
                ),
                itemCount: pinnedNotes.length,
                onReorder: (oldIndex, newIndex) {
                  ref
                      .read(notesProvider.notifier)
                      .reorderPinned(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final note = pinnedNotes[index];
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey(note.id),
                    index: index,
                    child: _buildNoteCard(note),
                  );
                },
              ),
              const SizedBox(height: AmberDimens.spacingLg),
            ],
            // 其他笔记
            if (regularNotes.isNotEmpty) ...[
              if (pinnedNotes.isNotEmpty)
                const Text(
                  '其他',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AmberColors.textDisabled,
                  ),
                ),
              const SizedBox(height: AmberDimens.spacingSm),
              ReorderableGridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  mainAxisExtent: 180,
                  mainAxisSpacing: AmberDimens.spacingMd,
                  crossAxisSpacing: AmberDimens.spacingMd,
                ),
                itemCount: regularNotes.length,
                onReorder: (oldIndex, newIndex) {
                  ref
                      .read(notesProvider.notifier)
                      .reorderRegular(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final note = regularNotes[index];
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey(note.id),
                    index: index,
                    child: _buildNoteCard(note),
                  );
                },
              ),
            ],
            // 新建笔记卡片
            if (regularNotes.isEmpty && pinnedNotes.isEmpty) ...[
              const SizedBox(height: AmberDimens.spacingMd),
              _buildCreateNoteCard(),
            ] else ...[
              const SizedBox(height: AmberDimens.spacingMd),
              // Put Create Card at the end of whatever list is last?
              // Grid Reordering makes mixing items hard.
              // For now, place Create Card below everything.
              _buildCreateNoteCard(),
            ],
          ],
        ),
      ),
    );
  }

  // Removed _buildNotesGrid as it is replaced by ReorderableGridView.builder inline or we can keep for fallback? 
  // It is used in the code above only. I replaced usage. So I can remove it or repurpose it?
  // I replaced usage in _buildGridView with inline Builders.
  // So _buildNotesGrid is no longer needed.
  // I will delete it to clean up.


  Widget _buildNoteCard(Note note) {
    final isSelected = _selectedNoteId == note.id;

    return GestureDetector(
      onTap: () => setState(() => _selectedNoteId = note.id),
      onSecondaryTapDown: (details) => _showContextMenu(context, details, note),
      child: Container(
        width: 240,
        height: 180,
        padding: const EdgeInsets.all(AmberDimens.spacingMd),
        decoration: BoxDecoration(
          color: isSelected ? AmberColors.primaryLight : AmberColors.cardBackground,
          borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
          // border removed as per user request
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                if (note.isPinned)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.push_pin, size: 14, color: AmberColors.primary),
                  ),
                Expanded(
                  child: Text(
                    note.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (note.tags.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AmberColors.primaryTransparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      note.tags.first,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AmberColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AmberDimens.spacingSm),
            // 内容预览
            Expanded(
              child: Text(
                note.summary.isNotEmpty ? note.summary : '空笔记',
                style: TextStyle(
                  fontSize: 12,
                  color: note.summary.isNotEmpty
                      ? AmberColors.textSecondary
                      : AmberColors.textDisabled,
                ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 底部日期
            Text(
              _formatDate(note.updatedAt),
              style: const TextStyle(
                fontSize: 11,
                color: AmberColors.textDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateNoteCard() {
    return GestureDetector(
      onTap: _createNewNote,
      child: Container(
        width: 240,
        height: 180,
        decoration: BoxDecoration(
          color: AmberColors.sidebarBackground,
          borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
          border: Border.all(
            color: AmberColors.divider,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AmberColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                size: 24,
                color: AmberColors.primary,
              ),
            ),
            const SizedBox(height: AmberDimens.spacingSm),
            const Text(
              '新建笔记',
              style: TextStyle(
                color: AmberColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(List<Note> pinnedNotes, List<Note> regularNotes) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        // Wrap with SingleScrollView to hold two lists
        padding: const EdgeInsets.all(AmberDimens.spacingMd),
        child: Column(
          children: [
            if (pinnedNotes.isNotEmpty)
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false, // Disable default handles
                itemCount: pinnedNotes.length,
                onReorder: (oldIndex, newIndex) {
                  ref
                      .read(notesProvider.notifier)
                      .reorderPinned(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final note = pinnedNotes[index];
                  return KeyedSubtree(
                    key: ValueKey(note.id),
                    child: _buildNoteListItem(note, index: index), // Pass index
                  );
                },
              ),
            if (pinnedNotes.isNotEmpty && regularNotes.isNotEmpty)
              const Divider(height: 32, thickness: 1), // Separator

            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false, // Disable default handles
              itemCount: regularNotes.length,
              onReorder: (oldIndex, newIndex) {
                ref
                    .read(notesProvider.notifier)
                    .reorderRegular(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final note = regularNotes[index];
                return KeyedSubtree(
                  key: ValueKey(note.id),
                  child: _buildNoteListItem(note, index: index), // Pass index
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteListItem(Note note, {required int index}) {
    final isSelected = _selectedNoteId == note.id;

    return ListTile(
      selected: isSelected,
      selectedTileColor: AmberColors.primaryLight,
      leading: note.isPinned
          ? const Icon(Icons.push_pin, size: 18, color: AmberColors.primary)
          : const Icon(Icons.note_outlined, size: 18),
      title: Text(note.title),
      subtitle: Text(
        note.summary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatDate(note.updatedAt),
            style: const TextStyle(
              fontSize: 12,
              color: AmberColors.textDisabled,
            ),
          ),
          const SizedBox(width: 8),
          ReorderableDragStartListener(
            index: index,
            child: const Icon(
              Icons.drag_handle,
              color: AmberColors.textDisabled,
            ),
          ),
        ],
      ),
      onTap: () => setState(() => _selectedNoteId = note.id),
      onLongPress: () => _showContextMenu(
        context,
        TapDownDetails(globalPosition: Offset.zero),
        note,
      ), // Fallback for mobile?
    );
    // Duplicate block removed
  }

  Widget _buildDetailPanel(Note note) {
    return Container(
      width: AmberDimens.detailPanelWidth,
      decoration: BoxDecoration(
        color: AmberColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(-8, 0), // Shadow to the left
          ),
        ],
      ),
      child: _NoteDetailPanel(
        key: ValueKey(note.id),
        note: note,
        onClose: () => setState(() => _selectedNoteId = null),
      ),
    );
  }

  void _createNewNote() {
    final now = DateTime.now();
    final newNote = Note(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '新建笔记',
      content: '',
      createdAt: now,
      updatedAt: now,
    );
    ref.read(notesProvider.notifier).addNote(newNote);
    setState(() => _selectedNoteId = newNote.id);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return DateFormat('M月d日').format(date);
    }
  }
  Future<void> _showContextMenu(
    BuildContext context,
    TapDownDetails details,
    Note note,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );

    final value = await showMenu<String>(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          value: 'pin',
          child: Row(
            children: [
              Icon(
                note.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                size: 18,
                color: AmberColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(note.isPinned ? '取消置顶' : '置顶'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(
                Icons.edit_outlined,
                size: 18,
                color: AmberColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text('编辑'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.red),
              const SizedBox(width: 8),
              Text('删除', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );

    if (value == null) return;

    if (value == 'pin') {
      ref.read(notesProvider.notifier).togglePin(note.id);
    } else if (value == 'edit') {
      setState(() => _selectedNoteId = note.id);
    } else if (value == 'delete') {
      _showDeleteConfirmDialog(note);
    }
  }

  Future<void> _showDeleteConfirmDialog(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除笔记'),
        content: Text('确定要删除笔记“${note.title}”吗？此操作无法撤销。'),
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
      ref.read(notesProvider.notifier).deleteNote(note.id);
      if (_selectedNoteId == note.id) {
        setState(() => _selectedNoteId = null);
      }
    }
  }
} // End of class _NotesPageState

class _NoteDetailPanel extends ConsumerStatefulWidget {
  final Note note;
  final VoidCallback onClose;

  const _NoteDetailPanel({
    super.key,
    required this.note,
    required this.onClose,
  });

  @override
  ConsumerState<_NoteDetailPanel> createState() => _NoteDetailPanelState();
}

class _NoteDetailPanelState extends ConsumerState<_NoteDetailPanel> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _updateTitle(String title) {
    ref
        .read(notesProvider.notifier)
        .updateNote(
          widget.note.copyWith(title: title, updatedAt: DateTime.now()),
        );
  }

  void _updateContent(String content) {
    ref
        .read(notesProvider.notifier)
        .updateNote(
          widget.note.copyWith(content: content, updatedAt: DateTime.now()),
        );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return DateFormat('M月d日').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 头部
        DragToMoveArea(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AmberDimens.spacingLg,
              vertical: AmberDimens.spacingSm, // Reduced from spacingMd
            ),
            child: Row(
              children: [
                const Spacer(),
                IconButton(
                  onPressed: () => ref
                      .read(notesProvider.notifier)
                      .togglePin(widget.note.id),
                  icon: Icon(
                    widget.note.isPinned
                        ? Icons.push_pin
                        : Icons.push_pin_outlined,
                    size: 20,
                    color: widget.note.isPinned
                        ? AmberColors.primary
                        : AmberColors.textSecondary,
                  ),
                  tooltip: widget.note.isPinned ? '取消置顶' : '置顶',
                  style: IconButton.styleFrom(
                    hoverColor: AmberColors.primary.withValues(alpha: 0.1),
                  ),
                ),
                const SizedBox(width: AmberDimens.spacingSm),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: AmberColors.textSecondary,
                  ),
                  tooltip: '关闭',
                  style: IconButton.styleFrom(
                    hoverColor: Colors.red.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // 内容区域
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题区域
              TextField(
                controller: _titleController,
                style: const TextStyle(
                  fontSize: 24, // Larger title
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
                    horizontal: AmberDimens.spacingLg,
                    vertical: 0,
                  ),
                ),
                onChanged: _updateTitle,
              ),
              
              const SizedBox(height: AmberDimens.spacingMd),

              // 标签区域
              if (widget.note.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AmberDimens.spacingLg,
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
                
              const SizedBox(height: AmberDimens.spacingLg),

              // 内容输入框 (高度拉满)
              Expanded(
                child: TextField(
                  controller: _contentController,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.8, // Better line height for reading
                    color: AmberColors.textSecondary,
                  ),
                  maxLines: null, 
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    fillColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    hintText: '开始输入内容...',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AmberDimens.spacingLg,
                      vertical: 0,
                    ),
                  ),
                  onChanged: _updateContent,
                ),
              ),
            ],
          ),
        ),
        // 底部
        Container(
          padding: const EdgeInsets.all(AmberDimens.spacingLg),
          child: Row(
            children: [
              Text(
                '更新于 ${_formatDate(widget.note.updatedAt)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AmberColors.textDisabled,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  ref.read(notesProvider.notifier).deleteNote(widget.note.id);
                  widget.onClose();
                },
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AmberColors.textSecondary,
                hoverColor: Colors.red.withValues(alpha: 0.1),
                tooltip: '删除',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
