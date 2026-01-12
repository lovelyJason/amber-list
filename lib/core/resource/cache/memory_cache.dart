import 'dart:collection';
import 'dart:typed_data';

import '../providers/resource_provider.dart';

/// LRU 内存缓存
///
/// 缓存已加载的资源数据，避免重复解密/下载
/// 使用 LRU（Least Recently Used）策略，自动淘汰最久未使用的资源
///
/// 特点：
/// - 线程安全（Dart 单线程模型）
/// - 自动内存管理（限制最大缓存大小）
/// - O(1) 时间复杂度的读写操作
class MemoryCache {
  /// 缓存数据
  final LinkedHashMap<String, _CacheEntry> _cache = LinkedHashMap();

  /// 最大缓存条目数
  final int _maxEntries;

  /// 最大缓存大小（字节）
  final int _maxSizeBytes;

  /// 当前缓存大小（字节）
  int _currentSizeBytes = 0;

  /// 创建内存缓存
  ///
  /// [maxEntries] 最大缓存条目数，默认 100
  /// [maxSizeBytes] 最大缓存大小，默认 50MB
  MemoryCache({
    int maxEntries = 100,
    int maxSizeBytes = 50 * 1024 * 1024,
  })  : _maxEntries = maxEntries,
        _maxSizeBytes = maxSizeBytes;

  /// 获取缓存资源
  ///
  /// [key] 资源路径
  /// 返回缓存的资源结果，如果不存在返回 null
  ResourceResult? get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    // LRU：访问后移到末尾（最近使用）
    _cache.remove(key);
    _cache[key] = entry;

    return ResourceResult(
      data: entry.data,
      source: entry.source,
      fromCache: true,
    );
  }

  /// 存入缓存
  ///
  /// [key] 资源路径
  /// [result] 资源数据
  void put(String key, ResourceResult result) {
    // 如果已存在，先移除旧数据
    if (_cache.containsKey(key)) {
      final oldEntry = _cache.remove(key);
      if (oldEntry != null) {
        _currentSizeBytes -= oldEntry.data.length;
      }
    }

    // 检查是否需要淘汰
    while (_cache.length >= _maxEntries ||
        _currentSizeBytes + result.data.length > _maxSizeBytes) {
      if (_cache.isEmpty) break;

      // 淘汰最久未使用的条目（链表头部）
      final oldestKey = _cache.keys.first;
      final oldestEntry = _cache.remove(oldestKey);
      if (oldestEntry != null) {
        _currentSizeBytes -= oldestEntry.data.length;
      }
    }

    // 存入新数据
    _cache[key] = _CacheEntry(
      data: result.data,
      source: result.source,
    );
    _currentSizeBytes += result.data.length;
  }

  /// 移除缓存
  ///
  /// [key] 资源路径
  void remove(String key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      _currentSizeBytes -= entry.data.length;
    }
  }

  /// 清空缓存
  void clear() {
    _cache.clear();
    _currentSizeBytes = 0;
  }

  /// 检查缓存是否存在
  bool containsKey(String key) => _cache.containsKey(key);

  /// 当前缓存条目数
  int get length => _cache.length;

  /// 当前缓存大小（字节）
  int get sizeBytes => _currentSizeBytes;

  /// 缓存统计信息（用于调试）
  Map<String, dynamic> get stats => {
        'entries': _cache.length,
        'maxEntries': _maxEntries,
        'sizeBytes': _currentSizeBytes,
        'maxSizeBytes': _maxSizeBytes,
        'sizeMB': (_currentSizeBytes / 1024 / 1024).toStringAsFixed(2),
        'maxSizeMB': (_maxSizeBytes / 1024 / 1024).toStringAsFixed(2),
      };
}

/// 缓存条目
class _CacheEntry {
  final Uint8List data;
  final ResourceSource source;

  _CacheEntry({
    required this.data,
    required this.source,
  });
}
