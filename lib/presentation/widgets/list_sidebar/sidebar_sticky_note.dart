import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/native_sticky_note_service.dart';
import '../../../data/models/models.dart';
import '../../pages/sticky_note/sticky_note_registry.dart';
import '../../providers/providers.dart';
import '../common/toast/toast_manager.dart';
import '../common/toast/toast_types.dart';

/// 便签窗口管理
/// 负责创建和管理原生/Flutter便签窗口
class SidebarStickyNote {
  /// 打开便签窗口
  /// 优先使用原生实现（macOS/Windows），fallback 到 Flutter 多窗口
  static Future<void> showWindow(
    BuildContext context,
    WidgetRef ref,
    TaskList list,
  ) async {
    // 获取当前列表的任务快照
    final allTasks = ref.read(taskProvider);
    final listTasks = allTasks.where((t) => t.listId == list.id).toList();

    final activeTasks = listTasks
        .where((t) => !t.isCompleted)
        .map((t) => {'id': t.id, 'title': t.title, 'isCompleted': false})
        .toList();

    final completedTasks = listTasks
        .where((t) => t.isCompleted)
        .map((t) => {'id': t.id, 'title': t.title, 'isCompleted': true})
        .toList();

    // ========== 优先使用原生便签实现 ==========
    final nativeService = NativeStickyNoteService.instance;

    if (nativeService.isSupported) {
      // 检查是否已打开
      final isOpen = await nativeService.isWindowOpen(list.id);
      if (isOpen) {
        // 已打开，聚焦
        await nativeService.focusStickyNote(list.id);
        if (context.mounted) {
          ToastManager().show(context, '便签已打开', type: ToastType.info);
        }
        return;
      }

      // 创建原生便签窗口
      final success = await nativeService.createStickyNote(
        id: list.id,
        title: list.name,
        activeTasks: activeTasks,
        completedTasks: completedTasks,
        themeColor: '0xFFFFF7D1',
      );

      if (success) {
        debugPrint('[StickyNote] 原生便签创建成功: ${list.id}');
        return;
      } else {
        debugPrint('[StickyNote] 原生便签创建失败，尝试 Flutter 多窗口');
      }
    }

    // ========== Fallback: Flutter 多窗口实现 ==========
    // 用于不支持原生便签的平台或原生创建失败时

    // Check if sticky note is already open (Flutter registry)
    if (ref.read(stickyNoteRegistryProvider.notifier).isOpen(list.id)) {
      final windowId =
          ref.read(stickyNoteRegistryProvider.notifier).getWindowId(list.id);
      if (windowId != null) {
        bool isAlive = false;
        try {
          final response = await DesktopMultiWindow.invokeMethod(
            windowId,
            'ping',
            null,
          ).timeout(const Duration(milliseconds: 500));
          if (response == 'pong') {
            isAlive = true;
          }
        } catch (e) {
          isAlive = false;
        }

        if (!isAlive) {
          ref.read(stickyNoteRegistryProvider.notifier).unregister(list.id);
        } else {
          if (context.mounted) {
            ToastManager().show(context, '当前已打开便签', type: ToastType.warning);
          }
          try {
            await DesktopMultiWindow.invokeMethod(windowId, 'focus', null);
          } catch (e) {
            debugPrint('[StickyNote] Focus failed: $e');
          }
          return;
        }
      }
    }

    // 构建结构化数据
    final data = {
      'id': list.id,
      'type': 'sticky_note',
      'title': list.name,
      'themeColor': '0xFFFFF7D1',
      'active': activeTasks,
      'completed': completedTasks,
    };

    // 创建独立窗口
    final window = await DesktopMultiWindow.createWindow(jsonEncode(data));

    // Register window
    ref
        .read(stickyNoteRegistryProvider.notifier)
        .register(list.id, window.windowId);

    // Platform-specific window size
    final size =
        Platform.isMacOS ? const Size(320, 360) : const Size(600, 700);

    window
      ..setFrame(const Offset(0, 0) & size)
      ..center()
      ..setTitle('便签: ${list.name}')
      ..show();
  }
}
