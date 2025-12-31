import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';

import '../../../core/constants/constants.dart';

class StickyNotePage extends StatefulWidget {
  final int windowId;
  final Map<String, dynamic> args;

  const StickyNotePage({
    super.key,
    required this.windowId,
    required this.args,
  });

  @override
  State<StickyNotePage> createState() => _StickyNotePageState();
}

class _StickyNotePageState extends State<StickyNotePage> {
  bool _isPinned = true;
  late Color _backgroundColor;
  bool _showColorPicker = false;
  // _isClosing is no longer needed if we don't intercept 'X'
  

  final List<Color> _colors = const [
    Color(0xFFFFF7D1), // Yellow (Default)
    Color(0xFFE1F5FE), // Blue
    Color(0xFFFFEBEE), // Pink
    Color(0xFFE8F5E9), // Green
  ];

  // Helper to manually notify main (e.g. if we add a custom close button later)
  Future<void> _notifyClose() async {
    final contentId = widget.args['id'] as String?;
    if (contentId != null) {
      try {
        await DesktopMultiWindow.invokeMethod(0, 'stickyNoteClosed', contentId);
      } catch (e) {
        debugPrint('Failed to notify close: $e');
      }
    }
  }
  
  // Custom close method (if invoked by UI button)
  void _closeWindow() async {
    // 1. Notify
    await _notifyClose();
    // 2. Close
    await WindowManager.instance.close();
  }

  @override
  void initState() {
    super.initState();
    // Initialize color from args or default to yellow
    if (widget.args['themeColor'] != null) {
        _backgroundColor = Color(int.parse(widget.args['themeColor']));
    } else {
      _backgroundColor = _colors[0];
    }
    
    // Default always on top
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WindowManager.instance.setAlwaysOnTop(true);
    });

    // Listen for updates from Main Window
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      if (call.method == 'updateTask') {
        final args = call.arguments as Map;
        final taskId = args['id'] as String;
        final isCompleted = args['isCompleted'] as bool;
        _handleTaskUpdate(taskId, isCompleted);
        return 'ok';
      } else if (call.method == 'ping') {
        return 'pong';
      }
      return null;
    });
    
    // NO WindowListener
    // NO setPreventClose
  }

  @override
  void dispose() {
    super.dispose();
  }


  
  void _togglePin() async {
    setState(() {
      _isPinned = !_isPinned;
    });
    await WindowManager.instance.setAlwaysOnTop(_isPinned);
  }



  void _handleTaskUpdate(String taskId, bool isCompleted) {
    if (!mounted) return;

    setState(() {
      // Find the task in active or completed lists
      final activeList = widget.args['active'] as List?;
      final completedList = widget.args['completed'] as List?;

      Map<String, dynamic>? taskMap;

      // Helper to find and remove
      if (activeList != null) {
        final index = activeList.indexWhere((t) => t['id'] == taskId);
        if (index != -1) {
          taskMap = activeList.removeAt(index);
        }
      }

      if (taskMap == null && completedList != null) {
        final index = completedList.indexWhere((t) => t['id'] == taskId);
        if (index != -1) {
          taskMap = completedList.removeAt(index);
        }
      }

      if (taskMap != null) {
        // Update status
        taskMap['isCompleted'] = isCompleted;

        // Re-insert into correct list
        if (isCompleted) {
          if (widget.args['completed'] == null) widget.args['completed'] = [];
          (widget.args['completed'] as List).add(taskMap);
        } else {
          if (widget.args['active'] == null) widget.args['active'] = [];
          (widget.args['active'] as List).add(taskMap);
        }
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final title = widget.args['title'] ?? '便签';
    final content = widget.args['content']; // String for single task
    final activeList = widget.args['active'] as List?; // List for checklist
    final completedList = widget.args['completed'] as List?;

    return Scaffold(
      backgroundColor: Colors.transparent, // Transparent for rounded corners
      body: Container(
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.zero, 
          boxShadow: [
             BoxShadow(
               color: Colors.black.withOpacity(0.2),
               blurRadius: 10,
               offset: const Offset(0, 4),
             )
          ],
          border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
        ),
        child: Column(
          children: [
            // === Drag Header ===
            GestureDetector(
                onPanStart: (_) {
                     WindowManager.instance.startDragging();
                },
                behavior: HitTestBehavior.translucent, // Allow dragging on empty space
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  color: Colors.black.withOpacity(0.02), // Slight tint for header area
                  child: Row(
                    children: [
                        const Icon(FluentIcons.note_24_regular, size: 16, color: AmberColors.textSecondary),
                        const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '琥珀便签',
                        style: TextStyle(
                          fontSize: Platform.isMacOS ? 12 : 13,
                          color: AmberColors.textSecondary,
                          fontWeight: Platform.isMacOS ? null : FontWeight.w500,
                        ),
                        maxLines: Platform.isMacOS ? null : 1,
                        overflow: Platform.isMacOS
                            ? null
                            : TextOverflow.ellipsis,
                      ),
                    ),
                        
                    if (_showColorPicker)
                      ..._buildColorPicker()
                    else
                      ..._buildStandardActions(),
                    ],
                  ),
                ),
            ),
            
            // === Content ===
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(
                            title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                    // Scenario A: Single Item Note (Legacy/String content)
                    if (content != null &&
                        content is String &&
                        content.isNotEmpty)
                      Expanded( 
                        child: SingleChildScrollView(
                          child: Text(
                            content,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),

                    // Scenario B: Checkbox List
                    if (activeList != null || completedList != null)
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            if (activeList != null)
                              ...activeList
                                  .map((item) => _buildCheckItem(item, false))
                                  .toList(),

                            if (activeList != null &&
                                activeList.isNotEmpty &&
                                completedList != null &&
                                completedList.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Divider(
                                  color: Colors.black.withOpacity(0.1),
                                  height: 1,
                                ),
                              ),

                            if (completedList != null)
                              ...completedList
                                  .map((item) => _buildCheckItem(item, true))
                                  .toList(),
                          ],
                        ),
                      ),

                    // Fallback
                    if ((content == null ||
                            (content is String && content.isEmpty)) &&
                        activeList == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          '暂无内容',
                          style: TextStyle(color: Colors.black54, fontSize: 14),
                        ),
                      ),
                    ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStandardActions() {
    return [
      IconButton(
        icon: const Icon(
          FluentIcons.color_24_regular,
          size: 16,
          color: AmberColors.textSecondary,
        ),
        onPressed: () => setState(() => _showColorPicker = true),
        splashRadius: 12,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        tooltip: '更换皮肤',
      ),
      IconButton(
        icon: Icon(
          _isPinned ? FluentIcons.pin_24_filled : FluentIcons.pin_24_regular,
          size: 16,
          color: _isPinned ? AmberColors.primary : AmberColors.textSecondary,
        ),
        onPressed: _togglePin,
        splashRadius: 12,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        tooltip: _isPinned ? '取消固定' : '固定便签',
      ),
      IconButton(
        icon: const Icon(
          FluentIcons.dismiss_24_regular,
          size: 16,
          color: AmberColors.textSecondary,
        ),
        onPressed: _closeWindow,
        splashRadius: 12,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        tooltip: '关闭',
      ),
    ];
  }

  List<Widget> _buildColorPicker() {
    return [
      ..._colors.map((color) {
        final isSelected = _backgroundColor.value == color.value;
        return GestureDetector(
          onTap: () {
            setState(() {
              _backgroundColor = color;
              _showColorPicker = false;
            });
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black12, width: 1),
              boxShadow: isSelected
                  ? [
                      const BoxShadow(
                        color: Colors.black26,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
      const SizedBox(width: 4),
      IconButton(
        icon: const Icon(
          FluentIcons.dismiss_20_regular,
          size: 14,
          color: AmberColors.textSecondary,
        ),
        onPressed: () => setState(() => _showColorPicker = false),
        splashRadius: 10,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      ),
    ];
  }


  Widget _buildCheckItem(dynamic itemMap, bool completed) {
    // Handle both pure string (legacy mock) vs Map
    final String title;
    final String id;

    if (itemMap is String) {
      title = itemMap;
      id = '';
    } else {
      title = itemMap['title'];
      id = itemMap['id'];
    }
      
      return Padding(
          padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () async {
          if (id.isEmpty) return; // Cannot toggle legacy items

          // 1. Optimistic Update (Visual)
          setState(() {
            // Move item between lists locally for immediate feedback
            if (completed) {
              // Move to active
              if (widget.args['completed'] != null)
                (widget.args['completed'] as List).remove(itemMap);
              itemMap['isCompleted'] = false;
              if (widget.args['active'] == null) widget.args['active'] = [];
              (widget.args['active'] as List).add(itemMap);
            } else {
              // Move to completed
              if (widget.args['active'] != null)
                (widget.args['active'] as List).remove(itemMap);
              itemMap['isCompleted'] = true;
              if (widget.args['completed'] == null)
                widget.args['completed'] = [];
              (widget.args['completed'] as List).add(itemMap);
            }
          });

          // 2. Send Message to Main Window
          try {
            await DesktopMultiWindow.invokeMethod(0, 'toggleTask', id);
          } catch (e) {
            debugPrint('Failed to toggle task: $e');
          }
        },
        child: Row(
          children: [
            Icon(
              completed
                  ? FluentIcons.checkbox_checked_24_filled
                  : FluentIcons.checkbox_unchecked_24_regular,
              size: 20,
              color: completed ? Colors.grey : Colors.black87,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: completed ? Colors.grey : Colors.black87,
                  decoration: completed ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
          ),
      );
  }
}
