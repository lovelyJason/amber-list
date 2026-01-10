import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'amber_toast.dart';
import 'toast_types.dart';
import '../../../../core/utils/sound_service.dart';

export 'toast_types.dart';

class ToastManager {
  static final ToastManager _instance = ToastManager._internal();
  factory ToastManager() => _instance;
  ToastManager._internal();

  final Queue<_ToastRequest> _queue = Queue();
  OverlayEntry? _currentEntry;
  bool _isShowing = false;
  Timer? _timer;

  /// 显示 Toast
  /// [context] 上下文，最好是全局的 NavigatorState context
  /// [message] 只显示文本
  /// [type] 类型：Success, Warning, Error, Info
  /// [duration] 持续时间，默认 2 秒
  /// [position] 位置，默认 Top
  void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 2),
    ToastPosition position = ToastPosition.top,
    bool playSoundOnError = true, // Control sound playback on error
  }) {
    final request = _ToastRequest(
      context: context,
      message: message,
      type: type,
      duration: duration,
      position: position,
    );

    // 播放提示音
    if (type == ToastType.error && playSoundOnError) {
      SoundService().playError();
    }

    _queue.add(request);
    _processQueue();
  }

  /// 直接使用 OverlayState 显示 Toast（绕过 Overlay.of() 查找）
  ///
  /// 用于启动阶段等特殊场景，此时可能没有合适的 context 来调用 Overlay.of()
  /// 通过 NavigatorState.overlay 可以直接获取 OverlayState
  void showWithOverlay(
    OverlayState overlayState,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 2),
    ToastPosition position = ToastPosition.top,
    bool playSoundOnError = true,
  }) {
    final request = _ToastRequestWithOverlay(
      overlayState: overlayState,
      message: message,
      type: type,
      duration: duration,
      position: position,
    );

    // 播放提示音
    if (type == ToastType.error && playSoundOnError) {
      SoundService().playError();
    }

    _overlayQueue.add(request);
    _processOverlayQueue();
  }

  final Queue<_ToastRequestWithOverlay> _overlayQueue = Queue();

  void _processOverlayQueue() {
    if (_isShowing || _overlayQueue.isEmpty) return;

    final request = _overlayQueue.removeFirst();
    _isShowing = true;
    _showOverlayDirect(request);
  }

  void _showOverlayDirect(_ToastRequestWithOverlay request) {
    // 创建 OverlayEntry
    _currentEntry = OverlayEntry(
      builder: (context) => _ToastAnimatorDirect(
        request: request,
        onDismiss: () {
          _removeCurrent();
        },
      ),
    );

    request.overlayState.insert(_currentEntry!);
  }

  void _processQueue() {
    if (_isShowing || _queue.isEmpty) return;

    final request = _queue.removeFirst();
    _isShowing = true;
    _showOverlay(request);
  }

  void _showOverlay(_ToastRequest request) {
    final overlayState = Overlay.of(request.context);
    
    // 创建 OverlayEntry
    _currentEntry = OverlayEntry(
      builder: (context) => _ToastAnimator(
        request: request,
        onDismiss: () {
            _removeCurrent();
        },
      ),
    );

    overlayState.insert(_currentEntry!);

    // 定时移除
    _timer = Timer(request.duration, () {
      // 触发动画退出 -> 实际上 _ToastAnimator 内部处理动画，这里我们只是由于时间到了，
      // 通知 Animator 做退出动画，或者直接硬移除（如果不用反向动画）。
      // 为了支持反向动画，通常由 Animator 自己管理退出。
      // 简单起见，这里我们直接移除，下次可以优化为 key 驱动的反向动画。
      // 由于 OverlayEntry 移除没有内置动画，必须在 builder 里做。
      // 我们这里稍微 hack 一下：让 _ToastAnimator 监听一个 GlobalKey 或者 ValueNotifier 来触发退出。
      
      // 修正：更简单的做法是 Timer 到期时，触发 _currentEntry 重建（如果能）或者通知 Animator。
      // 鉴于 Flutter 的复杂性，最稳健的做法是：
      // _ToastAnimator 内部也维护一个 Timer，或者由 Manager 触发 Animator 的 reverse。
      // 
      // 简化版：这里只是硬等待 duration，然后移除。动画效果由 Animator 的 didMount/dispose 处理？
      // 不，OverlayEntry 移除是瞬间的。必须先播动画。
      
      // 更好的方式：
      // Timer 到时间 -> 通知 Animator "开始退出" -> Animator 播完动画 -> 回调 Manager "已退出" -> Remove Entry.
      // 但这里我们简单点，直接移除，动画仅限入场（或者使用 AnimatedOverlay if needed）。
      // 下面我们用 _ToastAnimator 内部来控制自动消失。
    });
  }

  void _removeCurrent() {
    _timer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;
    _isShowing = false;
    // 继续下一个
    // 稍微延迟一点，避免太快
    Future.delayed(const Duration(milliseconds: 100), () {
        _processQueue();
    });
  }
}

class _ToastRequest {
  final BuildContext context;
  final String message;
  final ToastType type;
  final Duration duration;
  final ToastPosition position;

  _ToastRequest({
    required this.context,
    required this.message,
    required this.type,
    required this.duration,
    required this.position,
  });
}

/// 处理动画和定时逻辑的 Widget wrap
class _ToastAnimator extends StatefulWidget {
  final _ToastRequest request;
  final VoidCallback onDismiss;

  const _ToastAnimator({
    required this.request,
    required this.onDismiss,
  });

  @override
  State<_ToastAnimator> createState() => _ToastAnimatorState();
}

class _ToastAnimatorState extends State<_ToastAnimator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    final alignOffset = _getAlignOffset(widget.request.position);
    _offset = Tween<Offset>(
      begin: alignOffset, // 从偏移处进入
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    // 入场
    _controller.forward();

    // 自动离场计时
    // 减去进出动画时间，预留给展示的时间
    final displayTime = widget.request.duration;
    Future.delayed(displayTime, () {
        if (mounted) {
            _dismiss();
        }
    });
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _getAlignOffset(ToastPosition position) {
    switch (position) {
      case ToastPosition.top:
        return const Offset(0, -1.0);
      case ToastPosition.bottom:
        return const Offset(0, 1.0);
      case ToastPosition.center:
        return const Offset(0, 0.2); // 稍微有点下沉效果
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.request.position == ToastPosition.top ? 50 : null,
      bottom: widget.request.position == ToastPosition.bottom ? 50 : null,
      left: 0,
      right: 0,
      child: Center( // Center horizontally
        child: widget.request.position == ToastPosition.center
            ? Center(child: _buildAnimatedToast()) // Center vertically too if needed, but Positioned constraints make it tricky.
            : _buildAnimatedToast(),
      ),
    );
  }
  
  // 对于 Center 这种特殊情况，可能需要 Stack.fit expand 或 Alignment。
  // 简便起见，top/bottom 用 Positioned，Center 用 SafeArea + Align
  
  // 重新实现 build 以覆盖所有位置
  // 实际上 Overlay 是个 Stack。
  // 我们可以直接返回 Align
  
/*
  @override
  Widget build(BuildContext context) {
    return Align(
        alignment: _getAlignment(widget.request.position),
        child: Padding(
            padding: _getPadding(widget.request.position),
            child: _buildAnimatedToast(),
        ),
    );
  }
*/

  Widget _buildAnimatedToast() {
    return SlideTransition(
      position: _offset,
      child: FadeTransition(
        opacity: _opacity,
        child: Material(
            color: Colors.transparent,
            child: AmberToast(
                message: widget.request.message,
                type: widget.request.type,
            ),
        ),
      ),
    );
  }
}

/// Toast 请求（直接使用 OverlayState，绕过 Overlay.of() 查找）
class _ToastRequestWithOverlay {
  final OverlayState overlayState;
  final String message;
  final ToastType type;
  final Duration duration;
  final ToastPosition position;

  _ToastRequestWithOverlay({
    required this.overlayState,
    required this.message,
    required this.type,
    required this.duration,
    required this.position,
  });
}

/// Toast 动画器（直接使用 OverlayState 版本）
class _ToastAnimatorDirect extends StatefulWidget {
  final _ToastRequestWithOverlay request;
  final VoidCallback onDismiss;

  const _ToastAnimatorDirect({
    required this.request,
    required this.onDismiss,
  });

  @override
  State<_ToastAnimatorDirect> createState() => _ToastAnimatorDirectState();
}

class _ToastAnimatorDirectState extends State<_ToastAnimatorDirect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    final alignOffset = _getAlignOffset(widget.request.position);
    _offset = Tween<Offset>(
      begin: alignOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();

    final displayTime = widget.request.duration;
    Future.delayed(displayTime, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _getAlignOffset(ToastPosition position) {
    switch (position) {
      case ToastPosition.top:
        return const Offset(0, -1.0);
      case ToastPosition.bottom:
        return const Offset(0, 1.0);
      case ToastPosition.center:
        return const Offset(0, 0.2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.request.position == ToastPosition.top ? 50 : null,
      bottom: widget.request.position == ToastPosition.bottom ? 50 : null,
      left: 0,
      right: 0,
      child: Center(
        child: widget.request.position == ToastPosition.center
            ? Center(child: _buildAnimatedToast())
            : _buildAnimatedToast(),
      ),
    );
  }

  Widget _buildAnimatedToast() {
    return SlideTransition(
      position: _offset,
      child: FadeTransition(
        opacity: _opacity,
        child: Material(
          color: Colors.transparent,
          child: AmberToast(
            message: widget.request.message,
            type: widget.request.type,
          ),
        ),
      ),
    );
  }
}
