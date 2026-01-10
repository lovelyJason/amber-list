# iOS 桌面小组件架构文档

## 概述

琥珀清单支持 iOS 桌面小组件（Home Screen Widget），使用 WidgetKit + SwiftUI 实现。用户可以在 iPhone 桌面快速查看今日任务，与 Android 版本功能完全对齐。

## 功能特性

### 三种尺寸

| 尺寸 | 系统 | 显示任务数 | 功能 |
|------|------|-----------|------|
| Small | systemSmall (2x2) | 5 | 显示任务列表，支持分页，**支持皮肤切换** |
| Medium | systemMedium (4x2) | 5 | 左侧日期 + 右侧任务列表，支持分页 |
| Large | systemLarge (4x4) | 月历 | 月历视图，任务日期有红圈标记 |

### Small Widget 皮肤系统

Small Widget 支持 5 种预设皮肤，可通过以下方式配置：

1. **Widget 编辑界面**：长按 Widget → 编辑小组件 → 选择皮肤
2. **App 设置**：App 内设置 → 小组件 → 皮肤选择

#### 皮肤配色方案

| 皮肤 | 背景渐变 | 文字色 | 次要文字色 |
|------|---------|--------|-----------|
| 琥珀金 | `#E8D494 → #DDBE6F → #D9B560` | `#5C3D1E` | `#8B6914` |
| 纯净白（默认） | `#FAFAFA → #F5F5F5 → #EEEEEE` | `#212121` | `#757575` |
| 深空灰 | `#424242 → #303030 → #212121` | `#E0E0E0` | `#9E9E9E` |
| 薄荷绿 | `#B2DFDB → #80CBC4 → #4DB6AC` | `#1B3B38` | `#2E5752` |
| 樱花粉 | `#F8BBD9 → #F48FB1 → #F06292` | `#4A0D2B` | `#6D1B42` |

### 交互设计

- **点击任务项**：通过 Deep Link 打开 App 切换任务完成状态
- **点击翻页按钮**：切换到下一页任务（iOS 17+ AppIntent 实现）
- **点击日期格子**：打开 App 日历页面并跳转到指定日期
- **月历导航**：上/下月切换，今日按钮返回当前月（iOS 17+ AppIntent）
- **自动刷新**：30 分钟定时刷新 + App 数据变化时推送刷新

## 技术架构

### 系统要求

- **最低 iOS 版本**: iOS 17.0+
- **框架**: WidgetKit + SwiftUI
- **交互**: AppIntent（iOS 17+ 支持 Widget 内按钮交互）

### 数据流

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter App                            │
│                                                             │
│  ┌─────────────┐    ┌──────────────────┐                   │
│  │ TaskProvider│───▶│ HomeWidgetService│                   │
│  └─────────────┘    └────────┬─────────┘                   │
│                              │                              │
│                              ▼                              │
│                    ┌─────────────────┐                     │
│                    │  home_widget    │                     │
│                    │  (Flutter插件)   │                     │
│                    └────────┬────────┘                     │
└─────────────────────────────┼───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              App Group UserDefaults                         │
│              (group.com.amberlist.amberlist)                │
│                                                             │
│    Key: "widget_tasks"     → JSON Array of tasks           │
│    Key: "widget_small_skin" → "amber" | "white" | ...      │
│    Key: "small_widget_page" → Int (current page)           │
│    Key: "large_widget_month_offset" → Int (month offset)   │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  iOS Widget Extension                       │
│                  (AmberWidget Target)                       │
│                                                             │
│  ┌─────────────────┐   ┌─────────────────┐                 │
│  │WidgetDataStore │   │TimelineProvider │                  │
│  │ (读取数据)       │◀──│ (生成 Timeline)  │                 │
│  └─────────────────┘   └────────┬────────┘                 │
│                                 │                           │
│                                 ▼                           │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                 SwiftUI Widget Views                 │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐          │   │
│  │  │  Small   │  │  Medium  │  │  Large   │          │   │
│  │  │  Widget  │  │  Widget  │  │  Widget  │          │   │
│  │  └──────────┘  └──────────┘  └──────────┘          │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    AppIntents                        │   │
│  │  SmallNextPageIntent | PrevMonthIntent | ...         │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 核心组件

#### 1. Flutter 层

**HomeWidgetService** (`lib/core/services/home_widget_service.dart`)

```dart
class HomeWidgetService {
  // iOS App Group ID（必须与 Xcode 配置一致）
  static const String _iOSAppGroupId = 'group.com.amberlist.amberlist';

  /// 初始化（App 启动时调用）
  Future<void> init() async {
    if (Platform.isIOS) {
      await HomeWidget.setAppGroupId(_iOSAppGroupId);
    }
    HomeWidget.widgetClicked.listen(_handleWidgetClick);
  }

  /// 更新 Widget 数据
  Future<void> updateWidgetData(List<Task> tasks);

  /// 更新皮肤设置
  Future<void> updateSmallWidgetSkin(WidgetSkinType skinType);
}
```

#### 2. iOS 原生层

**WidgetDataStore** (`ios/AmberWidget/Models/WidgetDataStore.swift`)

通过 App Group UserDefaults 与 Flutter 共享数据：

```swift
class WidgetDataStore {
    private static let appGroupID = "group.com.amberlist.amberlist"

    static func loadTasks() -> [WidgetTask]
    static func loadIncompleteTasks() -> [WidgetTask]
    static func loadSmallWidgetSkin() -> WidgetSkinType
    static func loadCurrentPage(for size: WidgetSize) -> Int
    static func loadMonthOffset() -> Int
    static func reloadAllWidgets()
}
```

**WidgetSkinConfig** (`ios/AmberWidget/Models/WidgetSkinConfig.swift`)

皮肤配置与 Android/Flutter 保持一致：

```swift
enum WidgetSkinType: String, Codable, CaseIterable {
    case amber, white, dark, mint, pink
}

struct WidgetSkinConfig {
    let startColor, centerColor, endColor: Color
    let textColor, secondaryTextColor: Color
    let iconColor, checkboxColor: Color

    var backgroundGradient: LinearGradient { ... }
    static func getConfig(for type: WidgetSkinType) -> WidgetSkinConfig
}
```

**ChineseCalendar** (`ios/AmberWidget/Models/ChineseCalendar.swift`)

农历和节假日计算（从 Android 移植）：

```swift
class ChineseCalendar {
    static func getLunarDate(from date: Date) -> LunarDateInfo
}

class ChineseHolidays {
    static func getHolidayInfo(year: Int, month: Int, day: Int) -> HolidayInfo?
}
```

**AppIntent** (`ios/AmberWidget/AppIntent.swift`)

iOS 17+ Widget 内交互支持：

```swift
// 皮肤配置 Intent（Widget 编辑界面）
struct SmallWidgetConfigurationIntent: WidgetConfigurationIntent {
    @Parameter(title: "皮肤主题", default: .white)
    var skinType: WidgetSkinAppEnum
}

// 翻页 Intent
struct SmallNextPageIntent: AppIntent { ... }
struct MediumNextPageIntent: AppIntent { ... }

// 月历导航 Intent
struct PrevMonthIntent: AppIntent { ... }
struct NextMonthIntent: AppIntent { ... }
struct TodayIntent: AppIntent { ... }
```

## 文件结构

```
ios/AmberWidget/
├── AmberWidgetBundle.swift       # Widget Extension 入口
├── AppIntent.swift               # 配置和交互 Intent
├── Models/
│   ├── WidgetTask.swift          # 任务数据模型 + Color Extension
│   ├── WidgetSkinConfig.swift    # 皮肤配置（5种皮肤）
│   ├── WidgetDataStore.swift     # App Group 数据读取
│   └── ChineseCalendar.swift     # 农历/节假日计算
└── Views/
    ├── Components/
    │   └── TaskRowView.swift     # 任务行组件 + 空状态组件
    ├── SmallWidgetView.swift     # Small Widget (2x2)
    ├── MediumWidgetView.swift    # Medium Widget (4x2)
    └── LargeWidgetView.swift     # Large Widget (4x4 月历)

ios/Runner/
├── Info.plist                    # URL Scheme 配置 (amberlist://)
└── Runner.entitlements           # App Group 配置
```

## 配置说明

### 1. App Group 配置

Runner 和 AmberWidget 两个 Target 都需要添加相同的 App Group：

```
group.com.amberlist.amberlist
```

### 2. URL Scheme 配置

在 `ios/Runner/Info.plist` 中配置：

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.amberlist.amberlist</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>amberlist</string>
        </array>
    </dict>
</array>
```

### 3. Deep Link 格式

| 操作 | URL 格式 |
|------|---------|
| 切换任务完成状态 | `amberlist://widget/toggle_task?id=<task_id>` |
| 打开日历指定日期 | `amberlist://widget/calendar?date=<YYYY-MM-DD>` |

## UI 设计

### 配色

与 Android Widget 保持一致：

- **主色（琥珀金）**: `#F5A623`
- **背景色**: `#FFFBF5`（米白色）
- **文字色**: `#424242`
- **优先级颜色**:
  - 高: `#E53935`（红）
  - 中: `#FB8C00`（橙）
  - 低: `#43A047`（绿）

### Large Widget 月历特性

- **今日标记**: 琥珀色实心圆
- **任务日期标记**: 红色描边圆圈
- **节假日标记**: 显示节日名称（休/班）
- **农历日期**: 显示在日期下方
- **月份导航**: 左右箭头切换月份，今日按钮返回当前月

## 与 Android 实现的差异

| 特性 | Android | iOS |
|------|---------|-----|
| 皮肤配置方式 | 仅 App 设置 | App 设置 + Widget Intent |
| Widget 内交互 | PendingIntent + Broadcast | AppIntent (iOS 17+) |
| 数据共享 | SharedPreferences | App Group UserDefaults |
| 布局系统 | RemoteViews (XML) | SwiftUI |
| 农历计算 | ChineseCalendar (Kotlin) | ChineseCalendar (Swift) |

## 后续优化

- [ ] Deep Link 处理实现（点击任务切换完成状态）
- [ ] Widget 预览图
- [ ] Medium/Large Widget 皮肤支持
- [ ] 性能优化（减少 Timeline 刷新频率）
- [ ] 更多皮肤选项
