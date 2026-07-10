import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/constants.dart';
import '../../core/services/task_image_service.dart';
import 'image_preview_dialog.dart';

/// 任务图片缩略图预览组件
///
/// 设计理念：
/// - 解析任务描述中的 Markdown 图片语法，提取图片路径
/// - 以横向滚动的缩略图形式展示所有图片
/// - 点击缩略图可放大查看（弹窗）
/// - 支持删除图片（删除时回调通知父组件更新描述）
///
/// 使用方式：
/// ```dart
/// TaskImagePreview(
///   description: task.description,
///   onImageDeleted: (imagePath, newDescription) {
///     // 更新任务描述
///   },
///   readOnly: false,
/// )
/// ```
class TaskImagePreview extends StatelessWidget {
  /// 任务描述文本（包含 Markdown 图片语法）
  final String? description;

  /// 图片删除回调
  /// 参数：被删除的图片路径、删除后的新描述文本
  final void Function(String imagePath, String newDescription)? onImageDeleted;

  /// 是否只读模式（只读模式下不显示删除按钮）
  final bool readOnly;

  const TaskImagePreview({
    super.key,
    required this.description,
    this.onImageDeleted,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    // 提取所有图片路径
    final imagePaths = TaskImageService.extractImagePaths(description);

    // 没有图片时不显示
    if (imagePaths.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AmberDimens.spacingSm),
        // 标题
        Row(
          children: [
            const Icon(
              Icons.image_outlined,
              size: 14,
              color: AmberColors.textDisabled,
            ),
            const SizedBox(width: 4),
            Text(
              '已添加的图片 (${imagePaths.length})',
              style: const TextStyle(
                fontSize: 12,
                color: AmberColors.textDisabled,
              ),
            ),
          ],
        ),
        const SizedBox(height: AmberDimens.spacingXs),
        // 横向滚动的缩略图列表
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: imagePaths.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: AmberDimens.spacingSm),
            itemBuilder: (context, index) {
              final imagePath = imagePaths[index];
              return _ImageThumbnail(
                imagePath: imagePath,
                readOnly: readOnly,
                onTap: () => _showImageDialog(context, imagePath),
                onDelete: readOnly
                    ? null
                    : () => _deleteImage(context, imagePath),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 显示图片放大弹窗
  void _showImageDialog(BuildContext context, String imagePath) {
    showImagePreviewDialog(context, src: imagePath);
  }

  /// 删除图片
  void _deleteImage(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除图片'),
        content: const Text('确定要删除这张图片吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AmberColors.warning,
            ),
            onPressed: () async {
              Navigator.pop(context);

              // 删除文件
              await TaskImageService.deleteImage(imagePath);

              // 更新描述文本
              if (description != null && onImageDeleted != null) {
                final newDescription = TaskImageService.removeImageFromDescription(
                  description!,
                  imagePath,
                );
                onImageDeleted!(imagePath, newDescription);
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 单个图片缩略图组件
class _ImageThumbnail extends StatelessWidget {
  final String imagePath;
  final bool readOnly;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _ImageThumbnail({
    required this.imagePath,
    required this.readOnly,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 图片容器
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AmberDimens.radiusSm),
              border: Border.all(color: AmberColors.divider),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AmberDimens.radiusSm - 1),
              child: Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 24,
                    color: AmberColors.textDisabled,
                  ),
                ),
              ),
            ),
          ),
        ),
        // 删除按钮（只读模式下不显示）
        if (!readOnly && onDelete != null)
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
