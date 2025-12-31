# 日志系统

## 整体架构

```
lib/core/services/
├── logger_service.dart      # 日志服务核心（单例 + 静态方法）
└── config_service.dart      # 现有配置服务（提供路径）

~/amber-list/
├── config.json              # 现有配置
└── logs/                    # 日志目录（Release 模式）
    ├── warning.log          # 警告日志
    └── error.log            # 错误日志
```

## 核心设计

```dart
/// 日志级别
enum LogLevel { debug, info, warning, error }

/// 日志服务 - 单例 + 静态方法
class AppLogger {
  static final AppLogger instance = AppLogger._internal();
  
  // ========== 静态方法（外部调用）==========
  static void debug(String tag, String message);
  static void info(String tag, String message);
  static void warning(String tag, String message);
  static void error(String tag, String message, [Object? error, StackTrace? stack]);
  
  // ========== 配置 ==========
  LogLevel minLevel = LogLevel.debug;        // Debug 模式默认
  LogLevel minFileLevel = LogLevel.warning;  // 文件只记录 warning+
  
  // ========== 内部实现 ==========
  Future<void> init();           // 初始化（创建目录、打开文件）
  void _log(...);                // 核心日志逻辑
  void _writeToConsole(...);     // 控制台输出（带颜色）
  Future<void> _writeToFile(...);// 异步写文件
  Future<void> _rotateIfNeeded();// 文件轮转检查
  Future<void> _cleanOldLogs();  // 清理30天前日志
  Future<void> dispose();        // 关闭资源
}
```

### 关键特性
特性	实现方式
Debug 模式	控制台彩色输出，带时间戳、级别、Tag
Release 模式	只写 warning/error 到文件
异步缓冲	用 StreamController 做写入队列
文件轮转	超 10MB 重命名为 .1.log，最多保留 5 个
30天清理	启动时扫描删除过期日志
美化输出	ANSI 颜色 + 格式化时间戳

### 调用示例

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.instance.init();  // 初始化日志系统
  
  runApp(const MyApp());
}

// 任何地方使用
AppLogger.info('SyncManager', '同步开始');
AppLogger.warning('SyncManager', '网络不稳定');
AppLogger.error('Database', '查询失败', e, stackTrace);
```

Release 模式（文件）：
~/amber-list/logs/warning.log
~/amber-list/logs/error.log