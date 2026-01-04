import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 日志级别枚举
/// 从低到高：debug < info < warning < error
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// 日志条目，用于异步写入队列
class _LogEntry {
  final LogLevel level;
  final String tag;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  _LogEntry({
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  }) : timestamp = DateTime.now();
}

/// 琥珀清单日志服务
///
/// 设计理念：
/// - Debug 模式：控制台彩色输出，所有级别
/// - Release 模式：只将 warning/error 写入文件
/// - 异步缓冲写入，不阻塞主线程
/// - 文件自动轮转（10MB）和清理（30天）
///
/// 使用方式：
/// ```dart
/// // 初始化（在 main.dart 中调用一次）
/// await AppLogger.instance.init();
///
/// // 任意位置使用
/// AppLogger.debug('SyncManager', '开始同步');
/// AppLogger.info('Database', '数据库已连接');
/// AppLogger.warning('Network', '网络不稳定');
/// AppLogger.error('Sync', '同步失败', e, stackTrace);
/// ```
class AppLogger {
  // ==================== 单例模式 ====================
  static final AppLogger instance = AppLogger._internal();
  factory AppLogger() => instance;
  AppLogger._internal();

  // ==================== 配置常量 ====================

  /// 单个日志文件最大大小（10MB）
  static const int _maxFileSize = 10 * 1024 * 1024;

  /// 日志保留天数
  static const int _retentionDays = 30;

  /// 轮转文件最大数量
  static const int _maxRotatedFiles = 5;

  // ==================== 状态变量 ====================

  /// 日志目录路径
  String? _logDir;

  /// Warning 日志文件
  IOSink? _warningSink;

  /// Error 日志文件
  IOSink? _errorSink;

  /// 异步写入队列
  final StreamController<_LogEntry> _logQueue = StreamController<_LogEntry>();

  /// 是否已初始化
  bool _initialized = false;

  /// 当前 warning 文件大小（估算）
  int _warningFileSize = 0;

  /// 当前 error 文件大小（估算）
  int _errorFileSize = 0;

  // ==================== ANSI 颜色常量（控制台美化）====================
  static const String _reset = '\x1B[0m';
  static const String _bold = '\x1B[1m';
  static const String _dim = '\x1B[2m';
  static const String _red = '\x1B[31m';
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _magenta = '\x1B[35m';
  static const String _cyan = '\x1B[36m';

  // ==================== 静态方法（外部调用）====================

  /// 输出 Debug 级别日志（仅 Debug 模式下显示）
  static void debug(String tag, String message) {
    instance._log(LogLevel.debug, tag, message);
  }

  /// 输出 Info 级别日志
  static void info(String tag, String message) {
    instance._log(LogLevel.info, tag, message);
  }

  /// 输出 Warning 级别日志
  static void warning(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    instance._log(LogLevel.warning, tag, message, error, stackTrace);
  }

  /// 输出 Error 级别日志
  static void error(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    instance._log(LogLevel.error, tag, message, error, stackTrace);
  }

  // ==================== 初始化与销毁 ====================

  /// 初始化日志服务
  ///
  /// - 创建日志目录
  /// - 打开文件句柄
  /// - 启动异步写入监听
  /// - 清理过期日志
  Future<void> init() async {
    if (_initialized) return;

    // Release 模式下才需要文件写入，且仅桌面端支持
    if (!kDebugMode) {
      _logDir = _getLogDirectory();

      // 移动端（Android/iOS）不使用文件日志
      if (_logDir != null && _logDir!.isNotEmpty) {
        // 创建日志目录
        final dir = Directory(_logDir!);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        // 打开文件句柄（追加模式）
        await _openLogFiles();

        // 清理过期日志
        await _cleanOldLogs();

        // 启动异步写入监听
        _startLogListener();
      }
    }

    _initialized = true;

    // 输出初始化成功日志
    final modeInfo = kDebugMode
        ? '（Debug 模式）'
        : (_logDir?.isNotEmpty == true ? '，日志目录: $_logDir' : '（移动端，仅控制台日志）');
    info('AppLogger', '日志服务初始化完成$modeInfo');
  }

  /// 销毁日志服务，关闭文件句柄
  Future<void> dispose() async {
    await _warningSink?.flush();
    await _errorSink?.flush();
    await _warningSink?.close();
    await _errorSink?.close();
    await _logQueue.close();
    _initialized = false;
  }

  // ==================== 核心日志逻辑 ====================

  /// 统一日志处理入口
  void _log(LogLevel level, String tag, String message, [Object? error, StackTrace? stackTrace]) {
    // Debug 模式：所有日志输出到控制台
    if (kDebugMode) {
      _writeToConsole(level, tag, message, error: error, stackTrace: stackTrace);
    } else {
      // Release 模式：只处理 warning 和 error
      if (level == LogLevel.warning || level == LogLevel.error) {
        // 加入异步写入队列
        if (!_logQueue.isClosed) {
          _logQueue.add(_LogEntry(
            level: level,
            tag: tag,
            message: message,
            error: error,
            stackTrace: stackTrace,
          ));
        }
      }
    }
  }

  /// 控制台输出（带颜色美化）
  void _writeToConsole(LogLevel level, String tag, String message, {Object? error, StackTrace? stackTrace}) {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';

    String levelIcon;
    String levelColor;
    String levelName;

    switch (level) {
      case LogLevel.debug:
        levelIcon = '🔵';
        levelColor = _cyan;
        levelName = 'DEBUG';
        break;
      case LogLevel.info:
        levelIcon = '🟢';
        levelColor = _green;
        levelName = 'INFO ';
        break;
      case LogLevel.warning:
        levelIcon = '🟡';
        levelColor = _yellow;
        levelName = 'WARN ';
        break;
      case LogLevel.error:
        levelIcon = '🔴';
        levelColor = _red;
        levelName = 'ERROR';
        break;
    }

    // 格式：[时间] 图标 级别 [Tag] 消息
    final logLine = '$_dim[$timeStr]$_reset $levelIcon $levelColor$_bold$levelName$_reset $_magenta[$tag]$_reset $message';

    // 使用 print 而非 debugPrint，避免 flutter: 前缀，且支持 ANSI 颜色
    // ignore: avoid_print
    print(logLine);

    // 如果有错误信息，额外输出
    if (error != null) {
      // ignore: avoid_print
      print('$_dim    └─ Error: $_reset$_red$error$_reset');
    }
    if (stackTrace != null) {
      final stackLines = stackTrace.toString().split('\n').take(5).join('\n       ');
      // ignore: avoid_print
      print('$_dim    └─ Stack: $_reset$_dim$stackLines$_reset');
    }
  }

  // ==================== 工具方法 ====================

  /// 格式化本地时间为中国友好格式
  /// 输出格式：yyyy-MM-dd HH:mm:ss
  String _formatLocalTime(DateTime dateTime) {
    final year = dateTime.year.toString();
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }

  // ==================== 文件操作 ====================

  /// 获取日志目录路径
  /// 桌面端：~/amber-list/logs/
  /// 移动端：不使用文件日志（在 init() 中判断）
  String _getLogDirectory() {
    String home = '';
    if (Platform.isMacOS) {
      home = Platform.environment['HOME'] ?? '';
    } else if (Platform.isWindows) {
      home = Platform.environment['USERPROFILE'] ?? '';
    } else if (Platform.isLinux) {
      home = Platform.environment['HOME'] ?? '';
    }

    if (home.isEmpty) {
      return ''; // 移动端返回空，在 init() 中跳过文件日志
    }

    return '$home/amber-list/logs';
  }

  /// 打开日志文件（追加模式）
  Future<void> _openLogFiles() async {
    final warningFile = File('$_logDir/warning.log');
    final errorFile = File('$_logDir/error.log');

    // 获取当前文件大小
    if (await warningFile.exists()) {
      _warningFileSize = await warningFile.length();
    }
    if (await errorFile.exists()) {
      _errorFileSize = await errorFile.length();
    }

    _warningSink = warningFile.openWrite(mode: FileMode.append);
    _errorSink = errorFile.openWrite(mode: FileMode.append);
  }

  /// 启动异步写入监听
  void _startLogListener() {
    _logQueue.stream.listen((entry) async {
      await _writeToFile(entry);
    });
  }

  /// 写入日志到文件
  Future<void> _writeToFile(_LogEntry entry) async {
    // 格式化日志行：本地时间|级别|Tag|消息|错误|堆栈
    // 时间格式：yyyy-MM-dd HH:mm:ss（中国友好格式）
    final buffer = StringBuffer();
    buffer.write(_formatLocalTime(entry.timestamp));
    buffer.write('|');
    buffer.write(entry.level.name.toUpperCase());
    buffer.write('|');
    buffer.write(entry.tag);
    buffer.write('|');
    buffer.write(entry.message.replaceAll('\n', '\\n'));

    if (entry.error != null) {
      buffer.write('|');
      buffer.write(entry.error.toString().replaceAll('\n', '\\n'));
    }
    if (entry.stackTrace != null) {
      buffer.write('|');
      buffer.write(entry.stackTrace.toString().replaceAll('\n', '\\n'));
    }
    buffer.writeln();

    final logLine = buffer.toString();
    final lineBytes = logLine.length; // 近似字节数

    // 根据级别写入对应文件
    if (entry.level == LogLevel.warning) {
      _warningSink?.write(logLine);
      _warningFileSize += lineBytes;

      // 检查是否需要轮转
      if (_warningFileSize >= _maxFileSize) {
        await _rotateFile('warning.log');
        _warningFileSize = 0;
      }
    } else if (entry.level == LogLevel.error) {
      _errorSink?.write(logLine);
      _errorFileSize += lineBytes;

      if (_errorFileSize >= _maxFileSize) {
        await _rotateFile('error.log');
        _errorFileSize = 0;
      }
    }
  }

  /// 轮转日志文件
  /// warning.log -> warning.1.log -> warning.2.log ... -> warning.5.log (删除)
  Future<void> _rotateFile(String fileName) async {
    // 先关闭当前文件句柄
    if (fileName == 'warning.log') {
      await _warningSink?.flush();
      await _warningSink?.close();
    } else {
      await _errorSink?.flush();
      await _errorSink?.close();
    }

    final baseName = fileName.replaceAll('.log', '');

    // 删除最老的轮转文件
    final oldestFile = File('$_logDir/$baseName.$_maxRotatedFiles.log');
    if (await oldestFile.exists()) {
      await oldestFile.delete();
    }

    // 依次重命名：4->5, 3->4, 2->3, 1->2
    for (int i = _maxRotatedFiles - 1; i >= 1; i--) {
      final source = File('$_logDir/$baseName.$i.log');
      if (await source.exists()) {
        await source.rename('$_logDir/$baseName.${i + 1}.log');
      }
    }

    // 当前文件 -> .1.log
    final currentFile = File('$_logDir/$fileName');
    if (await currentFile.exists()) {
      await currentFile.rename('$_logDir/$baseName.1.log');
    }

    // 重新打开文件句柄
    if (fileName == 'warning.log') {
      _warningSink = File('$_logDir/$fileName').openWrite(mode: FileMode.append);
    } else {
      _errorSink = File('$_logDir/$fileName').openWrite(mode: FileMode.append);
    }
  }

  /// 清理过期日志文件（超过30天）
  Future<void> _cleanOldLogs() async {
    if (_logDir == null) return;

    final dir = Directory(_logDir!);
    if (!await dir.exists()) return;

    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: _retentionDays));

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.log')) {
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) {
          try {
            await entity.delete();
            // 在 debug 模式下也输出清理信息
            if (kDebugMode) {
              debug('AppLogger', '已清理过期日志: ${entity.path}');
            }
          } catch (e) {
            // 删除失败忽略
          }
        }
      }
    }
  }
}
