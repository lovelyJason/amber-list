import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// 原生便签窗口服务
/// 通过 Platform Channel 与 macOS/Windows 原生代码通信
/// 用于创建、管理和同步便签窗口
class NativeStickyNoteService {
  /// 单例实例
  static final NativeStickyNoteService instance = NativeStickyNoteService._();

  /// Platform Channel 名称（与原生端保持一致）
  static const String _channelName = 'com.amberlist.sticky_note';

  /// Method Channel
  late final MethodChannel _channel;

  /// 任务状态变化回调
  /// 当便签窗口中任务被勾选/取消勾选时触发
  /// 参数：(taskId, isCompleted)
  Function(String taskId, bool isCompleted)? onTaskToggled;

  /// 便签窗口关闭回调
  /// 当便签窗口被关闭时触发
  /// 参数：(noteId)
  Function(String noteId)? onStickyNoteClosed;

  /// 已打开的便签 ID 集合（Flutter 侧维护）
  final Set<String> _openNotes = {};

  NativeStickyNoteService._() {
    _channel = const MethodChannel(_channelName);

    // 设置反向调用处理器（Native → Flutter）
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  /// 检查当前平台是否支持原生便签
  bool get isSupported => Platform.isMacOS || Platform.isWindows;

  /// 处理来自原生端的方法调用
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onTaskToggled':
        final args = call.arguments as Map;
        final taskId = args['taskId'] as String;
        final isCompleted = args['isCompleted'] as bool;
        debugPrint('[NativeStickyNote] 收到任务状态变化: $taskId -> $isCompleted');
        onTaskToggled?.call(taskId, isCompleted);
        return null;

      case 'onStickyNoteClosed':
        final args = call.arguments as Map;
        final noteId = args['id'] as String;
        debugPrint('[NativeStickyNote] 收到窗口关闭通知: $noteId');
        _openNotes.remove(noteId);
        onStickyNoteClosed?.call(noteId);
        return null;

      default:
        debugPrint('[NativeStickyNote] 未知方法调用: ${call.method}');
        return null;
    }
  }

  /// 创建便签窗口
  ///
  /// [id] 便签唯一标识（通常是 listId 或 taskId）
  /// [title] 便签标题
  /// [activeTasks] 未完成任务列表，格式: [{'id': 'xxx', 'title': 'xxx', 'isCompleted': false}]
  /// [completedTasks] 已完成任务列表
  /// [themeColor] 主题色（十六进制字符串，如 "0xFFFFF7D1"）
  ///
  /// 返回：是否创建成功
  Future<bool> createStickyNote({
    required String id,
    required String title,
    required List<Map<String, dynamic>> activeTasks,
    required List<Map<String, dynamic>> completedTasks,
    String themeColor = '0xFFFFF7D1',
  }) async {
    if (!isSupported) {
      debugPrint('[NativeStickyNote] 当前平台不支持原生便签');
      return false;
    }

    // 如果已打开，直接聚焦
    if (_openNotes.contains(id)) {
      debugPrint('[NativeStickyNote] 便签已打开，聚焦: $id');
      return focusStickyNote(id);
    }

    try {
      final result = await _channel.invokeMethod<Map>('createStickyNote', {
        'id': id,
        'title': title,
        'themeColor': themeColor,
        'active': activeTasks,
        'completed': completedTasks,
      });

      final success = result?['success'] == true;
      if (success) {
        _openNotes.add(id);
        debugPrint('[NativeStickyNote] 创建便签成功: $id');
      } else {
        debugPrint('[NativeStickyNote] 创建便签失败: ${result?['error']}');
      }
      return success;
    } on PlatformException catch (e) {
      debugPrint('[NativeStickyNote] 创建便签异常: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[NativeStickyNote] 创建便签错误: $e');
      return false;
    }
  }

  /// 关闭便签窗口
  Future<bool> closeStickyNote(String id) async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<Map>('closeStickyNote', {
        'id': id,
      });

      final success = result?['success'] == true;
      if (success) {
        _openNotes.remove(id);
        debugPrint('[NativeStickyNote] 关闭便签成功: $id');
      }
      return success;
    } on PlatformException catch (e) {
      debugPrint('[NativeStickyNote] 关闭便签异常: ${e.message}');
      return false;
    }
  }

  /// 更新便签内容
  /// 当 Flutter 主窗口中任务状态变化时调用
  Future<bool> updateStickyNote({
    required String id,
    required List<Map<String, dynamic>> activeTasks,
    required List<Map<String, dynamic>> completedTasks,
  }) async {
    if (!isSupported) return false;

    // 只有当便签窗口打开时才更新
    if (!_openNotes.contains(id)) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<Map>('updateStickyNote', {
        'id': id,
        'active': activeTasks,
        'completed': completedTasks,
      });

      final success = result?['success'] == true;
      if (success) {
        debugPrint('[NativeStickyNote] 更新便签成功: $id');
      }
      return success;
    } on PlatformException catch (e) {
      debugPrint('[NativeStickyNote] 更新便签异常: ${e.message}');
      return false;
    }
  }

  /// 聚焦便签窗口
  Future<bool> focusStickyNote(String id) async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<Map>('focusStickyNote', {
        'id': id,
      });

      return result?['success'] == true;
    } on PlatformException catch (e) {
      debugPrint('[NativeStickyNote] 聚焦便签异常: ${e.message}');
      return false;
    }
  }

  /// 检查便签窗口是否打开
  Future<bool> isWindowOpen(String id) async {
    if (!isSupported) return false;

    // 先检查本地缓存
    if (!_openNotes.contains(id)) {
      return false;
    }

    // 向原生端确认
    try {
      final result = await _channel.invokeMethod<Map>('isWindowOpen', {
        'id': id,
      });

      final isOpen = result?['isOpen'] == true;
      // 同步本地状态
      if (!isOpen) {
        _openNotes.remove(id);
      }
      return isOpen;
    } on PlatformException catch (e) {
      debugPrint('[NativeStickyNote] 检查窗口状态异常: ${e.message}');
      return false;
    }
  }

  /// 获取所有已打开的便签 ID
  Set<String> get openNotes => Set.unmodifiable(_openNotes);

  /// 清除所有本地状态（用于重置）
  void clearLocalState() {
    _openNotes.clear();
  }
}
