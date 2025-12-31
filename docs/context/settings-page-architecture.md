# 设置页面架构文档

## 📋 概述

设置页面采用**标签页导航模式**，左侧为图标+文字的垂直导航栏，右侧为对应标签的内容区域。

**重构时间**: 2025-12-30
**架构模式**: 配置驱动 + 组件复用 + 状态隔离

---

## 🏗️ 文件结构

```
lib/presentation/pages/settings/
├── settings_page.dart              # 主容器（Scaffold + AppBar）
├── settings_tab_type.dart          # 标签类型枚举
├── settings_tab_config.dart        # 标签配置注册表
├── widgets/                        # 可复用组件
│   ├── settings_section.dart       # 区域容器（灰色标题 + 白色卡片）
│   ├── settings_tile.dart          # 设置项（icon + title + subtitle + 箭头）
│   ├── settings_nav_item.dart      # 导航项（hover + 选中状态 + 左侧指示器）
│   └── settings_tab_navigator.dart # 左侧导航栏容器（180px宽）
└── tabs/                           # 标签页 Widget
    ├── data_management_tab.dart    # 数据管理（导出导入 SQLite + JSON）
    ├── cloud_sync_tab.dart         # 云同步（嵌入 WebDavConfigSection）
    └── about_tab.dart              # 关于（版本 + GitHub + 反馈 + 更新日志）
```

---

## 🎯 核心设计原则

### 1. 配置驱动

所有标签通过 `SettingsTabConfig.getAllTabs()` 统一管理，避免硬编码。

### 2. 组件复用

`SettingsSection` 和 `SettingsTile` 可在任何标签页中使用，保持UI一致性。

### 3. 类型安全

使用枚举 `SettingsTabType` 代替字符串，编译期检查错误。

### 4. 状态隔离

标签索引使用本地 `StatefulWidget` 管理，不污染全局 Provider。

### 5. 逻辑不变

WebDAV配置、导出导入等功能完全复用原有逻辑，只改UI布局。

---

## 📐 UI 布局

```
┌─────────────────────────────────────┐
│  [×] 设置                            │ ← AppBar (56px高)
├─────────┬───────────────────────────┤
│         │                           │
│ 📦 数据管理 │  [灰色小标题] SQLite 数据库 │
│ (选中)  │                           │
│ ☁️  云同步  │  [白色卡片区域]           │
│         │  📥 导出数据库  →          │
│ ℹ️  关于   │  📤 导入数据库  →          │
│         │  ─────────               │
│ 180px   │  💾 导出JSON   →          │
│         │  📂 导入JSON   →          │
│         │                           │
│         │  Expanded (右侧内容区)     │
└─────────┴───────────────────────────┘
```

### 尺寸规范

- **左侧导航**: 180px 固定宽度
- **分割线**: 1px 厚度
- **右侧内容**: `Expanded` 自适应
- **导航项间距**: 垂直 2px，水平 8px
- **内容区padding**: 24px (`AmberDimens.spacingLg`)

### 颜色规范

- **选中背景**: `AmberColors.primary.withOpacity(0.1)` (#F5A623 + 10%透明度)
- **选中指示器**: `AmberColors.primary` (#F5A623)，左侧3px宽
- **Hover背景**: `AmberColors.cardBackground` (#FFFFFF)
- **导航栏背景**: `AmberColors.sidebarBackground` (#F5F5F5)

---

## 🔧 如何添加新标签页

### 完整步骤（3步，5分钟完成）

#### 步骤1: 在枚举中添加新类型

**文件**: `lib/presentation/pages/settings/settings_tab_type.dart`

```dart
enum SettingsTabType {
  dataManagement,
  cloudSync,
  about,

  // 🆕 新增标签
  theme; // 主题设置

  String get displayName {
    switch (this) {
      case SettingsTabType.dataManagement:
        return '数据管理';
      case SettingsTabType.cloudSync:
        return '云同步';
      case SettingsTabType.about:
        return '关于';

      // 🆕 添加显示名称
      case SettingsTabType.theme:
        return '主题';
    }
  }

  IconData get icon {
    switch (this) {
      case SettingsTabType.dataManagement:
        return Icons.storage_outlined;
      case SettingsTabType.cloudSync:
        return Icons.cloud_outlined;
      case SettingsTabType.about:
        return Icons.info_outline;

      // 🆕 添加图标
      case SettingsTabType.theme:
        return Icons.palette_outlined;
    }
  }
}
```

---

#### 步骤2: 创建标签页 Widget

**文件**: `lib/presentation/pages/settings/tabs/theme_tab.dart`

```dart
import 'package:flutter/material.dart';
import '../../../../core/constants/constants.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';

/// 主题设置标签页
class ThemeTab extends StatelessWidget {
  const ThemeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AmberDimens.spacingLg),
      children: [
        SettingsSection(
          title: '外观',
          children: [
            SettingsTile(
              icon: Icons.dark_mode_outlined,
              title: '深色模式',
              subtitle: '切换应用主题',
              onTap: () {
                // TODO: 实现主题切换逻辑
              },
            ),
            SettingsTile(
              icon: Icons.color_lens_outlined,
              title: '主题色',
              subtitle: '自定义应用配色方案',
              onTap: () {
                // TODO: 打开颜色选择器
              },
            ),
          ],
        ),
      ],
    );
  }
}
```

---

#### 步骤3: 在配置中注册

**文件**: `lib/presentation/pages/settings/settings_tab_config.dart`

```dart
import 'package:flutter/material.dart';
import 'settings_tab_type.dart';
import 'tabs/data_management_tab.dart';
import 'tabs/cloud_sync_tab.dart';
import 'tabs/about_tab.dart';
import 'tabs/theme_tab.dart'; // 🆕 导入新标签页

class SettingsTabConfig {
  final SettingsTabType type;
  final WidgetBuilder builder;

  const SettingsTabConfig({
    required this.type,
    required this.builder,
  });

  static List<SettingsTabConfig> getAllTabs() {
    return [
      SettingsTabConfig(
        type: SettingsTabType.dataManagement,
        builder: (context) => const DataManagementTab(),
      ),
      SettingsTabConfig(
        type: SettingsTabType.cloudSync,
        builder: (context) => const CloudSyncTab(),
      ),
      SettingsTabConfig(
        type: SettingsTabType.about,
        builder: (context) => const AboutTab(),
      ),

      // 🆕 注册新标签
      SettingsTabConfig(
        type: SettingsTabType.theme,
        builder: (context) => const ThemeTab(),
      ),
    ];
  }
}
```

---

### ✅ 完成

**无需修改其他任何文件**！导航栏和内容区会自动更新。

---

## 🧩 可复用组件使用指南

### 1. SettingsSection - 区域容器

用于将多个设置项分组，提供统一的标题样式和卡片背景。

**使用示例**:

```dart
SettingsSection(
  title: '通知设置',
  children: [
    SettingsTile(...),
    SettingsTile(...),
  ],
)
```

**效果**:
- 灰色小标题（12px，`AmberColors.textDisabled`）
- 白色卡片容器（8px圆角，1px灰色边框）

---

### 2. SettingsTile - 设置项

标准的设置选项ListTile，提供统一的样式。

**使用示例**:

```dart
SettingsTile(
  icon: Icons.notifications_outlined,
  title: '推送通知',
  subtitle: '接收重要消息提醒',
  onTap: () {
    // 处理点击
  },
)
```

**参数说明**:
- `icon`: 左侧图标（自动使用 `AmberColors.primary` 颜色）
- `title`: 主标题
- `subtitle`: 副标题（12px，`AmberColors.textSecondary`）
- `trailing`: 自定义右侧组件（可选，默认显示箭头）
- `onTap`: 点击回调（可选，为null时不显示箭头）

---

## 🎨 设计规范

### 间距规范

```dart
AmberDimens.spacingSm = 8.0   // 小间距
AmberDimens.spacingMd = 16.0  // 中等间距
AmberDimens.spacingLg = 24.0  // 大间距
AmberDimens.spacingXl = 32.0  // 超大间距
```

### 圆角规范

```dart
AmberDimens.radiusSm = 4.0   // 小圆角（导航项）
AmberDimens.radiusMd = 8.0   // 中圆角（卡片）
AmberDimens.radiusLg = 12.0  // 大圆角（弹窗）
```

### 文字大小

- **页面标题**: 24px，Bold
- **Section标题**: 12px，SemiBold，`textDisabled`
- **设置项标题**: 默认（继承ListTile），`textPrimary`
- **设置项副标题**: 12px，`textSecondary`

---

## 🔄 状态管理

### 标签切换状态

使用本地 `StatefulWidget` 管理，避免全局状态污染。

```dart
class _SettingsContentState extends State<SettingsContent> {
  int _currentTabIndex = 0; // 本地状态

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SettingsTabNavigator(
          currentIndex: _currentTabIndex,
          onTabChanged: (index) {
            setState(() => _currentTabIndex = index); // 本地setState
          },
        ),
        // ...
      ],
    );
  }
}
```

### 标签页内部状态

标签页Widget可自由选择状态管理方式：

- **无状态**: `StatelessWidget`（如 `AboutTab`）
- **本地状态**: `StatefulWidget`（如需要表单输入）
- **Riverpod**: `ConsumerWidget`（如 `DataManagementTab` 需要 `ref`）

---

## 🚀 切换动画

使用 `AnimatedSwitcher` 实现标签页切换的淡入淡出效果。

```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 200),
  switchInCurve: Curves.easeInOut,
  switchOutCurve: Curves.easeInOut,
  child: _buildTabContent(),
)
```

**关键点**:
- 使用 `KeyedSubtree` + `ValueKey(_currentTabIndex)` 避免状态泄漏
- 200ms动画时长，流畅不拖沓
- `easeInOut` 曲线，平滑自然

---

## 🐛 常见问题与解决方案

### 问题1: 标签页内容没有padding

**症状**: 内容紧贴边缘

**原因**: 标签页Widget忘记添加 `ListView` 的 `padding`

**解决**:
```dart
ListView(
  padding: const EdgeInsets.all(AmberDimens.spacingLg), // 必须添加
  children: [ ... ],
)
```

---

### 问题2: SettingsSection的children为空导致空白

**症状**: 显示空白卡片

**原因**: `SettingsSection` 未处理空children的情况

**解决**:
```dart
// 在使用前检查
if (items.isNotEmpty) {
  SettingsSection(
    title: '标题',
    children: items,
  )
}
```

---

### 问题3: Dialog中使用context导致警告

**症状**: "使用已销毁的context"警告

**原因**: `showDialog` 内部使用了外部context

**解决**:
```dart
showDialog(
  context: context,
  builder: (dialogContext) => AlertDialog( // 使用builder提供的context
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext, false), // 使用dialogContext
        child: const Text('取消'),
      ),
    ],
  ),
)
```

---

### 问题4: 异步操作后修改状态导致内存泄漏

**症状**: 快速切换标签时崩溃或警告

**原因**: Widget已销毁但异步操作仍在修改状态

**解决**:
```dart
Future<void> someAsyncOperation() async {
  final result = await someService.doSomething();

  // ✅ 在修改状态前检查mounted
  if (!mounted) return;

  setState(() {
    // 修改状态
  });
}
```

---

## 📝 代码审查检查清单

添加新标签页后，请检查以下事项：

- [ ] 枚举中添加了新类型、displayName、icon
- [ ] 创建了对应的标签页Widget文件
- [ ] 在 `SettingsTabConfig.getAllTabs()` 中注册
- [ ] 标签页Widget使用了 `ListView` + `padding`
- [ ] 使用 `SettingsSection` 保持UI一致性
- [ ] 如有异步操作，检查了 `mounted` 状态
- [ ] 如有Dialog，使用了 `builder` 提供的 `dialogContext`
- [ ] 所有颜色、尺寸使用了 `AmberColors` 和 `AmberDimens` 常量

---

## 🔗 相关文件

- **设计系统**: `lib/core/constants/colors.dart`、`lib/core/constants/dimensions.dart`
- **主题配置**: `lib/core/theme/amber_theme.dart`
- **导出导入服务**: `lib/data/services/export_service.dart`
- **WebDAV配置**: `lib/presentation/widgets/webdav_config_section.dart`

---

## 📖 参考资料

- [Flutter AnimatedSwitcher 文档](https://api.flutter.dev/flutter/widgets/AnimatedSwitcher-class.html)
- [Flutter showDialog 最佳实践](https://api.flutter.dev/flutter/material/showDialog.html)
- [Riverpod 状态管理](https://riverpod.dev/)

---

**最后更新**: 2025-12-30
**维护者**: 开发团队
