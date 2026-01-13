import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'widget_skins.dart';

/// 海报视图类型
enum PosterViewType {
  /// 月视图海报
  monthly,
  /// 周视图海报
  weekly,
}

/// 海报风格类型
enum PosterStyleType {
  /// 品牌渐变风格（琥珀橙、纯净白、深空灰、薄荷绿、樱花粉）
  brand,
  /// 创意撞色风格（带水墨背景图）
  creative,
}

/// 海报尺寸类型
enum PosterSizeType {
  /// 9:16 手机竖屏（适合朋友圈/微博）
  vertical9x16,
  /// 1:1 方形（适合 Instagram）
  square1x1,
  /// 16:9 横版（适合电脑端）
  horizontal16x9,
}

/// 海报配置模型
///
/// 存储用户选择的海报生成配置
/// 包括视图类型、风格、尺寸、皮肤等
class PosterConfig {
  /// 视图类型（月视图/周视图）
  final PosterViewType viewType;

  /// 风格类型（品牌渐变/创意撞色）
  final PosterStyleType styleType;

  /// 尺寸类型（9:16/1:1/16:9）
  final PosterSizeType sizeType;

  /// 目标日期（用于获取对应时间段的统计数据）
  final DateTime targetDate;

  /// 皮肤类型（决定配色方案）
  final WidgetSkinType skinType;

  const PosterConfig({
    required this.viewType,
    required this.styleType,
    required this.sizeType,
    required this.targetDate,
    required this.skinType,
  });

  /// 获取海报实际像素尺寸
  ///
  /// 基础宽度 1080px，高度根据比例计算
  /// 导出时会乘以 pixelRatio 获得高清图
  Size getPosterSize() {
    switch (sizeType) {
      case PosterSizeType.vertical9x16:
        return const Size(1080, 1920);
      case PosterSizeType.square1x1:
        return const Size(1080, 1080);
      case PosterSizeType.horizontal16x9:
        return const Size(1920, 1080);
    }
  }

  /// 获取预览尺寸（缩小到屏幕可显示的大小）
  ///
  /// [maxWidth] 最大宽度限制
  /// [maxHeight] 最大高度限制
  Size getPreviewSize({double maxWidth = 400, double maxHeight = 600}) {
    final posterSize = getPosterSize();
    final aspectRatio = posterSize.width / posterSize.height;

    double width = maxWidth;
    double height = width / aspectRatio;

    if (height > maxHeight) {
      height = maxHeight;
      width = height * aspectRatio;
    }

    return Size(width, height);
  }

  /// 获取导出文件名
  ///
  /// 格式：amber_poster_{view}_{date}_{size}.png
  String getFileName() {
    final viewStr = viewType == PosterViewType.monthly ? 'month' : 'week';
    final dateStr = DateFormat('yyyyMMdd').format(targetDate);
    final sizeStr = _getSizeString();
    return 'amber_poster_${viewStr}_${dateStr}_$sizeStr.png';
  }

  String _getSizeString() {
    switch (sizeType) {
      case PosterSizeType.vertical9x16:
        return '9x16';
      case PosterSizeType.square1x1:
        return '1x1';
      case PosterSizeType.horizontal16x9:
        return '16x9';
    }
  }

  /// 获取尺寸显示名称
  String getSizeDisplayName() {
    switch (sizeType) {
      case PosterSizeType.vertical9x16:
        return '竖版 9:16';
      case PosterSizeType.square1x1:
        return '方形 1:1';
      case PosterSizeType.horizontal16x9:
        return '横版 16:9';
    }
  }

  /// 获取皮肤配置
  WidgetSkinConfig get skinConfig => WidgetSkins.getConfig(skinType);

  /// 是否为竖版布局
  bool get isVertical => sizeType == PosterSizeType.vertical9x16;

  /// 是否为方形布局
  bool get isSquare => sizeType == PosterSizeType.square1x1;

  /// 是否为横版布局
  bool get isHorizontal => sizeType == PosterSizeType.horizontal16x9;

  /// 复制并修改配置
  PosterConfig copyWith({
    PosterViewType? viewType,
    PosterStyleType? styleType,
    PosterSizeType? sizeType,
    DateTime? targetDate,
    WidgetSkinType? skinType,
  }) {
    return PosterConfig(
      viewType: viewType ?? this.viewType,
      styleType: styleType ?? this.styleType,
      sizeType: sizeType ?? this.sizeType,
      targetDate: targetDate ?? this.targetDate,
      skinType: skinType ?? this.skinType,
    );
  }

  /// 获取品牌风格可用皮肤列表
  static List<WidgetSkinType> get brandSkins => [
        WidgetSkinType.amber,
        WidgetSkinType.white,
        WidgetSkinType.dark,
        WidgetSkinType.mint,
        WidgetSkinType.pink,
      ];

  /// 获取创意风格可用皮肤列表
  static List<WidgetSkinType> get creativeSkins => [
        WidgetSkinType.contrast01,
        WidgetSkinType.contrast02,
        WidgetSkinType.contrast03,
        WidgetSkinType.contrast04,
        WidgetSkinType.contrast05,
      ];

  /// 根据风格获取可用皮肤列表
  static List<WidgetSkinType> getSkinsForStyle(PosterStyleType style) {
    return style == PosterStyleType.brand ? brandSkins : creativeSkins;
  }
}
