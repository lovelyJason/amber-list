import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../data/models/models.dart';
import '../../../data/datasources/local/database.dart' as db;
import '../../providers/database_provider.dart';
import '../../widgets/adaptive/bottom_nav_bar.dart';
import '../../widgets/common/toast/toast_manager.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import 'notes_trash_page.dart';

/// 将数据库笔记对象转换为 UI 模型
Note _mapDbNoteToModel(db.Note dbNote) {
  List<String> tags = [];
  try {
    tags = List<String>.from(jsonDecode(dbNote.tags));
  } catch (_) {}

  return Note(
    id: dbNote.id,
    title: dbNote.title,
    content: dbNote.content,
    folderId: dbNote.folderId,
    tags: tags,
    isPinned: dbNote.isPinned,
    isDeleted: dbNote.isDeleted,
    deletedAt: dbNote.deletedAt,
    createdAt: dbNote.createdAt,
    updatedAt: dbNote.updatedAt,
  );
}

/// 笔记状态管理 Provider
/// 使用数据库持久化存储，支持 CRUD 操作
final notesProvider = StateNotifierProvider<NotesNotifier, List<Note>>((ref) {
  final database = ref.watch(databaseProvider);
  return NotesNotifier(database);
});

/// 垃圾篓笔记 Provider
/// 监听已软删除的笔记列表
final trashNotesProvider = StreamProvider<List<Note>>((ref) {
  final database = ref.watch(databaseProvider);
  return database.watchTrashNotes().map(
        (dbNotes) => dbNotes.map(_mapDbNoteToModel).toList(),
      );
});

/// 笔记状态管理器
/// 订阅数据库 Stream，自动同步状态变更
class NotesNotifier extends StateNotifier<List<Note>> {
  final db.AppDatabase database;

  NotesNotifier(this.database) : super([]) {
    _init();
  }

  /// 初始化：订阅数据库笔记表的变更流
  /// 数据库已按 sortOrder 排序返回，这里不再额外排序
  void _init() {
    database.watchAllNotes().listen((dbNotes) {
      // 转换为 UI 模型（数据库已按 sortOrder 排序）
      final notes = dbNotes.map(_mapDbNoteToModel).toList();
      state = notes;
    });
  }

  /// 添加笔记
  Future<void> addNote(Note note) async {
    await database.insertNote(
      db.NotesCompanion.insert(
        id: note.id,
        title: note.title,
        content: drift.Value(note.content),
        folderId: drift.Value(note.folderId),
        tags: drift.Value(jsonEncode(note.tags)),
        isPinned: drift.Value(note.isPinned),
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
      ),
    );
  }

  /// 更新笔记
  Future<void> updateNote(Note updated) async {
    await database.updateNote(
      db.NotesCompanion(
        id: drift.Value(updated.id),
        title: drift.Value(updated.title),
        content: drift.Value(updated.content),
        folderId: drift.Value(updated.folderId),
        tags: drift.Value(jsonEncode(updated.tags)),
        isPinned: drift.Value(updated.isPinned),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  /// 删除笔记（软删除，移到垃圾篓）
  Future<void> deleteNote(String id) async {
    await database.softDeleteNote(id);
  }

  /// 恢复已删除的笔记
  Future<void> restoreNote(String id) async {
    await database.restoreNote(id);
  }

  /// 永久删除笔记（物理删除）
  Future<void> permanentlyDeleteNote(String id) async {
    await database.permanentlyDeleteNote(id);
  }

  /// 清空垃圾篓
  Future<int> emptyTrash() async {
    return await database.emptyNotesTrash();
  }

  /// 切换置顶状态
  Future<void> togglePin(String id) async {
    final note = state.firstWhere((n) => n.id == id);
    await database.updateNote(
      db.NotesCompanion(
        id: drift.Value(id),
        isPinned: drift.Value(!note.isPinned),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  /// 重排序置顶笔记（持久化到数据库）
  Future<void> reorderPinned(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final pinned = state.where((n) => n.isPinned).toList();
    final item = pinned.removeAt(oldIndex);
    pinned.insert(newIndex, item);

    // 合并：置顶 + 非置顶
    final unpinned = state.where((n) => !n.isPinned).toList();
    final newOrder = [...pinned, ...unpinned];

    // 立即更新UI状态
    state = newOrder;

    // 持久化排序到数据库
    await database.updateNotesOrder(newOrder.map((n) => n.id).toList());
  }

  /// 重排序非置顶笔记（持久化到数据库）
  Future<void> reorderRegular(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final unpinned = state.where((n) => !n.isPinned).toList();
    final item = unpinned.removeAt(oldIndex);
    unpinned.insert(newIndex, item);

    // 合并：置顶 + 非置顶
    final pinned = state.where((n) => n.isPinned).toList();
    final newOrder = [...pinned, ...unpinned];

    // 立即更新UI状态
    state = newOrder;

    // 持久化排序到数据库
    await database.updateNotesOrder(newOrder.map((n) => n.id).toList());
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

  /// 新建笔记的 ID（用于判断关闭时是否删除空笔记）
  String? _newNoteId;

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

  /// 构建桌面端布局（原有布局）
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
            // 详情面板（使用安全查找，避免已删除笔记导致崩溃）
            if (_selectedNoteId != null) ...[
              () {
                final note =
                    notes.where((n) => n.id == _selectedNoteId).firstOrNull;
                if (note != null) {
                  return _buildDetailPanel(note);
                }
                // 笔记已删除，清空选中状态（延迟执行避免 build 中 setState）
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _selectedNoteId = null);
                });
                return const SizedBox.shrink();
              }(),
            ],
          ],
        ),
        // 垃圾篓浮动按钮（右下角）
        Positioned(
          right: _selectedNoteId != null
              ? AmberDimens.detailPanelWidth + AmberDimens.spacingLg
              : AmberDimens.spacingLg,
          bottom: AmberDimens.spacingLg,
          child: _buildTrashButton(),
        ),
      ],
    );
  }

  /// 构建垃圾篓浮动按钮
  Widget _buildTrashButton() {
    return FloatingActionButton.small(
      heroTag: null, // 禁用 Hero 动画，避免多个 FAB 冲突
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
  /// 移动端隐藏详情面板，点击笔记时全屏编辑
  Widget _buildMobileLayout(
    List<Note> pinnedNotes,
    List<Note> regularNotes,
    List<Note> notes,
  ) {
    // 如果选中了笔记，显示全屏编辑页面
    if (_selectedNoteId != null) {
      final note = notes.where((n) => n.id == _selectedNoteId).firstOrNull;
      if (note == null) {
        // 笔记已删除，延迟清空选中状态
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
              onPressed: () => ref.read(notesProvider.notifier).togglePin(note.id),
              icon: Icon(
                note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: note.isPinned ? AmberColors.primary : AmberColors.textSecondary,
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
        body: _NoteDetailPanel(
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
          // 垃圾篓
          IconButton(
            onPressed: _navigateToTrash,
            icon: const Icon(Icons.delete_outline, color: AmberColors.textSecondary),
            tooltip: '垃圾篓',
          ),
          // 视图切换
          IconButton(
            onPressed: () => setState(() => _isGridView = !_isGridView),
            icon: Icon(
              _isGridView ? Icons.view_list : Icons.grid_view,
              color: AmberColors.textSecondary,
            ),
            tooltip: _isGridView ? '列表视图' : '网格视图',
          ),
          // 新建笔记
          IconButton(
            onPressed: _createNewNote,
            icon: const Icon(Icons.add, color: AmberColors.primary),
            tooltip: '新建笔记',
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Container(
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
          ),
          const Divider(height: 1),
          // 笔记列表
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
    final isNewNote = note.id == _newNoteId;

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
        isNewNote: isNewNote,
        onClose: () => setState(() {
          _selectedNoteId = null;
          _newNoteId = null; // 清除新建笔记标记
        }),
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
    setState(() {
      _selectedNoteId = newNote.id;
      _newNoteId = newNote.id; // 标记为新建笔记
    });
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

  /// 是否为新建笔记（用于判断关闭时是否删除空笔记）
  final bool isNewNote;

  const _NoteDetailPanel({
    super.key,
    required this.note,
    required this.onClose,
    this.isNewNote = false,
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

  /// 判断笔记是否为空（标题为默认值且内容为空）
  bool _isEmptyNote() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
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

  /// 保存笔记（手动触发保存，同时更新标题和内容）
  void _saveNote() {
    final updatedNote = widget.note.copyWith(
      title: _titleController.text,
      content: _contentController.text,
      updatedAt: DateTime.now(),
    );
    ref.read(notesProvider.notifier).updateNote(updatedNote);

    // 显示保存成功提示
    ToastManager().show(context, '已保存', type: ToastType.success);

    // 关闭编辑面板
    widget.onClose();
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
                // 关闭按钮
                IconButton(
                  onPressed: _handleClose,
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
                const SizedBox(width: AmberDimens.spacingSm),
                // 保存按钮
                IconButton(
                  onPressed: _saveNote,
                  icon: const Icon(
                    Icons.check,
                    size: 20,
                    color: AmberColors.success,
                  ),
                  tooltip: '保存',
                  style: IconButton.styleFrom(
                    hoverColor: AmberColors.success.withValues(alpha: 0.1),
                  ),
                ),
                const SizedBox(width: AmberDimens.spacingSm),
                // 置顶按钮
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
                // 移除 onChanged，只通过保存按钮触发保存
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
                  // 移除 onChanged，只通过保存按钮触发保存
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
                onPressed: () => _showDeleteConfirmDialog(),
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
