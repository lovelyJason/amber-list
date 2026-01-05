/// 原生窗口配置模型
///
/// 用于传递窗口创建参数和配置信息。
class NativeWindowConfig {
  /// 窗口类型
  final String type;

  /// 窗口实例 ID（可选，支持同类型多窗口）
  final String? id;

  /// 窗口位置 X（可选）
  final double? x;

  /// 窗口位置 Y（可选）
  final double? y;

  /// 窗口宽度
  final double? width;

  /// 窗口高度
  final double? height;

  /// 额外参数
  final Map<String, dynamic>? arguments;

  const NativeWindowConfig({
    required this.type,
    this.id,
    this.x,
    this.y,
    this.width,
    this.height,
    this.arguments,
  });

  /// 转换为 Platform Channel 参数 Map
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      if (id != null) 'id': id,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (arguments != null) ...arguments!,
    };
  }

  /// 从 Map 创建配置
  factory NativeWindowConfig.fromMap(Map<String, dynamic> map) {
    return NativeWindowConfig(
      type: map['type'] as String,
      id: map['id'] as String?,
      x: map['x'] as double?,
      y: map['y'] as double?,
      width: map['width'] as double?,
      height: map['height'] as double?,
      arguments: Map<String, dynamic>.from(map)
        ..remove('type')
        ..remove('id')
        ..remove('x')
        ..remove('y')
        ..remove('width')
        ..remove('height'),
    );
  }
}
