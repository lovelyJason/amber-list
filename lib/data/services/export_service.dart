import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

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
  static Future<bool> importDatabase() async {
    try {
      // 选择数据库文件
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '导入数据库',
        type: FileType.any,
        allowedExtensions: ['db'],
      );

      if (result == null || result.files.isEmpty) return false;

      final importPath = result.files.first.path;
      if (importPath == null) return false;

      final importFile = File(importPath);
      if (!await importFile.exists()) return false;

      // 获取目标路径
      final dbDir = await getApplicationDocumentsDirectory();
      final dbPath = '${dbDir.path}/amber_list.db';

      // 备份现有数据库
      final currentDb = File(dbPath);
      if (await currentDb.exists()) {
        final backupPath = '${dbDir.path}/amber_list_backup_${DateTime.now().millisecondsSinceEpoch}.db';
        await currentDb.copy(backupPath);
      }

      // 复制导入文件
      await importFile.copy(dbPath);
      return true;
    } catch (e) {
      return false;
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
}
