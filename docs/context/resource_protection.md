# 资源保护架构设计文档

## 背景

Flutter 打包的 Windows/macOS 应用，`flutter_assets` 目录下所有资源文件（音频、图片、皮肤）都是明文可见的，用户可以直接访问、提取、甚至替换。

### 需要解决的问题

1. **资源被盗用** - 图片、音效等资源容易被提取复用
2. **资源被篡改** - 用户可以替换资源文件（如微信收款码被替换）
3. **敏感信息暴露** - 微信二维码等包含个人信息

---

## 架构设计

### 核心思路

抽象出 `ResourceManager`，支持多种 Provider（本地/网络/加密），按优先级依次尝试加载。

```
┌─────────────────────────────────────────────────────────┐
│                   ResourceManager                       │
│  ┌─────────────────────────────────────────────────┐   │
│  │              MemoryCache (LRU)                   │   │
│  │      最大 100 条 / 50MB，避免重复解密            │   │
│  └─────────────────────────────────────────────────┘   │
│                        ↓ 按优先级加载                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│  │ Network  │→ │Encrypted │→ │  Local   │             │
│  │ Provider │  │ Provider │  │ Provider │             │
│  │ 优先级 1  │  │ 优先级 10 │  │ 优先级 100│            │
│  │ (微信二维码)│  │(AES加密) │  │(开发调试) │            │
│  └──────────┘  └──────────┘  └──────────┘             │
└─────────────────────────────────────────────────────────┘
```

### 文件结构

```
lib/core/resource/
├── resource_manager.dart         # 统一入口（单例模式）
├── resource.dart                 # 模块导出文件
├── providers/
│   ├── resource_provider.dart    # 抽象接口
│   ├── local_resource_provider.dart       # 本地文件加载
│   ├── network_resource_provider.dart     # 网络下载（OSS/CDN）
│   └── encrypted_resource_provider.dart   # 加密资源（自动解密）
├── security/
│   └── aes_cipher.dart           # AES-256-CBC 加解密
└── cache/
    └── memory_cache.dart         # LRU 内存缓存
```

---

## 加密方案

### 算法选择

- **AES-256-CBC** - 安全性高，性能好
- **Magic Header** - 文件头 `AMBR` + 版本号，便于识别

### 文件格式

```
┌────────────────────────────────────────┐
│  Header (8 bytes)                      │
│  ├─ Magic: "AMBR" (4 bytes)            │
│  ├─ Version: 0x01 (1 byte)             │
│  └─ Reserved (3 bytes)                 │
├────────────────────────────────────────┤
│  Encrypted Data (AES-256-CBC)          │
│  └─ 原始文件内容加密后的数据             │
└────────────────────────────────────────┘
```

### 密钥存储

密钥通过混淆方式存储在代码中：

```dart
// 密钥拆分存储，运行时拼接（增加逆向难度）
final keyParts = [
  [0x41, 0x6D, 0x62, 0x65, 0x72, 0x4C, 0x69, 0x73], // "AmberLis"
  [0x74, 0x53, 0x65, 0x63, 0x75, 0x72, 0x65, 0x4B], // "tSecureK"
  // ...
];
```

> **安全说明**：此方案可防止普通用户直接提取资源，但无法阻止专业逆向工程师。核心目的是增加资源盗用的成本。

---

## Provider 优先级

| Provider | 优先级 | 用途 |
|----------|--------|------|
| NetworkResourceProvider | 1 | 微信二维码等敏感资源，优先从网络加载 |
| EncryptedResourceProvider | 10 | 本地加密资源，AES 解密后返回 |
| LocalResourceProvider | 100 | 原始资源，作为最终 fallback（开发调试用） |

---

## 使用方式

### 1. 初始化（main.dart）

```dart
void _initResourceManager() {
  const networkUrls = <String, String>{
    'images/wechat-add.jpg': 'https://cdn.qdovo.com/hupo/wechat-add.jpg',
    'images/wechat-receive-code.jpg': 'https://cdn.qdovo.com/hupo/wechat-receive-code.jpg',
  };

  final config = kDebugMode
      ? ResourceConfig.development  // Debug: 不加密
      : ResourceConfig.production(networkUrls: networkUrls);  // Release: 启用加密

  ResourceManager.initialize(config);
}
```

### 2. 加载图片资源

```dart
// 推荐：使用 SecureImage 组件（自带 loading 和错误处理）
SecureImage(
  path: 'images/logo.png',
  width: 100,
  height: 100,
)
```

### 3. 加载音频/其他资源（需要原始数据时）

```dart
// 手动加载：拿到 Uint8List 原始数据
final data = await ResourceManager.instance.load('audio/success.mp3');
if (data != null) {
  // 传给音频播放器或做其他处理
  audioPlayer.playBytes(data);
}
```

### 4. 构建时加密资源

```bash
# 运行加密脚本
dart run scripts/encrypt_assets.dart

# 输出示例：
# Processing: images/
#   Encrypted: images/logo.png -> images/logo.png.enc
# ...
# Total: 29 files encrypted
```

---

## 构建流程

### 本地构建（推荐）

```bash
# 一键打包 Windows Release（推荐）
dart run scripts/build_windows_release.dart

# 可选参数
dart run scripts/build_windows_release.dart --skip-encrypt    # 跳过加密，直接用已有的 assets_enc（只改代码没改资源时用）
dart run scripts/build_windows_release.dart --keep-raw-assets # 保留原始资源（包体积翻倍，仅调试用）
dart run scripts/build_windows_release.dart --no-restore      # 不恢复 pubspec.yaml
dart run scripts/build_windows_release.dart --help            # 查看帮助
```

脚本会自动执行以下流程：
1. `flutter pub get` - 获取依赖
2. `encrypt_assets.dart` - 加密资源到 `assets_enc/`
3. 修改 `pubspec.yaml` - 移除原始 assets 配置
4. `flutter build windows --release` - 构建 Release 包
5. 恢复 `pubspec.yaml` - 还原原始配置

输出目录：`build/windows/x64/runner/Release/`

### CI/CD 集成（GitHub Actions）

```yaml
# .github/workflows/build_windows.yml

# 4. 加密资源文件
- name: Encrypt Assets
  run: |
    echo "Encrypting assets..."
    dart run scripts/encrypt_assets.dart
    echo "Assets encrypted successfully"

# 5. Build Windows Release
- name: Build Windows Release
  run: flutter build windows --release
```

### 资源目录配置（pubspec.yaml）

```yaml
flutter:
  assets:
    # 原始资源（开发调试用）
    - assets/icons/
    - assets/images/
    - assets/audio/
    - assets/skins/
    # 加密资源（生产环境使用）
    - assets_enc/icons/
    - assets_enc/images/
    - assets_enc/audio/
    - assets_enc/skins/
```

---

## 安全策略

### 资源分类

| 资源类型 | 保护策略 | 说明 |
|----------|----------|------|
| 微信二维码/收款码 | 网络优先 + 本地加密 fallback | 防止被替换 |
| 图片/皮肤 | 本地 AES 加密 | 防止被提取 |
| 音效 | 本地 AES 加密 | 防止被提取 |
| 通用图标 | 不加密 | 无需保护 |

### 运行模式

| 模式 | 加密启用 | 用途 |
|------|----------|------|
| Debug (kDebugMode) | 否 | 开发调试，直接读取原始资源 |
| Release | 是 | 生产环境，使用加密资源 |

---

## 注意事项

1. **密钥安全**：当前密钥硬编码在代码中，如需更高安全性，可考虑：
   - 从服务器动态获取密钥
   - 使用设备唯一标识生成密钥

2. **性能影响**：
   - 首次加载需要解密，有轻微延迟
   - 解密后会缓存到内存，后续访问无额外开销

3. **调试技巧**：
   - Debug 模式自动禁用加密，无需手动切换
   - 可通过 `ResourceManager.instance.cacheStats` 查看缓存状态

4. **增量加密**：
   - 加密脚本支持增量模式，未修改的文件会跳过

---

## 相关文件

### 新建文件（11 个）

| 文件 | 作用 |
|------|------|
| [lib/core/resource/providers/resource_provider.dart](../../lib/core/resource/providers/resource_provider.dart) | 资源提供者抽象接口 |
| [lib/core/resource/providers/local_resource_provider.dart](../../lib/core/resource/providers/local_resource_provider.dart) | 本地资源加载器 |
| [lib/core/resource/providers/encrypted_resource_provider.dart](../../lib/core/resource/providers/encrypted_resource_provider.dart) | 加密资源加载器（自动解密） |
| [lib/core/resource/providers/network_resource_provider.dart](../../lib/core/resource/providers/network_resource_provider.dart) | 网络资源加载器（OSS/CDN） |
| [lib/core/resource/security/aes_cipher.dart](../../lib/core/resource/security/aes_cipher.dart) | AES-256-CBC 加解密工具 |
| [lib/core/resource/cache/memory_cache.dart](../../lib/core/resource/cache/memory_cache.dart) | LRU 内存缓存 |
| [lib/core/resource/resource_manager.dart](../../lib/core/resource/resource_manager.dart) | 资源管理器统一入口 |
| [lib/core/resource/resource.dart](../../lib/core/resource/resource.dart) | 模块导出文件 |
| [lib/presentation/widgets/secure_image.dart](../../lib/presentation/widgets/secure_image.dart) | 安全图片组件 |
| [scripts/encrypt_assets.dart](../../scripts/encrypt_assets.dart) | 资源加密脚本 |
| [scripts/build_windows_release.dart](../../scripts/build_windows_release.dart) | 本地 Windows Release 打包脚本 |

### 修改文件（4 个）

| 文件 | 改动 |
|------|------|
| [pubspec.yaml](../../pubspec.yaml) | 添加 `encrypt` 依赖 + 加密资源目录 |
| [lib/main.dart](../../lib/main.dart) | 集成 ResourceManager 初始化 |
| [.github/workflows/build_windows.yml](../../.github/workflows/build_windows.yml) | 添加加密步骤 |
| [.gitignore](../../.gitignore) | 忽略 `assets_enc/` 目录 |

---

## 更新日志

### 2026-01-12
- 初始版本
- 实现 ResourceManager + Provider 架构
- 支持 AES-256-CBC 加密
- 支持网络资源优先加载
- 集成 CI/CD 构建流程

## 说明

现在定义了lib/core/resource 加密的核心逻辑和lib/presentation/widgets/secure_image组件， 但是实际上没有去引用，因为这个方案改变不了暴露目录结构的问题，因此先采用PAK合并文件。

**PAK 打包方案已实现**，详见 [pak_packaging.md](./pak_packaging.md)。

PAK 方案将所有 assets 文件合并为单个 `resources.pak` 文件：
- 隐藏目录结构（用户看不到 `audio/`, `images/`, `skins/` 等目录）
- 隐藏文件名列表
- 配合 AES 加密使用，可进一步保护资源内容