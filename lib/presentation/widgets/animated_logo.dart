import 'package:flutter/material.dart';

/// 全局状态：GIF 动画是否已经播放完毕
///
/// 用于解决 Drawer 等场景下 Widget 被销毁重建导致 GIF 重复播放的问题
/// 一旦任意一个 AnimatedLogo 播放完毕，所有新建的实例都直接显示静态图
bool _globalGifFinished = false;

/// 琥珀 Logo 动画组件 - GIF 播放 3 遍后切换到静态 PNG
///
/// 设计哲学:
/// - 启动时播放 GIF 动画展现琥珀结晶效果
/// - 播放 3 遍后（约 15 秒）自动切换到静态 PNG，节省性能
/// - 使用全局状态记录播放完成状态，避免 Drawer 等场景重复播放
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
  /// 实例级别的状态，初始值从全局状态读取
  /// 如果全局已经播放完毕，直接显示静态图
  late bool _showGif;

  @override
  void initState() {
    super.initState();

    // 从全局状态初始化：如果已经播放过，直接显示静态图
    _showGif = !_globalGifFinished;

    // 如果还需要播放 GIF，启动定时器
    if (_showGif) {
      // GIF 每次循环约 5 秒，播放 3 遍后切换到静态图（15 秒）
      Future.delayed(const Duration(seconds: 15), () {
        if (mounted) {
          setState(() {
            _showGif = false;
          });
        }
        // 标记全局状态：GIF 已播放完毕，后续所有实例都直接显示静态图
        _globalGifFinished = true;
      });
    }
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
