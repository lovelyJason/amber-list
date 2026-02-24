import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:super_clipboard/super_clipboard.dart';

/// 任务图片管理服务
///
/// 职责：
/// - 从剪切板读取图片数据
/// - 保存图片到 ~/.amber-list/images/tasks/ 目录
/// - 返回本地文件路径供任务描述字段引用
/// - 支持删除任务图片
///
/// 图片存储路径格式：
/// ~/.amber-list/images/tasks/task_{timestamp}.png
///
/// 使用方式：
/// ```dart
/// // 从剪切板粘贴图片
/// final imagePath = await TaskImageService.pasteImageFromClipboard();
/// if (imagePath != null) {
///   // 在描述中插入 Markdown 图片语法
///   description += '\n![image]($imagePath)';
/// }
/// ```
class TaskImageService {
  /// 获取图片存储目录路径
  /// 桌面端：~/.amber-list/images/tasks/
  static String _getImageDirectory() {
    String home = '';
    if (Platform.isMacOS) {
      home = Platform.environment['HOME'] ?? '';
    } else if (Platform.isWindows) {
      home = Platform.environment['USERPROFILE'] ?? '';
    } else if (Platform.isLinux) {
      home = Platform.environment['HOME'] ?? '';
    }

    if (home.isEmpty) {
      // 移动端不支持，返回空
      return '';
    }

    return '$home/.amber-list/images/tasks';
  }

  /// 确保图片存储目录存在
  static Future<Directory?> _ensureImageDirectory() async {
    final dirPath = _getImageDirectory();
    if (dirPath.isEmpty) return null;

    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 从剪切板读取图片并保存到本地
  ///
  /// 返回保存后的文件路径，失败返回 null
  ///
  /// 支持的图片格式：PNG、JPEG、TIFF（macOS 截图）
  static Future<String?> pasteImageFromClipboard() async {
    try {
      // 确保目录存在
      final dir = await _ensureImageDirectory();
      if (dir == null) {
        debugPrint('[TaskImageService] 图片目录不可用（可能是移动端）');
        return null;
      }

      // 使用 super_clipboard 读取剪切板
      final clipboard = SystemClipboard.instance;
      if (clipboard == null) {
        debugPrint('[TaskImageService] 剪切板不可用');
        return null;
      }

      final reader = await clipboard.read();

      // 生成文件名：task_{timestamp}.png
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'task_$timestamp.png';
      final filePath = '${dir.path}/$fileName';

      // 使用 Completer 处理异步回调
      final completer = Completer<String?>();

      // 尝试读取 PNG 格式（super_clipboard 会自动将其他格式转换为 PNG）
      if (reader.canProvide(Formats.png)) {
        reader.getFile(Formats.png, (file) async {
          try {
            final stream = file.getStream();
            final bytes = await _streamToBytes(stream);

            if (bytes.isNotEmpty) {
              final outFile = File(filePath);
              await outFile.writeAsBytes(bytes);
              debugPrint('[TaskImageService] 图片已保存: $filePath (${bytes.length} bytes)');
              completer.complete(filePath);
            } else {
              debugPrint('[TaskImageService] 图片数据为空');
              completer.complete(null);
            }
          } catch (e) {
            debugPrint('[TaskImageService] 保存图片失败: $e');
            completer.complete(null);
          }
        }, onError: (error) {
          debugPrint('[TaskImageService] 读取图片失败: $error');
          completer.complete(null);
        });
      } else {
        debugPrint('[TaskImageService] 剪切板中没有图片');
        completer.complete(null);
      }

      return completer.future;
    } catch (e, stack) {
      debugPrint('[TaskImageService] 粘贴图片失败: $e');
      debugPrint('[TaskImageService] Stack: $stack');
      return null;
    }
  }

  /// 将 Stream<Uint8List> 转换为 Uint8List
  static Future<Uint8List> _streamToBytes(Stream<Uint8List> stream) async {
    final chunks = <Uint8List>[];
    await for (final chunk in stream) {
      chunks.add(chunk);
    }

    // 合并所有 chunks
    final totalLength = chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final result = Uint8List(totalLength);
    var offset = 0;
    for (final chunk in chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return result;
  }

  /// 检查剪切板是否有图片
  ///
  /// 用于 UI 层判断是否显示粘贴图片提示
  static Future<bool> hasImageInClipboard() async {
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard == null) return false;

      final reader = await clipboard.read();
      // super_clipboard 会自动将各种图片格式转换为 PNG
      return reader.canProvide(Formats.png);
    } catch (e) {
      debugPrint('[TaskImageService] 检查剪切板图片失败: $e');
      return false;
    }
  }

  /// 删除任务图片
  ///
  /// [imagePath] 图片文件的完整路径
  static Future<void> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[TaskImageService] 图片已删除: $imagePath');
      }
    } catch (e) {
      debugPrint('[TaskImageService] 删除图片失败: $e');
    }
  }

  /// 从描述文本中提取所有图片路径
  ///
  /// 解析 Markdown 图片语法：![alt](path)
  /// 返回所有匹配的图片路径列表
  static List<String> extractImagePaths(String? description) {
    if (description == null || description.isEmpty) {
      return [];
    }

    // 匹配 Markdown 图片语法：![任意文字](路径)
    // 路径需要包含 .amber-list/images/tasks 以确保是任务图片
    final regex = RegExp(r'!\[.*?\]\((.*?\.amber-list/images/tasks/[^)]+)\)');
    final matches = regex.allMatches(description);

    return matches.map((match) => match.group(1)!).toList();
  }

  /// 从描述文本中移除指定图片的 Markdown 语法
  ///
  /// [description] 原始描述文本
  /// [imagePath] 要移除的图片路径
  /// 返回移除后的描述文本
  static String removeImageFromDescription(
      String description, String imagePath) {
    // 转义路径中的特殊正则字符
    final escapedPath = imagePath.replaceAllMapped(
      RegExp(r'[.*+?^${}()|[\]\\]'),
      (match) => '\\${match.group(0)}',
    );

    // 匹配包含该路径的 Markdown 图片语法，包括可能的换行
    final regex = RegExp('\\n?!\\[.*?\\]\\($escapedPath\\)\\n?');
    return description.replaceAll(regex, '\n').trim();
  }
}
