import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../data/models/models.dart';
import '../../widgets/adaptive/bottom_nav_bar.dart';
import '../../providers/app_state.dart';
import 'notes_provider.dart';
import 'notes_trash_page.dart';
import 'widgets/note_card.dart';
import 'widgets/note_detail_panel.dart';

/// 笔记页面
///
/// 设计哲学：
/// - 响应式布局，桌面端左侧列表右侧详情，移动端全屏编辑
/// - 支持网格/列表两种视图模式
/// - 支持拖拽排序、置顶、搜索等功能
class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  String _searchQuery = '';
  bool _isGridView = true;
  String? _selectedNoteId;

  /// 新建笔记的 ID（用于判断关闭时是否删除空笔记）
  String? _newNoteId;

  /// 详情面板宽度（可拖拽调整）
  double _detailPanelWidth = AmberDimens.detailPanelWidth;

  @override
  Widget build(BuildContext context) {
    // 监听跨页跳转：从任务详情跳转到指定笔记
    final navState = ref.watch(appNavProvider);
    if (navState.targetNoteId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedNoteId = navState.targetNoteId);
          ref.read(appNavProvider.notifier).clearTargetNote();
        }
      });
    }

    final notes = ref.watch(notesProvider);
    final filteredNotes = _searchQuery.isEmpty
        ? notes
        : notes
            .where((n) =>
                n.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                n.content.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    // 分离置顶和普通笔记
    final pinnedNotes = filteredNotes.where((n) => n.isPinned).toList();
    final regularNotes = filteredNotes.where((n) => !n.isPinned).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile =
            constraints.maxWidth < ResponsiveHelper.mobileBreakpoint;

        if (isMobile) {
          return _buildMobileLayout(pinnedNotes, regularNotes, notes);
        } else {
          return _buildDesktopLayout(pinnedNotes, regularNotes, notes);
        }
      },
    );
  }

  /// 构建桌面端布局
  Widget _buildDesktopLayout(
    List<Note> pinnedNotes,
    List<Note> regularNotes,
    List<Note> notes,
  ) {
    return Stack(
      children: [
        Row(
          children: [
            // 主内容区
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  Expanded(
                    child: _isGridView
                        ? _buildGridView(pinnedNotes, regularNotes)
                        : _buildListView(pinnedNotes, regularNotes),
                  ),
                ],
              ),
            ),
            // 详情面板
            if (_selectedNoteId != null) ...[
              () {
                final note =
                    notes.where((n) => n.id == _selectedNoteId).firstOrNull;
                if (note != null) {
                  return _buildDetailPanelWithDivider(note);
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _selectedNoteId = null);
                });
                return const SizedBox.shrink();
              }(),
            ],
          ],
        ),
        // 垃圾篓浮动按钮
        Positioned(
          right: _selectedNoteId != null
              ? _detailPanelWidth + AmberDimens.spacingLg
              : AmberDimens.spacingLg,
          bottom: AmberDimens.spacingLg,
          child: _buildTrashButton(),
        ),
      ],
    );
  }

  /// 构建详情面板（含可拖拽分割线）
  Widget _buildDetailPanelWithDivider(Note note) {
    final isNewNote = note.id == _newNoteId;

    return Builder(
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final notesPageWidth = screenWidth - AmberDimens.narrowSidebarWidth;
        const minListWidth = 500.0;
        final maxPanelWidth = (notesPageWidth - minListWidth).clamp(
          280.0,
          double.infinity,
        );
        final displayWidth = _detailPanelWidth.clamp(280.0, maxPanelWidth);

        return Stack(
          children: [
            // 详情面板主体
            Container(
              width: displayWidth,
              decoration: BoxDecoration(
                color: AmberColors.cardBackground,
                border: Border(
                  left: BorderSide(color: AmberColors.divider, width: 1),
                ),
              ),
              child: NoteDetailPanel(
                key: ValueKey(note.id),
                note: note,
                isNewNote: isNewNote,
                onClose: () => setState(() {
                  _selectedNoteId = null;
                  _newNoteId = null;
                }),
              ),
            ),
            // 可拖拽区域
            Positioned(
              left: -4,
              top: 0,
              bottom: 0,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _detailPanelWidth -= details.delta.dx;
                      _detailPanelWidth =
                          _detailPanelWidth.clamp(280.0, maxPanelWidth);
                    });
                  },
                  child: Container(width: 8, color: Colors.transparent),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 构建垃圾篓浮动按钮
  Widget _buildTrashButton() {
    return FloatingActionButton.small(
      heroTag: null,
      onPressed: _navigateToTrash,
      backgroundColor: AmberColors.cardBackground,
      foregroundColor: AmberColors.textSecondary,
      elevation: 4,
      tooltip: '垃圾篓',
      child: const Icon(Icons.delete_outline, size: 20),
    );
  }

  /// 导航到垃圾篓页面
  void _navigateToTrash() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotesTrashPage()),
    );
  }

  /// 构建移动端布局
  Widget _buildMobileLayout(
    List<Note> pinnedNotes,
    List<Note> regularNotes,
    List<Note> notes,
  ) {
    // 如果选中了笔记，显示全屏编辑页面
    if (_selectedNoteId != null) {
      final note = notes.where((n) => n.id == _selectedNoteId).firstOrNull;
      if (note == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selectedNoteId = null);
        });
        return const SizedBox.shrink();
      }
      return Scaffold(
        backgroundColor: AmberColors.cardBackground,
        appBar: AppBar(
          backgroundColor: AmberColors.cardBackground,
          elevation: 0,
          leading: IconButton(
            onPressed: () => setState(() => _selectedNoteId = null),
            icon: const Icon(Icons.arrow_back, color: AmberColors.textPrimary),
          ),
          title: const Text(
            '编辑笔记',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AmberColors.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () =>
                  ref.read(notesProvider.notifier).togglePin(note.id),
              icon: Icon(
                note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: note.isPinned
                    ? AmberColors.primary
                    : AmberColors.textSecondary,
              ),
              tooltip: note.isPinned ? '取消置顶' : '置顶',
            ),
            IconButton(
              onPressed: () {
                ref.read(notesProvider.notifier).deleteNote(note.id);
                setState(() => _selectedNoteId = null);
              },
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: '删除',
            ),
          ],
        ),
        body: NoteDetailPanel(
          key: ValueKey(note.id),
          note: note,
          onClose: () => setState(() => _selectedNoteId = null),
        ),
      );
    }

    // 笔记列表页面
    return Scaffold(
      backgroundColor: AmberColors.background,
      appBar: AppBar(
        backgroundColor: AmberColors.cardBackground,
        elevation: 0,
        title: const Text(
          '笔记',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AmberColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _navigateToTrash,
            icon: const Icon(Icons.delete_outline,
                color: AmberColors.textSecondary),
            tooltip: '垃圾篓',
          ),
          IconButton(
            onPressed: () => setState(() => _isGridView = !_isGridView),
            icon: Icon(
              _isGridView ? Icons.view_list : Icons.grid_view,
              color: AmberColors.textSecondary,
            ),
            tooltip: _isGridView ? '列表视图' : '网格视图',
          ),
          IconButton(
            onPressed: _createNewNote,
            icon: const Icon(Icons.add, color: AmberColors.primary),
            tooltip: '新建笔记',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMobileSearchBar(),
          const Divider(height: 1),
          Expanded(
            child: _isGridView
                ? _buildGridView(pinnedNotes, regularNotes)
                : _buildListView(pinnedNotes, regularNotes),
          ),
        ],
      ),
      bottomNavigationBar: const MobileBottomNavBar(),
    );
  }

  /// 构建移动端搜索栏
  Widget _buildMobileSearchBar() {
    return Container(
      color: AmberColors.cardBackground,
      padding: const EdgeInsets.symmetric(
        horizontal: AmberDimens.spacingMd,
        vertical: AmberDimens.spacingSm,
      ),
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
    );
  }

  /// 构建桌面端头部工具栏
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
            const SizedBox(width: AmberDimens.spacingMd),
            // 搜索框（使用 Flexible 防止溢出）
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
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
            ),
            const SizedBox(width: AmberDimens.spacingMd),
            // 视图切换
            IconButton(
              onPressed: () => setState(() => _isGridView = true),
              icon: Icon(
                Icons.grid_view,
                color:
                    _isGridView ? AmberColors.primary : AmberColors.textSecondary,
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

  /// 构建网格视图
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
              _buildPinnedGrid(pinnedNotes),
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
              _buildRegularGrid(regularNotes),
            ],
            // 新建笔记卡片
            const SizedBox(height: AmberDimens.spacingMd),
            CreateNoteCard(onTap: _createNewNote),
          ],
        ),
      ),
    );
  }

  /// 构建置顶笔记网格
  Widget _buildPinnedGrid(List<Note> pinnedNotes) {
    return ReorderableGridView.builder(
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
        ref.read(notesProvider.notifier).reorderPinned(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final note = pinnedNotes[index];
        return ReorderableDelayedDragStartListener(
          key: ValueKey(note.id),
          index: index,
          child: NoteCard(
            note: note,
            isSelected: _selectedNoteId == note.id,
            onTap: () => setState(() => _selectedNoteId = note.id),
            onSecondaryTapDown: (details) =>
                _showContextMenu(context, details, note),
          ),
        );
      },
    );
  }

  /// 构建普通笔记网格
  Widget _buildRegularGrid(List<Note> regularNotes) {
    return ReorderableGridView.builder(
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
        ref.read(notesProvider.notifier).reorderRegular(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final note = regularNotes[index];
        return ReorderableDelayedDragStartListener(
          key: ValueKey(note.id),
          index: index,
          child: NoteCard(
            note: note,
            isSelected: _selectedNoteId == note.id,
            onTap: () => setState(() => _selectedNoteId = note.id),
            onSecondaryTapDown: (details) =>
                _showContextMenu(context, details, note),
          ),
        );
      },
    );
  }

  /// 构建列表视图
  Widget _buildListView(List<Note> pinnedNotes, List<Note> regularNotes) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AmberDimens.spacingMd),
        child: Column(
          children: [
            if (pinnedNotes.isNotEmpty)
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: pinnedNotes.length,
                onReorder: (oldIndex, newIndex) {
                  ref.read(notesProvider.notifier).reorderPinned(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final note = pinnedNotes[index];
                  return KeyedSubtree(
                    key: ValueKey(note.id),
                    child: NoteListItem(
                      note: note,
                      isSelected: _selectedNoteId == note.id,
                      index: index,
                      onTap: () => setState(() => _selectedNoteId = note.id),
                      onLongPress: () => _showContextMenu(
                        context,
                        TapDownDetails(globalPosition: Offset.zero),
                        note,
                      ),
                    ),
                  );
                },
              ),
            if (pinnedNotes.isNotEmpty && regularNotes.isNotEmpty)
              const Divider(height: 32, thickness: 1),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: regularNotes.length,
              onReorder: (oldIndex, newIndex) {
                ref.read(notesProvider.notifier).reorderRegular(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final note = regularNotes[index];
                return KeyedSubtree(
                  key: ValueKey(note.id),
                  child: NoteListItem(
                    note: note,
                    isSelected: _selectedNoteId == note.id,
                    index: index,
                    onTap: () => setState(() => _selectedNoteId = note.id),
                    onLongPress: () => _showContextMenu(
                      context,
                      TapDownDetails(globalPosition: Offset.zero),
                      note,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 新建笔记
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
    setState(() {
      _selectedNoteId = newNote.id;
      _newNoteId = newNote.id;
    });
  }

  /// 显示右键菜单
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
              SizedBox(width: 8),
              Text('编辑'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.red),
              SizedBox(width: 8),
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

  /// 显示删除确认对话框
  Future<void> _showDeleteConfirmDialog(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除笔记'),
        content: Text('确定要删除笔记"${note.title}"吗？此操作无法撤销。'),
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
}
