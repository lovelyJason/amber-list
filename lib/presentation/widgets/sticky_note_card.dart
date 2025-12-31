import 'package:flutter/material.dart';
import '../../core/constants/constants.dart';

class StickyNoteCard extends StatefulWidget {
  final String title;
  final Widget content;
  final VoidCallback onClose;
  final Function(double dx, double dy) onResize;

  const StickyNoteCard({
    super.key,
    required this.title,
    required this.content,
    required this.onClose,
    required this.onResize,
  });

  @override
  State<StickyNoteCard> createState() => _StickyNoteCardState();
}

class _StickyNoteCardState extends State<StickyNoteCard> {
  int _colorIndex = 0;
  bool _isPinned = false;
  bool _showColorPicker = false;

  final List<Color> _colors = const [
    Color(0xFFFFF9C4), // Yellow
    Color(0xFFE1F5FE), // Blue
    Color(0xFFFFEBEE), // Pink
    Color(0xFFE8F5E9), // Green
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        color: _colors[_colorIndex],
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar - Draggable
          GestureDetector(
            onPanUpdate: (details) {
              widget.onResize(details.delta.dx, details.delta.dy);
            },
            behavior: HitTestBehavior.translucent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              color: Colors.transparent,
              child: Row(
                children: [
                   // 拖拽区域占位
                   Expanded(
                     child: SizedBox(
                       height: 32, 
                       child: Container(color: Colors.transparent), 
                     ),
                   ),
                   // 操作区
                   if (_showColorPicker) 
                     ..._buildColorPicker()
                   else 
                     ..._buildStandardActions(),
                ],
              ),
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: widget.content),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  List<Widget> _buildStandardActions() {
    return [
      IconButton(
        icon: const Icon(Icons.palette_outlined, size: 16, color: Colors.black54),
        tooltip: '更换皮肤',
        onPressed: () {
          setState(() {
            _showColorPicker = true;
          });
        },
      ),
      IconButton(
        icon: Icon(
          _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
          size: 16,
          color: _isPinned ? AmberColors.primary : Colors.black54,
        ),
        onPressed: () {
          setState(() {
            _isPinned = !_isPinned;
          });
        },
        tooltip: _isPinned ? '取消固定' : '固定便签',
      ),
      IconButton(
        icon: const Icon(Icons.close, size: 16, color: Colors.black54),
        onPressed: widget.onClose,
        tooltip: '关闭',
      ),
    ];
  }

  List<Widget> _buildColorPicker() {
    return [
      ..._colors.asMap().entries.map((entry) {
        final index = entry.key;
        final color = entry.value;
        return GestureDetector(
          onTap: () {
            setState(() {
              _colorIndex = index;
              _showColorPicker = false;
            });
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.black12,
                width: 1,
              ),
              boxShadow: index == _colorIndex ? [
                const BoxShadow(
                   color: Colors.black26, 
                   blurRadius: 2, 
                   offset: Offset(0, 1)
                )
              ] : null,
            ),
            child: index == _colorIndex ? const Icon(Icons.check, size: 10, color: Colors.black54) : null,
          ),
        );
      }),
      const SizedBox(width: 8),
      IconButton(
        icon: const Icon(Icons.close, size: 16, color: Colors.black54),
        onPressed: () {
           setState(() {
             _showColorPicker = false;
           });
        },
        tooltip: '取消',
      ),
    ];
  }
}
