import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/constants.dart';
import '../../../../../data/models/models.dart';
import '../../../../providers/task_provider.dart';
import '../../notes_provider.dart';

/// 笔记选择器对话框
///
/// 用于在编辑器中插入笔记关联链接
class NoteLinkPickerDialog extends ConsumerStatefulWidget {
  const NoteLinkPickerDialog({super.key});

  @override
  ConsumerState<NoteLinkPickerDialog> createState() =>
      _NoteLinkPickerDialogState();
}

class _NoteLinkPickerDialogState extends ConsumerState<NoteLinkPickerDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);
    final filteredNotes = _searchQuery.isEmpty
        ? notes
        : notes
            .where((note) =>
                note.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                note.content.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return AlertDialog(
      title: const Text('选择笔记'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          children: [
            // 搜索框
            TextField(
              decoration: const InputDecoration(
                hintText: '搜索笔记...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 16),
            // 笔记列表
            Expanded(
              child: filteredNotes.isEmpty
                  ? const Center(child: Text('没有找到笔记'))
                  : ListView.builder(
                      itemCount: filteredNotes.length,
                      itemBuilder: (context, index) {
                        final note = filteredNotes[index];
                        return _buildNoteItem(note);
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }

  Widget _buildNoteItem(Note note) {
    return ListTile(
      leading: const Icon(Icons.description_outlined),
      title: Text(
        note.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        note.summary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      onTap: () => Navigator.pop(context, note),
    );
  }
}

/// 任务选择器对话框
///
/// 用于在编辑器中插入任务关联链接
class TaskLinkPickerDialog extends ConsumerStatefulWidget {
  const TaskLinkPickerDialog({super.key});

  @override
  ConsumerState<TaskLinkPickerDialog> createState() =>
      _TaskLinkPickerDialogState();
}

class _TaskLinkPickerDialogState extends ConsumerState<TaskLinkPickerDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskProvider);
    final filteredTasks = _searchQuery.isEmpty
        ? tasks.where((t) => !t.isDeleted).toList()
        : tasks
            .where((task) =>
                !task.isDeleted &&
                task.title.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return AlertDialog(
      title: const Text('选择任务'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          children: [
            // 搜索框
            TextField(
              decoration: const InputDecoration(
                hintText: '搜索任务...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 16),
            // 任务列表
            Expanded(
              child: filteredTasks.isEmpty
                  ? const Center(child: Text('没有找到任务'))
                  : ListView.builder(
                      itemCount: filteredTasks.length,
                      itemBuilder: (context, index) {
                        final task = filteredTasks[index];
                        return _buildTaskItem(task);
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }

  Widget _buildTaskItem(Task task) {
    return ListTile(
      leading: Icon(
        task.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
        color: task.isCompleted ? AmberColors.success : AmberColors.textSecondary,
      ),
      title: Text(
        task.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          color: task.isCompleted
              ? AmberColors.textDisabled
              : AmberColors.textPrimary,
        ),
      ),
      onTap: () => Navigator.pop(context, task),
    );
  }
}

/// 显示笔记选择器并返回选中的笔记
Future<Note?> showNoteLinkPicker(BuildContext context) {
  return showDialog<Note>(
    context: context,
    builder: (context) => const NoteLinkPickerDialog(),
  );
}

/// 显示任务选择器并返回选中的任务
Future<dynamic> showTaskLinkPicker(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => const TaskLinkPickerDialog(),
  );
}
