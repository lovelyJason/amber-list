# PAK 资源打包方案设计文档

## 背景

Flutter 打包的 Windows/macOS 应用，`flutter_assets/assets/` 目录下所有资源文件都是明文可见的，目录结构完全暴露。即使使用 AES 加密，用户依然可以浏览目录、看到文件名列表。

### 需要解决的问题

1. **目录结构暴露** - 用户可以看到 `audio/`, `images/`, `skins/` 等目录名和文件列表
2. **文件名暴露** - 即使加密了内容，文件名本身可能泄露信息
3. **资源被替换** - 用户可以通过文件名直接替换资源

---

## 解决方案：PAK 打包

将 `flutter_assets/assets/` 目录下的所有文件合并为单个 `resources.pak` 文件，然后删除原目录。

### 核心思路

```
构建前:                           构建后:
flutter_assets/                   flutter_assets/
├── assets/                       └── resources.pak  (单文件，隐藏目录结构)
│   ├── audio/
│   │   └── success.mp3
│   ├── images/
│   │   └── logo.png
│   ├── skins/
│   │   └── default.json
│   └── CHANGELOG.md
└── ...
```

---

## PAK 文件格式

### 文件结构

```
┌────────────────────────────────────────────────┐
│ Header (64 字节)                                │
│   Magic: "APAK" (4 bytes)                      │
│   Version: 1 (1 byte)                          │
│   Reserved (3 bytes)                           │
│   Index Offset (8 bytes, uint64, little-endian)│
│   Index Length (8 bytes, uint64)               │
│   Data Offset (8 bytes, uint64)                │
│   File Count (8 bytes, uint64)                 │
│   Reserved (24 bytes)                          │
├────────────────────────────────────────────────┤
│ Index Section                                   │
│   每个条目:                                     │
│   ├─ PathLength (2 bytes, uint16)              │
│   ├─ Path (UTF-8 字符串)                        │
│   ├─ DataOffset (8 bytes, uint64)              │
│   └─ DataLength (8 bytes, uint64)              │
├────────────────────────────────────────────────┤
│ Data Section                                    │
│   所有文件的原始数据连续存储                     │
└────────────────────────────────────────────────┘
```

### 设计决策

| 决策点 | 选择 | 理由 |
|-------|------|------|
| 是否加密 | 否 | 只需隐藏目录结构，加密已有独立方案 |
| 是否压缩 | 否 | 图片/音频本身已压缩，再压缩收益低 |
| 字节序 | Little-endian | Windows/macOS 主流架构 |
| 索引位置 | Header 之后 | 便于一次性加载索引 |

---

## 架构设计

### 整体架构

```
┌───────────────────────────────────────────────────────────────┐
│                      ResourceManager                          │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                  MemoryCache (LRU)                       │ │
│  └─────────────────────────────────────────────────────────┘ │
│                            ↓                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │ Network  │→ │   PAK    │→ │Encrypted │→ │  Local   │     │
│  │ Provider │  │ Provider │  │ Provider │  │ Provider │     │
│  │(优先级 1) │  │(优先级 50)│  │(优先级 10)│  │(优先级100)│    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘     │
└───────────────────────────────────────────────────────────────┘
```

### Provider 优先级

| Provider | 优先级 | 用途 |
|----------|--------|------|
| NetworkResourceProvider | 1 | 敏感资源从网络加载（微信二维码等） |
| PakResourceProvider | 50 | Release 模式下从 PAK 加载 |
| EncryptedResourceProvider | 10 | 加密资源（AES-256-CBC） |
| LocalResourceProvider | 100 | 原始本地资源（开发调试用） |

### 文件结构

```
lib/core/resource/
├── resource_manager.dart         # 统一入口（已修改，支持 PAK）
├── resource.dart                 # 模块导出文件（已修改）
├── providers/
│   ├── resource_provider.dart    # 抽象接口（已修改，新增 ResourceSource.pak）
│   ├── pak_resource_provider.dart        # PAK 资源加载器（新增）
│   ├── local_resource_provider.dart      # 本地文件加载器
│   ├── encrypted_resource_provider.dart  # 加密资源加载器
│   └── network_resource_provider.dart    # 网络资源加载器
├── security/
│   └── aes_cipher.dart           # AES-256-CBC 加解密
└── cache/
    └── memory_cache.dart         # LRU 内存缓存

scripts/
└── pak_packer.dart               # PAK 打包脚本（新增）
```

---

## 构建流程

### 流程图

```
┌─────────────────┐
│ flutter build   │
│ windows/macos   │
│ --release       │
└────────┬────────┘
         ↓
┌─────────────────┐
│ dart run        │
│ scripts/        │
│ pak_packer.dart │
└────────┬────────┘
         ↓
┌─────────────────┐
│ 打包完成         │
│ resources.pak   │
│ 删除 assets/    │
└─────────────────┘
```

### 命令行使用

```bash
# 1. 构建 Release 版本
flutter build windows --release

# 2. 打包资源
dart run scripts/pak_packer.dart

# 可选参数
dart run scripts/pak_packer.dart --delete-source    # 打包后删除原 assets 目录
dart run scripts/pak_packer.dart --input <path>     # 自定义输入目录
dart run scripts/pak_packer.dart --output <path>    # 自定义输出路径
dart run scripts/pak_packer.dart --help             # 查看帮助
```

### 默认路径

| 平台 | 输入目录 | 输出文件 |
|------|---------|---------|
| Windows | `build/windows/x64/runner/Release/data/flutter_assets/assets` | `build/windows/x64/runner/Release/data/flutter_assets/resources.pak` |
| macOS | `build/macos/Build/Products/Release/<app>.app/Contents/Frameworks/App.framework/Resources/flutter_assets/assets` | 同级 `resources.pak` |

---

## 运行时加载

### 初始化配置

```dart
// main.dart
void _initResourceManager() {
  const networkUrls = <String, String>{
    'images/wechat-add.jpg': 'https://cdn.qdovo.com/hupo/wechat-add.jpg',
  };

  final config = kDebugMode
      ? ResourceConfig.development  // Debug: 不加密、不用 PAK
      : ResourceConfig.production(
          networkUrls: networkUrls,
          enablePak: true,  // Release: 启用 PAK
        );

  ResourceManager.initialize(config);
}
```

### 加载流程

```dart
// 加载资源（自动选择 Provider）
final data = await ResourceManager.instance.load('images/logo.png');

// 加载流程：
// 1. 检查 MemoryCache
// 2. 依次尝试 Provider（按优先级）
//    - NetworkProvider: 检查 URL 映射
//    - PakProvider: 从 PAK 文件读取
//    - EncryptedProvider: 解密 .enc 文件
//    - LocalProvider: 读取原始文件
// 3. 成功后存入 MemoryCache
```

### PakResourceProvider 工作原理

```dart
// 初始化时加载索引（O(n) 一次性操作）
await provider.initialize();
// 解析 Header → 读取 Index Section → 构建 Map<String, PakEntry>

// 加载资源（O(1) 查找 + seek 读取）
final result = await provider.load('images/logo.png');
// _index['images/logo.png'] → seek(offset) → read(length)
```

---

## 打包的资源目录

| 目录 | 说明 |
|------|------|
| `icons/` | 应用图标（当前为空，预留） |
| `images/` | 图片资源 |
| `audio/` | 音频资源 |
| `skins/` | 皮肤主题配置 |
| `CHANGELOG.md` | 更新日志（渲染在设置页面） |

---

## 注意事项

### Debug vs Release

| 模式 | PAK 启用 | 说明 |
|------|----------|------|
| Debug | 否 | 直接读取 `assets/` 目录，便于调试 |
| Release | 是 | 从 `resources.pak` 加载，隐藏目录结构 |

### 性能考虑

1. **索引缓存** - PAK 初始化时一次性加载索引到内存（Map），后续查找 O(1)
2. **RandomAccessFile** - 使用 seek 定位，按需读取，避免加载整个 PAK 到内存
3. **LRU 缓存** - 已加载的资源存入 MemoryCache，避免重复读取

### 兼容性

1. **Fallback 机制** - 如果 PAK 文件不存在或格式错误，自动降级到 LocalProvider
2. **路径统一** - PAK 内使用正斜杠 `/`，跨平台兼容

---

## 相关文件

### 新增文件

| 文件 | 作用 |
|------|------|
| [scripts/pak_packer.dart](../../scripts/pak_packer.dart) | PAK 打包脚本 |
| [lib/core/resource/providers/pak_resource_provider.dart](../../lib/core/resource/providers/pak_resource_provider.dart) | PAK 资源加载 Provider |

### 修改文件

| 文件 | 改动 |
|------|------|
| [lib/core/resource/providers/resource_provider.dart](../../lib/core/resource/providers/resource_provider.dart) | 新增 `ResourceSource.pak` 枚举值 |
| [lib/core/resource/resource.dart](../../lib/core/resource/resource.dart) | 导出 `pak_resource_provider.dart` |
| [lib/core/resource/resource_manager.dart](../../lib/core/resource/resource_manager.dart) | 集成 `PakResourceProvider`，新增 `enablePak` 配置 |

---

## 更新日志

### 2026-01-12

- 设计并实现 PAK 打包方案
- 新增 `pak_packer.dart` 打包脚本
- 新增 `PakResourceProvider` 资源加载器
- 修改 `ResourceManager` 集成 PAK 支持
- 编写设计文档
