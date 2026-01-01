# Envied 编译时环境配置

本文档记录琥珀清单项目使用 `envied` 实现编译时环境变量配置的方案。

---

## 一、方案概述

### 为什么选择 envied？

| 方案 | 安全性 | 类型检查 | 性能 |
|-----|--------|---------|------|
| flutter_dotenv（运行时） | 低（.env 文件可被提取） | 无 | 需要读取文件 |
| **envied（编译时）** | **高（值直接编译进代码，可混淆）** | **有** | **无额外开销** |

`envied` 配合 `build_runner` 会把 `.env` 里的值在**编译时**直接写入 Dart 代码，更安全且有类型检查。

---

## 二、项目配置

### 2.1 依赖

```yaml
# pubspec.yaml
dependencies:
  envied: ^1.3.2

dev_dependencies:
  envied_generator: ^1.1.1
  build_runner: ^2.4.14  # 项目已有
```

### 2.2 文件结构

```
amber-list/
├── .env              # 实际配置文件（不提交到 Git）
├── .env.example      # 配置模板（提交到 Git，供协作者参考）
└── lib/
    └── env/
        ├── env.dart      # 配置类定义
        └── env.g.dart    # 自动生成的代码
```

### 2.3 .gitignore 配置

```gitignore
# 环境配置文件（包含敏感信息，不应提交）
.env
# .env.example 应该提交，作为配置模板
```

---

## 三、当前配置项

### 3.1 SECRET_STORAGE_TYPE

控制密钥存储方式：

| 值 | 说明 | 安全性 |
|---|------|-------|
| `keychain` | 系统钥匙串存储（flutter_secure_storage） | 高 |
| `shared_preferences` | SharedPreferences 存储 | 低 |

#### 各平台存储实现对比

| 平台 | flutter_secure_storage (keychain) | SharedPreferences |
|------|-----------------------------------|-------------------|
| macOS | Keychain | NSUserDefaults (plist) |
| Windows | Windows Credential Manager | 注册表 (HKCU) |
| iOS | Keychain | NSUserDefaults |
| Android | EncryptedSharedPreferences (6.0+) / Keystore | SharedPreferences (XML) |
| Linux | libsecret | 配置文件 |

**.env 示例：**
```env
SECRET_STORAGE_TYPE=keychain
```

---

## 四、使用方法

### 4.1 代码中使用

```dart
import 'package:amber_list/env/env.dart';

// 方式1：布尔值快捷方法
if (Env.useKeychain) {
  // 使用 flutter_secure_storage (钥匙串)
} else {
  // 使用 SharedPreferences
}

// 方式2：枚举判断
switch (Env.secretStorageType) {
  case SecretStorageType.keychain:
    // 使用钥匙串存储
    break;
  case SecretStorageType.sharedPreferences:
    // 使用 SharedPreferences 存储
    break;
}
```

### 4.2 修改配置后重新生成

**重要**：每次修改 `.env` 文件后，必须重新运行 build_runner：

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 五、添加新配置项

### 步骤1：更新 .env 和 .env.example

```env
# .env
SECRET_STORAGE_TYPE=keychain
NEW_CONFIG_KEY=some_value
```

### 步骤2：更新 lib/env/env.dart

```dart
@Envied(path: '.env')
abstract class Env {
  // 现有配置...

  // 新增配置
  @EnviedField(varName: 'NEW_CONFIG_KEY')
  static const String newConfigKey = _Env.newConfigKey;

  // 敏感配置（开启混淆）
  @EnviedField(varName: 'API_KEY', obfuscate: true)
  static final String apiKey = _Env.apiKey;
}
```

### 步骤3：重新生成代码

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 六、注意事项

1. **编译时确定**：配置值在编译时就固定了，运行时无法更改
2. **敏感数据混淆**：对于 API Key 等敏感数据，使用 `obfuscate: true` 开启混淆
3. **CI/CD 配置**：在 CI/CD 环境中，需要在构建前创建 `.env` 文件
4. **类型支持**：envied 支持 `String`、`int`、`double`、`bool` 等基本类型

---

## 更新日志

### 2026-01-01
- 初始化 envied 配置
- 添加 `SECRET_STORAGE_TYPE` 配置项（控制密钥存储方式）
- 创建 `lib/env/env.dart` 配置类
- 更新 `.gitignore` 忽略 `.env` 文件
- 集成到 `SyncConfigService`，WebDAV 密码存储方式由编译时配置决定
