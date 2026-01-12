/// PAK 资源打包脚本
///
/// 将 Flutter 构建产物中的 assets 目录打包成单个 PAK 文件，
/// 隐藏目录结构，防止资源被直接访问。
///
/// 使用方式：
/// ```bash
/// dart run scripts/pak_packer.dart
/// dart run scripts/pak_packer.dart --input <path> --output <path>
/// dart run scripts/pak_packer.dart --help
/// ```
///
/// PAK 文件格式：
/// ```
/// ┌────────────────────────────────────────────────┐
/// │ Header (64 字节)                                │
/// │   Magic: "APAK" (4 bytes)                      │
/// │   Version: 1 (1 byte)                          │
/// │   Reserved (3 bytes)                           │
/// │   Index Offset (8 bytes)                       │
/// │   Index Length (8 bytes)                       │
/// │   Data Offset (8 bytes)                        │
/// │   File Count (8 bytes)                         │
/// │   Reserved (24 bytes)                          │
/// ├────────────────────────────────────────────────┤
/// │ Index Section                                   │
/// │   每个条目: PathLength(2) + Path + Offset(8)   │
/// │             + Length(8)                         │
/// ├────────────────────────────────────────────────┤
/// │ Data Section                                    │
/// │   所有文件的原始数据连续存储                     │
/// └────────────────────────────────────────────────┘
/// ```
library;

import 'dart:io';
import 'dart:typed_data';

/// PAK 文件格式常量
class PakFormat {
  /// Magic Number: "APAK"
  static const List<int> magic = [0x41, 0x50, 0x41, 0x4B];

  /// 当前版本
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

/// 索引条目
class PakEntry {
  final String path;
  final int offset;
  final int length;

  PakEntry({
    required this.path,
    required this.offset,
    required this.length,
  });
}

/// ANSI 颜色代码
class _Colors {
  static const reset = '\x1B[0m';
  static const green = '\x1B[32m';
  static const yellow = '\x1B[33m';
  static const red = '\x1B[31m';
  static const cyan = '\x1B[36m';
  static const bold = '\x1B[1m';
}

/// 打印带颜色的日志
void _log(String message, {String color = _Colors.reset}) {
  print('$color$message${_Colors.reset}');
}

void _logSuccess(String message) {
  _log('  ✓ $message', color: _Colors.green);
}

void _logWarning(String message) {
  _log('  ⚠ $message', color: _Colors.yellow);
}

void _logError(String message) {
  _log('  ✗ $message', color: _Colors.red);
}

/// 显示帮助信息
void _showHelp() {
  print('''
${_Colors.bold}PAK 资源打包脚本${_Colors.reset}

${_Colors.cyan}用法:${_Colors.reset}
  dart run scripts/pak_packer.dart [选项]

${_Colors.cyan}选项:${_Colors.reset}
  --input <path>      输入目录（默认: build/windows/x64/runner/Release/data/flutter_assets/assets）
  --output <path>     输出 PAK 文件路径（默认: 输入目录同级的 resources.pak）
  --delete-source     打包后删除原 assets 目录
  --help              显示此帮助信息

${_Colors.cyan}示例:${_Colors.reset}
  dart run scripts/pak_packer.dart
  dart run scripts/pak_packer.dart --delete-source
  dart run scripts/pak_packer.dart --input ./assets --output ./resources.pak

${_Colors.cyan}PAK 文件格式:${_Colors.reset}
  Header (64 bytes) + Index Section + Data Section
''');
}

/// PAK 打包器
class PakPacker {
  final String inputDir;
  final String outputPath;
  final bool deleteSource;

  PakPacker({
    required this.inputDir,
    required this.outputPath,
    this.deleteSource = false,
  });

  /// 执行打包
  Future<void> pack() async {
    final inputDirectory = Directory(inputDir);
    if (!inputDirectory.existsSync()) {
      throw Exception('输入目录不存在: $inputDir');
    }

    _log('\n${_Colors.bold}开始打包资源...${_Colors.reset}');
    _log('  输入目录: $inputDir');
    _log('  输出文件: $outputPath');

    // 1. 收集所有文件
    final files = await _collectFiles(inputDirectory);
    if (files.isEmpty) {
      _logWarning('没有找到任何文件');
      return;
    }
    _logSuccess('找到 ${files.length} 个文件');

    // 2. 构建索引和写入 PAK
    await _writePak(files);
    _logSuccess('PAK 文件已生成: $outputPath');

    // 3. 可选：删除原目录
    if (deleteSource) {
      await inputDirectory.delete(recursive: true);
      _logSuccess('已删除原 assets 目录');
    }

    // 4. 统计信息
    final pakFile = File(outputPath);
    final pakSize = await pakFile.length();
    _log('\n${_Colors.bold}打包完成！${_Colors.reset}');
    _log('  文件数量: ${files.length}');
    _log('  PAK 大小: ${_formatSize(pakSize)}');
  }

  /// 收集所有文件
  Future<List<FileSystemEntity>> _collectFiles(Directory dir) async {
    final files = <FileSystemEntity>[];

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        files.add(entity);
      }
    }

    // 按路径排序，保证一致性
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  /// 写入 PAK 文件
  Future<void> _writePak(List<FileSystemEntity> files) async {
    final outputFile = File(outputPath);
    final raf = await outputFile.open(mode: FileMode.write);

    try {
      // 准备索引数据
      final entries = <PakEntry>[];
      final indexBuffer = BytesBuilder();

      // 计算数据区起始位置（Header + Index）
      // 先预估索引大小，然后写入
      int currentDataOffset = PakFormat.headerSize;

      // 第一遍：计算索引大小
      for (final file in files) {
        final relativePath = _getRelativePath(file.path);
        final pathBytes = _encodeString(relativePath);
        // PathLength(2) + Path + Offset(8) + Length(8)
        currentDataOffset += 2 + pathBytes.length + 8 + 8;
      }

      final indexOffset = PakFormat.headerSize;
      final indexLength = currentDataOffset - PakFormat.headerSize;
      final dataOffset = currentDataOffset;

      // 第二遍：构建索引并计算每个文件的 offset
      int fileDataOffset = dataOffset;
      for (final file in files) {
        final f = file as File;
        final relativePath = _getRelativePath(f.path);
        final fileLength = await f.length();

        entries.add(PakEntry(
          path: relativePath,
          offset: fileDataOffset,
          length: fileLength,
        ));

        // 写入索引条目
        final pathBytes = _encodeString(relativePath);
        indexBuffer.add(_encodeUint16(pathBytes.length));
        indexBuffer.add(pathBytes);
        indexBuffer.add(_encodeUint64(fileDataOffset));
        indexBuffer.add(_encodeUint64(fileLength));

        fileDataOffset += fileLength;
      }

      // 写入 Header
      await _writeHeader(
        raf,
        indexOffset: indexOffset,
        indexLength: indexLength,
        dataOffset: dataOffset,
        fileCount: files.length,
      );

      // 写入 Index
      await raf.writeFrom(indexBuffer.toBytes());

      // 写入 Data
      for (final file in files) {
        final f = file as File;
        await _writeFileData(raf, f);
      }
    } finally {
      await raf.close();
    }
  }

  /// 写入 Header
  Future<void> _writeHeader(
    RandomAccessFile raf, {
    required int indexOffset,
    required int indexLength,
    required int dataOffset,
    required int fileCount,
  }) async {
    final header = BytesBuilder();

    // Magic (4 bytes)
    header.add(PakFormat.magic);

    // Version (1 byte)
    header.addByte(PakFormat.version);

    // Reserved (3 bytes)
    header.add([0, 0, 0]);

    // Index Offset (8 bytes)
    header.add(_encodeUint64(indexOffset));

    // Index Length (8 bytes)
    header.add(_encodeUint64(indexLength));

    // Data Offset (8 bytes)
    header.add(_encodeUint64(dataOffset));

    // File Count (8 bytes)
    header.add(_encodeUint64(fileCount));

    // Reserved (24 bytes)
    header.add(List.filled(24, 0));

    assert(header.length == PakFormat.headerSize);
    await raf.writeFrom(header.toBytes());
  }

  /// 写入文件数据（分块读取，避免内存爆炸）
  Future<void> _writeFileData(RandomAccessFile pak, File file) async {
    const chunkSize = 1024 * 1024; // 1MB
    final input = await file.open(mode: FileMode.read);

    try {
      while (true) {
        final chunk = await input.read(chunkSize);
        if (chunk.isEmpty) break;
        await pak.writeFrom(chunk);
      }
    } finally {
      await input.close();
    }
  }

  /// 获取相对路径（去除输入目录前缀，统一使用 /）
  String _getRelativePath(String fullPath) {
    var relative = fullPath.replaceAll(r'\', '/');
    final inputNormalized = inputDir.replaceAll(r'\', '/');

    if (relative.startsWith(inputNormalized)) {
      relative = relative.substring(inputNormalized.length);
    }

    // 去除开头的 /
    while (relative.startsWith('/')) {
      relative = relative.substring(1);
    }

    return relative;
  }

  /// 编码字符串为 UTF-8 字节
  Uint8List _encodeString(String s) {
    return Uint8List.fromList(s.codeUnits);
  }

  /// 编码 uint16（小端序）
  Uint8List _encodeUint16(int value) {
    final data = ByteData(2);
    data.setUint16(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  /// 编码 uint64（小端序）
  Uint8List _encodeUint64(int value) {
    final data = ByteData(8);
    data.setUint64(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  /// 格式化文件大小
  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }
}

void main(List<String> args) async {
  // 解析参数
  String? inputDir;
  String? outputPath;
  var deleteSource = false;
  var showHelp = false;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--input':
        if (i + 1 < args.length) {
          inputDir = args[++i];
        }
        break;
      case '--output':
        if (i + 1 < args.length) {
          outputPath = args[++i];
        }
        break;
      case '--delete-source':
        deleteSource = true;
        break;
      case '--help':
      case '-h':
        showHelp = true;
        break;
    }
  }

  if (showHelp) {
    _showHelp();
    return;
  }

  // 默认路径
  inputDir ??= 'build/windows/x64/runner/Release/data/flutter_assets/assets';
  outputPath ??= 'build/windows/x64/runner/Release/data/flutter_assets/resources.pak';

  print('''
${_Colors.bold}${_Colors.cyan}
╔═══════════════════════════════════════════════════════════╗
║              PAK 资源打包工具                              ║
╚═══════════════════════════════════════════════════════════╝
${_Colors.reset}''');

  try {
    final packer = PakPacker(
      inputDir: inputDir,
      outputPath: outputPath,
      deleteSource: deleteSource,
    );

    await packer.pack();
  } catch (e) {
    _logError('打包失败: $e');
    exit(1);
  }
}
