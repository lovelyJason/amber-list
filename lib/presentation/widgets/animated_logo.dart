import 'package:flutter/material.dart';

/// 琥珀 Logo 动画组件 - GIF 播放 3 遍后切换到静态 PNG
///
/// 设计哲学:
/// - 启动时播放 GIF 动画展现琥珀结晶效果
/// - 播放 3 遍后（约 15 秒）自动切换到静态 PNG，节省性能
/// - 使用 Image.asset 的缓存机制，确保两个图片都预加载
class AnimatedLogo extends StatefulWidget {
  final double width;
  final double height;
  final BoxFit fit;

  const AnimatedLogo({
    super.key,
    this.width = 40,
    this.height = 40,
    this.fit = BoxFit.cover,
  });

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo> {
  bool _showGif = true;

  @override
  void initState() {
    super.initState();

    // GIF 每次循环约 5 秒，播放 3 遍后切换到静态图（15 秒）
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) {
        setState(() {
          _showGif = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _showGif
          ? 'assets/images/logo_transparent.gif'
          : 'assets/images/logo_transparent.png',
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      // 预加载失败时的容错处理
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF5A623), // AmberColors.primary
                Color(0xFFD4891C), // AmberColors.primaryDark
              ],
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.bug_report_outlined,
              size: 20,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}
