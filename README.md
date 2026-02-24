# 琥珀清单 (Amber List)

一款简约而不失质感的桌面端待办应用，封存万物，历久弥新。

使用本软件，数据掌握在自己手里，可以根据需要本地存储您的数据，也可以导出数据，导入数据， 以及，使用您自己的云端存储空间，包括但不限于WebDAV, 各大厂商的OSS等，将数据捞牢牢掌握自己手里，不用每个月给清单软件付上高额的订阅费用，革了他们的命。

## 下载地址

https://www.qdovo.com/amber/

<img width="540" height="360" alt="image" src="https://github.com/user-attachments/assets/f6b841f1-d8d7-4f50-bae1-6717e444b7b7" />

日历视图

<img width="540" height="360" alt="image" src="https://github.com/user-attachments/assets/56e96ee3-f3da-4d89-8a54-47412ce5ca42" />

## 特性

- **琥珀主题**：温暖的琥珀色调，简约优雅的视觉设计
- **待办清单**：任务管理、优先级设置、截止日期、标签分类
- **日历视图**：月/周视图切换，直观查看任务分布
- **笔记功能**：Markdown支持，卡片/列表视图
- **数据自主**：SQLite本地存储，支持导入/导出
- **跨平台**：支持 macOS 和 Windows

## 快速开始

### 环境要求

- Flutter 3.38+
- Dart 3.10+
- macOS 10.14+ / Windows 10+

### 安装运行

```bash
# 克隆项目
git clone https://github.com/yourusername/amber-list.git
cd amber-list

# 安装依赖
flutter pub get

# 生成代码
dart run build_runner build --delete-conflicting-outputs

# 运行（macOS）
flutter run -d macos

# 运行（Windows）
flutter run -d windows
```

### 构建发布版

```bash
# macOS
flutter build macos --release

# Windows
flutter build windows --release
```

## 项目结构

```
lib/
├── core/           # 核心层（主题、常量）
├── data/           # 数据层（模型、数据库）
└── presentation/   # 表现层（页面、组件、状态）

docs/
├── design/         # 设计文档
│   ├── UI_DESIGN_SPEC.md      # UI设计规范
│   └── KEYBOARD_SHORTCUTS.md  # 快捷键规划
├── development/    # 开发文档
│   ├── ARCHITECTURE.md        # 项目架构
│   └── ROADMAP.md            # 开发路线图
└── api/            # API文档
    └── DATA_MODELS.md         # 数据模型
```

## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter |
| 状态管理 | Riverpod |
| 数据库 | Drift (SQLite) |
| 窗口管理 | window_manager |

## 路线图

- [x] v1.0.0 MVP - 核心功能
- [x] v1.1.0 - 数据持久化完善
- [x] v1.2.0 - 快捷键支持
- [x] v1.3.0 - WebDAV 云同步
- [x] v1.4.0 - 任务提醒
- [x] v2.0.0 - 移动端支持

详见 [ROADMAP.md](docs/development/ROADMAP.md)

## 文档

- [UI设计规范](docs/design/UI_DESIGN_SPEC.md)
- [项目架构](docs/development/ARCHITECTURE.md)
- [快捷键规划](docs/design/KEYBOARD_SHORTCUTS.md)
- [数据模型](docs/api/DATA_MODELS.md)
- [开发路线图](docs/development/ROADMAP.md)

## 开发

```bash
# 代码分析
flutter analyze

# 运行测试
flutter test

# 代码生成（修改数据库或Provider后）
dart run build_runner build --delete-conflicting-outputs
```

## 使用

### MacOS

由于使用了钥匙串的功能， 没有付费签名，需要开启隐私安全里面的【允许以下来源的应用程序： 任何来源】，如果没有这个选项，需要

```bash
sudo spctl --master-disable
```

## 许可证

MIT License
