import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class MacTrafficLights extends StatefulWidget {
  const MacTrafficLights({super.key});

  @override
  State<MacTrafficLights> createState() => _MacTrafficLightsState();
}

class _MacTrafficLightsState extends State<MacTrafficLights> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(
            color: const Color(0xFFFF5F56), // Red
            icon: Icons.close,
            size: 10,
            onTap: () => windowManager.close(),
          ),
          const SizedBox(width: 8),
          _buildButton(
            color: const Color(0xFFFFBD2E), // Yellow
            icon: Icons.remove,
            size: 10, // Minimize icon is usually just a line
            onTap: () => windowManager.minimize(),
          ),
          const SizedBox(width: 8),
          _buildButton(
            color: const Color(0xFF27C93F), // Green
            icon: Icons.add, // Or simpler maximize icon
            size: 10,
            onTap: () async {
              if (await windowManager.isMaximized()) {
                windowManager.unmaximize();
              } else {
                windowManager.maximize();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
    double size = 12,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: _isHovering ? 1.0 : 0.0,
          child: Icon(
            icon,
            size: 8,
            color: Colors.black.withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}
