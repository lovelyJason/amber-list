import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// 数据库导入结果
class ImportResult {
  /// 是否成功
  final bool success;

  /// 是否被用户取消
  final bool cancelled;

  /// 错误信息（失败时）
  final String? errorMessage;

  /// 备份文件路径（成功时，如果有备份）
  final String? backupPath;

  ImportResult._({
    required this.success,
    this.cancelled = false,
    this.errorMessage,
    this.backupPath,
  });

  /// 成功
  factory ImportResult.success({String? backupPath}) =>
      ImportResult._(success: true, backupPath: backupPath);

  /// 用户取消
  factory ImportResult.cancelled() =>
      ImportResult._(success: false, cancelled: true);

  /// 错误
  factory ImportResult.error(String message) =>
      ImportResult._(success: false, errorMessage: message);
}

/// 导出服务
class ExportService {
  /// 导出数据库文件
  static Future<String?> exportDatabase() async {
    try {
      final dbDir = await getApplicationDocumentsDirectory();
      final dbPath = '${dbDir.path}/amber_list.db';
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        return null;
      }

      // 选择保存位置
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '导出数据库',
        fileName: 'amber_list_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.db',
        type: FileType.any,
      );

      if (result == null) return null;

      // 复制数据库文件
      await dbFile.copy(result);
      return result;
    } catch (e) {
      return null;
    }
  }

  /// 导入数据库文件
  /// 注意：调用前必须先关闭数据库连接，否则文件可能被锁定
  ///
  /// 返回值：
  /// - null: 用户取消或选择无效文件
  /// - String: 成功时返回备份文件路径（如有）
  static Future<ImportResult> importDatabase() async {
    try {
      // 选择数据库文件
      // 注意：allowedExtensions 只有在 FileType.custom 时才生效
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '导入数据库',
        type: FileType.custom,
        allowedExtensions: ['db', 'sqlite', 'sqlite3'],
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult.cancelled();
      }

      final importPath = result.files.first.path;
      if (importPath == null) {
        return ImportResult.error('无法读取文件路径');
      }

      final importFile = File(importPath);
      if (!await importFile.exists()) {
        return ImportResult.error('文件不存在');
      }

      // 简单校验：检查文件头是否是 SQLite 格式
      // SQLite 文件头的前 16 字节是 "SQLite format 3\0"
      final header = await importFile.openRead(0, 16).first;
      final sqliteHeader = 'SQLite format 3'.codeUnits;
      bool isValidSqlite = header.length >= 15;
      if (isValidSqlite) {
        for (int i = 0; i < 15; i++) {
          if (header[i] != sqliteHeader[i]) {
            isValidSqlite = false;
            break;
          }
        }
      }
      if (!isValidSqlite) {
        return ImportResult.error('文件格式无效，请选择正确的 SQLite 数据库文件');
      }

      // 获取目标路径
      final dbDir = await getApplicationDocumentsDirectory();
      final dbPath = '${dbDir.path}/amber_list.db';
      final walPath = '${dbDir.path}/amber_list.db-wal';
      final shmPath = '${dbDir.path}/amber_list.db-shm';

      String? backupPath;

      // 备份现有数据库
      final currentDb = File(dbPath);
      if (await currentDb.exists()) {
        backupPath = '${dbDir.path}/amber_list_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.db';
        await currentDb.copy(backupPath);
      }

      // 删除 WAL 和 SHM 文件（如果存在）
      // 这些是 SQLite 的 Write-Ahead Logging 文件，导入新数据库时必须清理
      final walFile = File(walPath);
      final shmFile = File(shmPath);
      if (await walFile.exists()) {
        await walFile.delete();
      }
      if (await shmFile.exists()) {
        await shmFile.delete();
      }

      // 复制导入文件
      await importFile.copy(dbPath);

      return ImportResult.success(backupPath: backupPath);
    } catch (e) {
      return ImportResult.error('导入失败: $e');
    }
  }

  /// 导出为JSON格式
  static Future<String?> exportAsJson(Map<String, dynamic> data) async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '导出数据',
        fileName: 'amber_list_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json',
        type: FileType.any,
      );

      if (result == null) return null;

      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      await File(result).writeAsString(jsonStr);
      return result;
    } catch (e) {
      return null;
    }
  }

  /// 从JSON导入
  static Future<Map<String, dynamic>?> importFromJson() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '导入数据',
        type: FileType.any,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return null;

      final importPath = result.files.first.path;
      if (importPath == null) return null;

      final content = await File(importPath).readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// 导出海报图片
  ///
  /// 将图片字节数据保存到用户选择的位置
  /// [imageBytes] 图片的 PNG 字节数据
  /// [fileName] 建议的文件名（如 amber_poster_month_20250113_9x16.png）
  ///
  /// 返回：成功时返回文件路径，用户取消或失败返回 null
  static Future<String?> exportPosterImage(
    Uint8List imageBytes,
    String fileName,
  ) async {
    try {
      // 选择保存位置
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '保存海报',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['png'],
      );

      if (result == null) {
        debugPrint('[ExportService] 用户取消保存海报');
        return null;
      }

      // 确保文件扩展名为 .png
      String savePath = result;
      if (!savePath.toLowerCase().endsWith('.png')) {
        savePath = '$savePath.png';
      }

      // 写入图片文件
      final file = File(savePath);
      await file.writeAsBytes(imageBytes);

      debugPrint('[ExportService] 海报已保存: $savePath');
      return savePath;
    } catch (e) {
      debugPrint('[ExportService] 保存海报失败: $e');
      return null;
    }
  }
}
