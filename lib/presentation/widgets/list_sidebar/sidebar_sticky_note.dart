import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/native_sticky_note_service.dart';
import '../../../data/models/models.dart';
import '../../../env/env.dart';
import '../../pages/sticky_note/sticky_note_registry.dart';
import '../../providers/providers.dart';
import '../common/toast/toast_manager.dart';

/// 便签窗口管理
/// 负责创建和管理原生/Flutter便签窗口
///
/// 渲染模式由 .env 中的 STICKY_NOTE_NATIVE_MODE 环境变量控制：
/// - 0: 所有平台使用 Flutter (desktop_multi_window)
/// - 1: 仅 macOS 使用原生，Windows 使用 Flutter（默认推荐）
/// - 2: 仅 Windows 使用原生，macOS 使用 Flutter
/// - 3: 所有平台使用原生渲染
class SidebarStickyNote {
  /// 判断当前平台是否应使用原生便签
  ///
  /// 根据 Env.stickyNoteNativeMode 位标志和当前平台判断
  static bool _shouldUseNativeStickyNote() {
    if (Platform.isMacOS) {
      return Env.macOSUseNativeStickyNote;
    } else if (Platform.isWindows) {
      return Env.windowsUseNativeStickyNote;
    }
    // 其他平台（Linux 等）暂不支持原生便签
    return false;
  }

  /// 打开便签窗口
  /// 根据 STICKY_NOTE_NATIVE_MODE 环境变量决定使用原生还是 Flutter 实现
  static Future<void> showWindow(
    BuildContext context,
    WidgetRef ref,
    TaskList list,
  ) async {
    // 获取当前列表的任务快照
    final allTasks = ref.read(taskProvider);
    final listTasks = allTasks
        .where((t) => t.listId == list.id && !t.isDeleted)
        .toList();

    final activeTasks = listTasks
        .where((t) => !t.isCompleted)
        .map((t) => {'id': t.id, 'title': t.title, 'isCompleted': false})
        .toList();

    final completedTasks = listTasks
        .where((t) => t.isCompleted)
        .map((t) => {'id': t.id, 'title': t.title, 'isCompleted': true})
        .toList();

    // ========== 根据环境变量决定渲染模式 ==========
    final useNative = _shouldUseNativeStickyNote();
    final nativeService = NativeStickyNoteService.instance;

    debugPrint('[StickyNote] 平台: ${Platform.operatingSystem}, '
        '原生模式位标志: ${Env.stickyNoteNativeMode}, '
        '使用原生: $useNative');

    if (useNative && nativeService.isSupported) {
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
        debugPrint('[StickyNote] 原生便签创建失败，降级到 Flutter 多窗口');
      }
    }

    // ========== Flutter 多窗口实现 (desktop_multi_window 0.3.0) ==========
    // 用于配置为 Flutter 渲染的平台，或原生创建失败时的降级方案

    // 检查注册表中是否有该便签的记录
    if (ref.read(stickyNoteRegistryProvider.notifier).isOpen(list.id)) {
      final registeredWindowId =
          ref.read(stickyNoteRegistryProvider.notifier).getWindowId(list.id);

      // 使用 WindowController.getAll() 验证窗口是否真的存在
      bool windowExists = false;
      if (registeredWindowId != null && registeredWindowId.isNotEmpty) {
        try {
          final allWindows = await WindowController.getAll();
          windowExists = allWindows.any((w) => w.windowId == registeredWindowId);
          debugPrint('[StickyNote] 验证窗口 $registeredWindowId 是否存在: $windowExists, '
              '所有窗口: ${allWindows.map((w) => w.windowId).toList()}');
        } catch (e) {
          debugPrint('[StickyNote] 获取子窗口列表失败: $e');
          windowExists = false;
        }
      }

      if (windowExists) {
        // 窗口确实存在，提示用户
        if (context.mounted) {
          ToastManager().show(context, '便签已打开', type: ToastType.info);
        }
        return;
      } else {
        // 窗口已不存在（可能关闭通知丢失），清理注册表
        debugPrint('[StickyNote] 窗口 $registeredWindowId 已不存在，清理注册表');
        ref.read(stickyNoteRegistryProvider.notifier).unregister(list.id);
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

    // 创建独立窗口 (使用新的 WindowController API)
    final windowController = await WindowController.create(
      WindowConfiguration(
        arguments: jsonEncode(data),
        hiddenAtLaunch: true,
      ),
    );

    // 注册窗口到跟踪表
    ref
        .read(stickyNoteRegistryProvider.notifier)
        .register(list.id, windowController.windowId);

    debugPrint('[StickyNote] 创建 Flutter 便签窗口: ${windowController.windowId}');

    // 设置窗口属性并显示
    // 注: 0.3.0 版本窗口大小通过 WindowConfiguration 或者 window_manager 设置
    // 这里通过 invokeMethod 调用窗口内部设置
    await windowController.show();
  }
}