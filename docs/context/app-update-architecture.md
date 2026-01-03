# 应用更新功能架构文档

## 概述

应用更新功能支持全平台（macOS、Windows、Android、iOS）的版本检查与更新。

**实现时间**: 2025-01-03
**架构模式**: Service + Provider + UI 分层

---

## 文件结构

```
lib/
├── data/
│   ├── models/
│   │   └── app_update_info.dart          # 更新信息数据模型
│   └── services/
│       └── update/
│           └── app_update_service.dart   # 更新服务核心（HTTP请求、版本比较）
├── presentation/
│   ├── providers/
│   │   └── app_update_provider.dart      # 状态管理（Riverpod）
│   ├── widgets/
│   │   └── app_update_dialog.dart        # 更新弹窗 + 强制更新页面
│   └── pages/settings/tabs/
│       └── about_tab.dart                # 集成"检查更新"按钮
└── app.dart                              # 启动时自动检查更新
```

---

## 核心设计原则

### 1. 服务端驱动

版本信息通过远程 JSON API 获取，支持动态控制更新策略。

### 2. 强制更新机制

当用户版本低于 `minimum_version` 时，显示全屏拦截页面，必须更新才能使用。

### 3. 平台差异化

根据当前平台自动选择对应的下载链接（DMG/EXE/APK/App Store）。

### 4. 非阻塞启动

使用 `addPostFrameCallback` 延迟检查更新，不影响应用启动速度。

---

## 数据模型

### AppUpdateInfo

```dart
class AppUpdateInfo {
  final String latestVersion;      // 最新版本号
  final String latestBuildNumber;  // 最新构建号
  final String minimumVersion;     // 最低支持版本（低于此版本强制更新）
  final String releaseNotes;       // 更新日志
  final String? macosDownloadUrl;  // macOS 下载链接
  final String? windowsDownloadUrl;// Windows 下载链接
  final String? androidDownloadUrl;// Android 下载链接
  final String? iosDownloadUrl;    // iOS App Store 链接
  final bool updateEnabled;        // 服务端开关
}
```

### UpdateType 枚举

| 类型 | 说明 |
|------|------|
| `none` | 无需更新 |
| `optional` | 可选更新（用户可跳过） |
| `force` | 强制更新（必须更新才能使用） |

---

## 版本比较逻辑

```
当前版本 < 最低版本 → 强制更新 (force)
当前版本 < 最新版本 → 可选更新 (optional)
当前版本 >= 最新版本 → 无需更新 (none)
```

支持语义化版本号格式：`major.minor.patch`（如 `1.2.3`）

---

## 服务端 JSON 格式

```json
{
  "latest_version": "1.2.0",
  "latest_build_number": "10",
  "minimum_version": "1.0.0",
  "release_notes": "- 新增功能A\n- 修复问题B",
  "download_urls": {
    "macos": "https://example.com/AmberList-1.2.0.dmg",
    "windows": "https://example.com/AmberList-1.2.0-Setup.exe",
    "android": "https://example.com/AmberList-1.2.0.apk",
    "ios": "https://apps.apple.com/app/amber-list/id123456789"
  },
  "release_date": "2025-01-15T00:00:00Z",
  "update_enabled": true
}
```

### 字段说明

| 字段 | 必填 | 说明 |
|------|------|------|
| `latest_version` | 是 | 最新版本号 |
| `latest_build_number` | 是 | 最新构建号 |
| `minimum_version` | 是 | 低于此版本必须强制更新 |
| `release_notes` | 否 | 更新日志，支持换行符 |
| `download_urls` | 否 | 各平台下载链接对象 |
| `update_enabled` | 否 | 设为 false 可禁用更新检查 |

---

## 状态管理

### AppUpdateState

```dart
class AppUpdateState {
  final bool isChecking;                  // 是否正在检查
  final UpdateCheckResult? lastCheckResult; // 最近检查结果
  final bool showForceUpdateDialog;       // 是否显示强制更新
  final bool skippedCurrentVersion;       // 是否已跳过当前版本
}
```

### Provider 方法

| 方法 | 说明 |
|------|------|
| `checkForUpdates()` | 检查更新 |
| `skipCurrentVersion()` | 跳过当前版本（仅可选更新） |
| `openDownloadUrl()` | 打开下载链接 |

---

## UI 组件

### 1. 检查更新按钮（AboutTab）

位于设置页 → 关于标签，显示：
- 检查状态（加载中/成功/失败）
- 版本信息（当前版本/最新版本）
- "有更新"标签

### 2. 更新对话框（AppUpdateDialog）

- **可选更新**: 显示"稍后再说"和"立即更新"按钮
- **强制更新**: 仅显示"立即更新"按钮，无法关闭

### 3. 强制更新页面（ForceUpdateScreen）

全屏拦截页面，阻止用户继续使用旧版本。

---

## 启动时检查流程

```
应用启动
    ↓
addPostFrameCallback (延迟执行)
    ↓
checkForUpdates()
    ↓
    ├── 成功 + 强制更新 → 显示 ForceUpdateScreen
    ├── 成功 + 可选更新 → 静默（用户可手动检查）
    └── 失败 → 静默（不阻塞应用）
```

---

## 配置说明

### 修改 API 地址

编辑 `lib/data/services/update/app_update_service.dart`：

```dart
static const String _updateCheckUrl =
    'https://your-server.com/api/app-update.json';
```

### 部署建议

1. **GitHub Raw**: 放在 GitHub 仓库的 `update.json` 文件
2. **CDN**: 放在 OSS/CDN 上以提高访问速度
3. **自建 API**: 动态生成 JSON，支持灰度发布

---

## 依赖

| 依赖包 | 用途 |
|--------|------|
| `http` | HTTP 请求 |
| `package_info_plus` | 获取当前应用版本 |
| `url_launcher` | 打开下载链接 |

---

## 测试场景

| 场景 | 预期行为 |
|------|---------|
| 当前版本 = 最新版本 | 提示"已是最新版本" |
| 当前版本 < 最新版本 | 显示可选更新弹窗 |
| 当前版本 < 最低版本 | 显示强制更新页面 |
| 网络错误 | 静默失败，不阻塞应用 |
| `update_enabled: false` | 跳过更新检查 |

---

## 更新日志

### 2025-01-03
- 初始实现全平台更新检查功能
- 支持强制更新和可选更新
- 集成到设置页面和应用启动流程
