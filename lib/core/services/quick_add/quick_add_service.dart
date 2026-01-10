import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../../utils/date_utils.dart';
import '../native_window/native_window_service.dart';
import '../native_window/window_types.dart';

/// 闪念胶囊服务
///
/// 负责全局热键注册、QuickAdd 窗口管理和任务创建。
/// 这是 Flutter 侧的业务逻辑层，与原生窗口通信。
///
/// 功能：
/// - 注册/注销全局热键 (Cmd/Ctrl + Alt + A)
/// - 显示/隐藏 QuickAdd 窗口
/// - 处理原生窗口的回调（任务创建、取消、日期选择）
/// - 与 TaskProvider 协作创建任务
class QuickAddService {
  QuickAddService();

  /// 原生窗口服务
  NativeWindowService get _windowService => NativeWindowService.instance;

  /// 窗口类型
  String get _windowType => NativeWindowType.quickAdd.value;

  /// 默认热键：Ctrl + Shift + A（双平台统一）
  static HotKey get defaultHotKey => HotKey(
        key: PhysicalKeyboardKey.keyA,
        modifiers: [
          HotKeyModifier.control,
          HotKeyModifier.shift,
        ],
        scope: HotKeyScope.system, // 全局热键
      );

  /// 当前注册的热键
  HotKey? _currentHotKey;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 当前选中的日期（用于日期选择器回调）
  DateTime _selectedDate = DateTime.now();

  /// 任务创建回调（由外部设置，用于创建任务）
  /// 参数：标题, 日期, 优先级(0-3), 标签列表, 任务列表ID（null表示收集箱）
  void Function(String title, DateTime? dueDate, int priority, List<String> tags, String? listId)?
      onTaskCreated;

  /// 笔记创建回调（由外部设置，用于创建笔记）
  /// 参数：内容, 标签列表
  void Function(String content, List<String> tags)? onNoteCreated;

  /// 日期选择器请求回调（由外部设置，用于显示日期选择器）
  void Function(DateTime currentDate, void Function(DateTime) onDateSelected)?
      onDatePickerRequested;

  /// 热键触发回调（由外部设置，用于获取最新数据后显示窗口）
  /// 如果设置了此回调，热键触发时会调用此回调而不是直接显示窗口
  void Function()? onHotKeyTriggered;

  /// 清单选中回调（由外部设置，用于持久化清单选择偏好）
  /// 参数：清单 ID（null 表示收集箱）
  void Function(String? listId)? onListSelected;

  /// 初始化服务
  ///
  /// 注册全局热键和原生窗口回调
  Future<void> initialize({HotKey? customHotKey}) async {
    if (_isInitialized) return;

    // 注册原生窗口回调
    _registerNativeCallbacks();

    // 注册全局热键
    await registerHotKey(customHotKey ?? defaultHotKey);

    _isInitialized = true;
    debugPrint('[QuickAddService] 初始化完成');
  }

  /// 销毁服务
  ///
  /// 注销热键和回调
  Future<void> dispose() async {
    if (!_isInitialized) return;

    // 注销热键
    await unregisterHotKey();

    // 注销原生窗口回调
    _unregisterNativeCallbacks();

    _isInitialized = false;
    debugPrint('[QuickAddService] 已销毁');
  }

  /// 注册全局热键
  Future<void> registerHotKey(HotKey hotKey) async {
    // 先注销旧热键
    if (_currentHotKey != null) {
      await unregisterHotKey();
    }

    try {
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (_) => _onHotKeyPressed(),
      );
      _currentHotKey = hotKey;
      // debugPrint('[QuickAddService] 热键已注册: ${_formatHotKey(hotKey)}');
    } catch (e) {
      debugPrint('[QuickAddService] 热键注册失败: $e');
    }
  }

  /// 注销当前热键
  Future<void> unregisterHotKey() async {
    if (_currentHotKey == null) return;

    try {
      await hotKeyManager.unregister(_currentHotKey!);
      debugPrint('[QuickAddService] 热键已注销');
    } catch (e) {
      debugPrint('[QuickAddService] 热键注销失败: $e');
    }
    _currentHotKey = null;
  }

  /// 显示 QuickAdd 窗口
  ///
  /// [selectedDate] 默认选中的日期
  /// [tags] 可选的标签列表（名称）
  /// [taskLists] 可选的任务列表（id, name）
  /// [selectedListId] 展开模式下默认选中的清单 ID（null 表示收集箱）
  Future<void> showQuickAdd({
    DateTime? selectedDate,
    List<String>? tags,
    List<Map<String, String>>? taskLists,
    String? selectedListId,
  }) async {
    _selectedDate = selectedDate ?? DateTime.now();

    final arguments = <String, dynamic>{
      'selectedDate': _selectedDate.millisecondsSinceEpoch.toDouble(),
      'tags': tags ?? <String>[],
      'taskLists': taskLists ?? <Map<String, String>>[],
    };

    // 如果有上次选中的清单 ID，传递给原生端
    if (selectedListId != null) {
      arguments['selectedListId'] = selectedListId;
    }

    await _windowService.createOrShowWindow(
      type: _windowType,
      arguments: arguments,
    );
    debugPrint('[QuickAddService] QuickAdd 窗口已显示，默认清单: ${selectedListId ?? "收集箱"}');
  }

  /// 隐藏 QuickAdd 窗口
  Future<void> hideQuickAdd() async {
    await _windowService.hideWindow(type: _windowType);
    debugPrint('[QuickAddService] QuickAdd 窗口已隐藏');
  }

  /// 更新选中日期
  Future<void> updateSelectedDate(DateTime date) async {
    _selectedDate = date;

    await _windowService.sendMessage(
      type: _windowType,
      method: 'updateDate',
      arguments: {
        'date': date.millisecondsSinceEpoch.toDouble(),
      },
    );
    debugPrint('[QuickAddService] 日期已更新: $date');
  }

  // ===== 私有方法 =====

  /// 热键按下处理
  void _onHotKeyPressed() {
    debugPrint('[QuickAddService] 热键触发');
    // 如果设置了热键触发回调，调用它（让外部获取数据后显示窗口）
    if (onHotKeyTriggered != null) {
      onHotKeyTriggered!();
    } else {
      // 否则直接显示窗口（不带动态数据）
      showQuickAdd();
    }
  }

  /// 注册原生窗口回调
  void _registerNativeCallbacks() {
    // 任务创建回调
    _windowService.registerCallback(
      _windowType,
      'onQuickAddTaskCreated',
      _handleTaskCreated,
    );

    // 笔记创建回调
    _windowService.registerCallback(
      _windowType,
      'onQuickAddNoteCreated',
      _handleNoteCreated,
    );

    // 取消回调
    _windowService.registerCallback(
      _windowType,
      'onQuickAddCancelled',
      _handleCancelled,
    );

    // 日期选择器请求回调
    _windowService.registerCallback(
      _windowType,
      'onDatePickerRequested',
      _handleDatePickerRequested,
    );

    // 清单选中回调（用于立即持久化）
    _windowService.registerCallback(
      _windowType,
      'onQuickAddListSelected',
      _handleListSelected,
    );

    // debugPrint('[QuickAddService] 原生窗口回调已注册');
  }

  /// 注销原生窗口回调
  void _unregisterNativeCallbacks() {
    _windowService.unregisterCallback(_windowType, 'onQuickAddTaskCreated');
    _windowService.unregisterCallback(_windowType, 'onQuickAddNoteCreated');
    _windowService.unregisterCallback(_windowType, 'onQuickAddCancelled');
    _windowService.unregisterCallback(_windowType, 'onDatePickerRequested');
    _windowService.unregisterCallback(_windowType, 'onQuickAddListSelected');

    debugPrint('[QuickAddService] 原生窗口回调已注销');
  }

  /// 处理任务创建
  void _handleTaskCreated(Map<String, dynamic> arguments) {
    final title = arguments['title'] as String?;
    final dueDateMs = arguments['dueDate'] as double?;
    final hasDate = arguments['hasDate'] as bool? ?? false;
    final priority = (arguments['priority'] as int?) ?? 0;
    final tagsList = arguments['tags'] as List<dynamic>?;
    final tags = tagsList?.map((e) => e.toString()).toList() ?? <String>[];
    final listId = arguments['listId'] as String?; // 任务列表 ID（null 表示收集箱）

    if (title == null || title.isEmpty) return;

    DateTime? dueDate;
    if (hasDate && dueDateMs != null) {
      dueDate = DateTime.fromMillisecondsSinceEpoch(dueDateMs.toInt());
      // 规范化为 UTC 日期
      dueDate = AmberDateUtils.normalizeToUtcDate(dueDate);
    }

    debugPrint(
        '[QuickAddService] 创建任务: $title, 日期: $dueDate, 优先级: $priority, 标签: $tags, 列表: $listId');

    // 调用外部回调创建任务
    onTaskCreated?.call(title, dueDate, priority, tags, listId);
  }

  /// 处理笔记创建
  void _handleNoteCreated(Map<String, dynamic> arguments) {
    // Swift 端发送的参数名是 'title'
    final content = arguments['title'] as String?;
    final tagsList = arguments['tags'] as List<dynamic>?;
    final tags = tagsList?.map((e) => e.toString()).toList() ?? <String>[];

    if (content == null || content.isEmpty) return;

    debugPrint('[QuickAddService] 创建笔记: $content, 标签: $tags');

    // 调用外部回调创建笔记
    onNoteCreated?.call(content, tags);
  }

  /// 处理取消
  void _handleCancelled(Map<String, dynamic> arguments) {
    debugPrint('[QuickAddService] 用户取消输入');
    // 可以在这里添加统计或其他逻辑
  }

  /// 处理日期选择器请求
  void _handleDatePickerRequested(Map<String, dynamic> arguments) {
    final currentDateMs = arguments['currentDate'] as double?;
    final currentDate = currentDateMs != null
        ? DateTime.fromMillisecondsSinceEpoch(currentDateMs.toInt())
        : DateTime.now();

    debugPrint('[QuickAddService] 请求日期选择器，当前日期: $currentDate');

    // 调用外部回调显示日期选择器
    onDatePickerRequested?.call(currentDate, (newDate) {
      updateSelectedDate(newDate);
    });
  }

  /// 处理清单选中（立即持久化）
  void _handleListSelected(Map<String, dynamic> arguments) {
    final listId = arguments['listId'] as String?;

    debugPrint('[QuickAddService] 清单选中: ${listId ?? "收集箱"}');

    // 调用外部回调保存清单选择偏好
    onListSelected?.call(listId);
  }

  /// 格式化热键显示
  String _formatHotKey(HotKey hotKey) {
    final parts = <String>[];

    for (final modifier in hotKey.modifiers ?? <HotKeyModifier>[]) {
      switch (modifier) {
        case HotKeyModifier.meta:
          parts.add(Platform.isMacOS ? '⌘' : 'Win');
          break;
        case HotKeyModifier.control:
          parts.add(Platform.isMacOS ? '⌃' : 'Ctrl');
          break;
        case HotKeyModifier.alt:
          parts.add(Platform.isMacOS ? '⌥' : 'Alt');
          break;
        case HotKeyModifier.shift:
          parts.add('⇧');
          break;
        default:
          break;
      }
    }

    // 添加主键
    final keyLabel = hotKey.key.keyLabel;
    parts.add(keyLabel);

    return parts.join(' + ');
  }
}

/// QuickAddService 的 Provider
final quickAddServiceProvider = Provider<QuickAddService>((ref) {
  return QuickAddService();
});
