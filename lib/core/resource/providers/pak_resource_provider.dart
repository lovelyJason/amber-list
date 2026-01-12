import 'dart:io';

import 'package:flutter/foundation.dart';

import 'resource_provider.dart';

/// PAK 文件格式常量
///
/// 与 scripts/pak_packer.dart 保持一致
class PakFormat {
  /// Magic Number: "APAK"
  static const List<int> magic = [0x41, 0x50, 0x41, 0x4B];

  /// 当前支持的版本
  static const int version = 1;

  /// Header 固定大小
  static const int headerSize = 64;

  /// 验证 Magic Number
  static bool validateMagic(List<int> data) {
    if (data.length < 4) return false;
    for (var i = 0; i < 4; i++) {
      if (data[i] != magic[i]) return false;
    }
    return true;
  }
}

/// PAK 索引条目
///
/// 记录单个文件在 PAK 中的位置和大小
class PakEntry {
  /// 文件相对路径（如 "images/logo.png"）
  final String path;

  /// 数据在 PAK 文件中的偏移量
  final int offset;

  /// 数据长度（字节）
  final int length;

  PakEntry({
    required this.path,
    required this.offset,
    required this.length,
  });
}

/// PAK 资源提供者
///
/// 从 PAK 打包文件中加载资源，用于 Release 模式隐藏目录结构。
///
/// 特点：
/// - 启动时一次性加载索引到内存（O(1) 查找）
/// - 按需读取文件数据（RandomAccessFile seek）
/// - 自动定位 PAK 文件（相对于可执行文件）
///
/// 使用方式：
/// ```dart
/// // 初始化（通常在 ResourceManager 中自动完成）
/// final provider = PakResourceProvider();
/// await provider.initialize();
///
/// // 加载资源
/// final result = await provider.load('images/logo.png');
/// ```
class PakResourceProvider implements ResourceProvider {
  /// PAK 文件路径
  final String? _customPakPath;

  /// 索引缓存（路径 -> 条目）
  final Map<String, PakEntry> _index = {};

  /// PAK 文件句柄（保持打开状态用于随机读取）
  RandomAccessFile? _pakFile;

  /// 是否已初始化
  bool _initialized = false;

  /// 初始化错误信息
  String? _initError;

  /// 创建 PAK 资源提供者
  ///
  /// [pakPath] 自定义 PAK 文件路径，为 null 时自动定位
  PakResourceProvider({String? pakPath}) : _customPakPath = pakPath;

  /// 初始化 Provider
  ///
  /// 加载 PAK 文件并解析索引
  /// 如果 PAK 文件不存在或格式错误，会静默失败（返回 false）
  Future<bool> initialize() async {
    if (_initialized) return _initError == null;

    try {
      final pakPath = _resolvePakPath();
      final pakFile = File(pakPath);

      if (!pakFile.existsSync()) {
        _initError = 'PAK 文件不存在: $pakPath';
        _log(_initError!);
        _initialized = true;
        return false;
      }

      _pakFile = await pakFile.open(mode: FileMode.read);

      // 解析 Header
      final header = await _pakFile!.read(PakFormat.headerSize);
      if (!_validateHeader(header)) {
        _initError = 'PAK 文件格式无效';
        _log(_initError!);
        await _pakFile!.close();
        _pakFile = null;
        _initialized = true;
        return false;
      }

      // 解析 Header 字段
      final headerData = ByteData.sublistView(header);
      final indexOffset = headerData.getUint64(8, Endian.little);
      final indexLength = headerData.getUint64(16, Endian.little);
      final fileCount = headerData.getUint64(32, Endian.little);

      // 读取索引区
      await _pakFile!.setPosition(indexOffset);
      final indexData = await _pakFile!.read(indexLength);

      // 解析索引
      _parseIndex(indexData, fileCount);

      _log('PAK 初始化成功: $fileCount 个文件');
      _initialized = true;
      return true;
    } catch (e) {
      _initError = 'PAK 初始化失败: $e';
      _log(_initError!);
      _initialized = true;
      return false;
    }
  }

  /// 解析索引数据
  void _parseIndex(Uint8List indexData, int fileCount) {
    final data = ByteData.sublistView(indexData);
    var offset = 0;

    for (var i = 0; i < fileCount; i++) {
      // 读取路径长度
      final pathLength = data.getUint16(offset, Endian.little);
      offset += 2;

      // 读取路径
      final pathBytes = indexData.sublist(offset, offset + pathLength);
      final path = String.fromCharCodes(pathBytes);
      offset += pathLength;

      // 读取数据偏移
      final dataOffset = data.getUint64(offset, Endian.little);
      offset += 8;

      // 读取数据长度
      final dataLength = data.getUint64(offset, Endian.little);
      offset += 8;

      _index[path] = PakEntry(
        path: path,
        offset: dataOffset,
        length: dataLength,
      );
    }
  }

  /// 验证 Header
  bool _validateHeader(Uint8List header) {
    if (header.length < PakFormat.headerSize) return false;

    // 验证 Magic
    if (!PakFormat.validateMagic(header)) return false;

    // 验证版本
    if (header[4] != PakFormat.version) return false;

    return true;
  }

  /// 解析 PAK 文件路径
  String _resolvePakPath() {
    if (_customPakPath != null) return _customPakPath;

    // 默认路径：相对于可执行文件
    // Windows: amber_list.exe 同级的 data/flutter_assets/resources.pak
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return '$exeDir/data/flutter_assets/resources.pak';
  }

  @override
  Future<ResourceResult?> load(String path) async {
    // 确保已初始化
    if (!_initialized) {
      await initialize();
    }

    if (_pakFile == null || _initError != null) {
      return null;
    }

    final entry = _index[path];
    if (entry == null) {
      return null;
    }

    try {
      // Seek 到数据位置
      await _pakFile!.setPosition(entry.offset);

      // 读取数据
      final data = await _pakFile!.read(entry.length);

      return ResourceResult(
        data: Uint8List.fromList(data),
        source: ResourceSource.pak,
      );
    } catch (e) {
      _log('PAK 读取失败 [$path]: $e');
      return null;
    }
  }

  @override
  Future<bool> exists(String path) async {
    // 确保已初始化
    if (!_initialized) {
      await initialize();
    }

    return _index.containsKey(path);
  }

  @override
  int get priority => 50; // 介于 Network (1) 和 Local (100) 之间

  @override
  String get name => 'PakResourceProvider';

  /// 获取已加载的文件数量
  int get fileCount => _index.length;

  /// 获取所有文件路径
  List<String> get allPaths => _index.keys.toList();

  /// 释放资源
  Future<void> dispose() async {
    if (_pakFile != null) {
      await _pakFile!.close();
      _pakFile = null;
    }
    _index.clear();
    _initialized = false;
    _initError = null;
  }

  /// 日志输出
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[PakResourceProvider] $message');
    }
  }
}
