import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/resource/resource_manager.dart';

/// 安全图片组件
///
/// 从 ResourceManager 加载图片，支持：
/// - 加密资源自动解密
/// - 网络资源自动降级
/// - 加载状态和错误处理
/// - 内存缓存
///
/// 使用示例：
/// ```dart
/// SecureImage(
///   path: 'images/logo.png',
///   width: 100,
///   height: 100,
///   fit: BoxFit.contain,
/// )
/// ```
class SecureImage extends StatefulWidget {
  /// 资源路径（相对于 assets 目录）
  final String path;

  /// 图片宽度
  final double? width;

  /// 图片高度
  final double? height;

  /// 图片填充模式
  final BoxFit? fit;

  /// 图片对齐方式
  final Alignment alignment;

  /// 加载中占位组件
  final Widget? placeholder;

  /// 加载失败占位组件
  final Widget? errorWidget;

  /// 是否使用缓存
  final bool useCache;

  const SecureImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.placeholder,
    this.errorWidget,
    this.useCache = true,
  });

  @override
  State<SecureImage> createState() => _SecureImageState();
}

class _SecureImageState extends State<SecureImage> {
  /// 图片数据
  Uint8List? _imageData;

  /// 加载状态
  bool _isLoading = true;

  /// 是否加载失败
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(SecureImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final data = await ResourceManager.instance.load(
        widget.path,
        useCache: widget.useCache,
      );

      if (!mounted) return;

      if (data != null) {
        setState(() {
          _imageData = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 加载中
    if (_isLoading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.placeholder ?? const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // 加载失败
    if (_hasError || _imageData == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.errorWidget ?? const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.grey),
        ),
      );
    }

    // 显示图片
    return Image.memory(
      _imageData!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: widget.errorWidget ?? const Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.grey),
          ),
        );
      },
    );
  }
}

/// 安全网络图片组件
///
/// 专门用于微信二维码等敏感图片
/// 优先从网络加载，失败时降级到本地加密资源
///
/// 使用示例：
/// ```dart
/// SecureNetworkImage(
///   networkUrl: 'https://cdn.example.com/wechat-qr.jpg',
///   localPath: 'images/wechat-add.jpg',
///   width: 200,
///   height: 200,
/// )
/// ```
class SecureNetworkImage extends StatefulWidget {
  /// 网络图片 URL
  final String networkUrl;

  /// 本地 fallback 路径
  final String localPath;

  /// 图片宽度
  final double? width;

  /// 图片高度
  final double? height;

  /// 图片填充模式
  final BoxFit? fit;

  /// 加载中占位组件
  final Widget? placeholder;

  /// 加载失败占位组件
  final Widget? errorWidget;

  const SecureNetworkImage({
    super.key,
    required this.networkUrl,
    required this.localPath,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<SecureNetworkImage> createState() => _SecureNetworkImageState();
}

class _SecureNetworkImageState extends State<SecureNetworkImage> {
  Uint8List? _imageData;
  bool _isLoading = true;
  bool _hasError = false;
  String _source = '';

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // 尝试网络加载
      final result = await ResourceManager.instance.loadWithResult(widget.localPath);

      if (!mounted) return;

      if (result != null) {
        setState(() {
          _imageData = result.data;
          _source = result.source.name;
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.placeholder ?? const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_hasError || _imageData == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.errorWidget ?? const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.grey),
        ),
      );
    }

    return Image.memory(
      _imageData!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      semanticLabel: 'Source: $_source',
    );
  }
}
