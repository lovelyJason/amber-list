import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/constants.dart';

Future<void> showImagePreviewDialog(
  BuildContext context, {
  required String src,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context),
        child: Stack(
          children: [
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.deferToChild,
                onTap: () {}, // 防止点击图片时触发遮罩关闭
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 6,
                    child: _PreviewImage(src: src),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                tooltip: '关闭',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PreviewImage extends StatelessWidget {
  final String src;

  const _PreviewImage({required this.src});

  @override
  Widget build(BuildContext context) {
    final file = File(src);
    final isFile = src.isNotEmpty && file.existsSync();
    final isHttpUrl = Uri.tryParse(src)?.hasAbsolutePath == true &&
        (src.startsWith('http://') || src.startsWith('https://'));

    final Widget image = isFile
        ? Image.file(file, fit: BoxFit.contain)
        : isHttpUrl
            ? Image.network(src, fit: BoxFit.contain)
            : const SizedBox(
                width: 300,
                height: 200,
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 48,
                    color: AmberColors.textDisabled,
                  ),
                ),
              );

    return Container(
      color: AmberColors.cardBackground,
      child: image,
    );
  }
}

