import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 垃圾桶抛物线动画服务
/// 用于在删除任务时显示一个小图标飞向垃圾桶的动画效果
class TrashAnimationService {
  TrashAnimationService._();
  static final TrashAnimationService instance = TrashAnimationService._();

  /// 垃圾桶的全局位置（由侧边栏设置）
  Offset? _trashIconPosition;

  /// 动画时长（毫秒），可调整
  static const int animationDurationMs = 400;

  /// 飞行图标大小
  static const double iconSize = 20.0;

  /// 抛物线高度系数（越大弧度越高）
  static const double parabolaHeight = 80.0;

  /// 设置垃圾桶图标位置
  void setTrashIconPosition(Offset position) {
    _trashIconPosition = position;
  }

  /// 获取垃圾桶位置
  Offset? get trashIconPosition => _trashIconPosition;

  /// 播放抛物线动画
  /// [context] - BuildContext
  /// [startPosition] - 动画起始位置（全局坐标）
  /// [onComplete] - 动画完成后的回调
  void playTrashAnimation(
    BuildContext context,
    Offset startPosition, {
    VoidCallback? onComplete,
  }) {
    if (_trashIconPosition == null) {
      // 没有垃圾桶位置，直接执行回调
      onComplete?.call();
      return;
    }

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _TrashAnimationWidget(
        startPosition: startPosition,
        endPosition: _trashIconPosition!,
        onComplete: () {
          overlayEntry.remove();
          onComplete?.call();
        },
      ),
    );

    overlay.insert(overlayEntry);
  }
}

/// 抛物线动画 Widget
class _TrashAnimationWidget extends StatefulWidget {
  final Offset startPosition;
  final Offset endPosition;
  final VoidCallback onComplete;

  const _TrashAnimationWidget({
    required this.startPosition,
    required this.endPosition,
    required this.onComplete,
  });

  @override
  State<_TrashAnimationWidget> createState() => _TrashAnimationWidgetState();
}

class _TrashAnimationWidgetState extends State<_TrashAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(
        milliseconds: TrashAnimationService.animationDurationMs,
      ),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInQuad,
    );

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final t = _animation.value;

        // 计算抛物线位置
        // 线性插值 x 坐标
        final x = widget.startPosition.dx +
            (widget.endPosition.dx - widget.startPosition.dx) * t;

        // y 坐标使用二次函数实现抛物线效果
        // y = start.y + (end.y - start.y) * t - height * 4 * t * (1 - t)
        final linearY = widget.startPosition.dy +
            (widget.endPosition.dy - widget.startPosition.dy) * t;
        final parabolaOffset =
            TrashAnimationService.parabolaHeight * 4 * t * (1 - t);
        final y = linearY - parabolaOffset;

        // 计算缩放（从 1.0 缩小到 0.5）
        final scale = 1.0 - (t * 0.5);

        // 计算透明度（后半段开始淡出）
        final opacity = t < 0.7 ? 1.0 : (1.0 - (t - 0.7) / 0.3);

        // 计算旋转角度（旋转一圈）
        final rotation = t * math.pi * 2;

        return Positioned(
          left: x - TrashAnimationService.iconSize / 2,
          top: y - TrashAnimationService.iconSize / 2,
          child: Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: rotation,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: const Icon(
                  Icons.description_outlined,
                  size: TrashAnimationService.iconSize,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
