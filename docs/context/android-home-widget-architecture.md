# Android 桌面小组件架构文档

## 概述

琥珀清单支持 Android 桌面小组件（Home Screen Widget），用户可以在手机桌面快速查看今日任务并直接切换完成状态，无需打开 App。

## 功能特性

### 三种尺寸

| 尺寸 | 网格 | 显示任务数 | 功能 |
|------|------|-----------|------|
| Small | 2x2 | 5 | 显示任务列表，支持分页，**支持皮肤切换** |
| Medium | 4x2 | 5 | 显示日期 + 任务列表，支持分页 |
| Large | 4x4 | 月历 | 显示月历视图，任务日期有手绘圆圈标记 |

### 任务筛选规则

Widget 显示的任务包括：
1. **今日任务**：`dueDate` 为今天的未完成任务
2. **已过期任务**：`dueDate` 早于今天 且 `autoPostpone=true` 的未完成任务

排除条件：
- `isDeleted=true`（已删除）
- `isCompleted=true`（已完成）
- `dueDate=null`（无截止日期）

### 交互设计

- **点击任务项**：切换任务完成状态（通过 Deep Link 打开 App 执行）
- **点击 Header/Logo**：打开 App 主界面
- **点击翻页按钮**：切换到下一页任务（Small/Medium Widget）
- **点击日期格子**：打开 App 日历页面（Large Widget）
- **自动刷新**：
  - 系统定时刷新（30 分钟）
  - App 任务数据变化时立即推送刷新

### Small Widget 皮肤系统

Small Widget 支持 5 种预设皮肤，用户可在 App 设置中切换。

#### 皮肤配色方案

| 皮肤 | 背景渐变 | 文字色 | 次要文字色 |
|------|---------|--------|-----------|
| 琥珀金（默认） | `#E8D494 → #DDBE6F → #D9B560` | `#5C3D1E` | `#8B6914` |
| 纯净白 | `#FAFAFA → #F5F5F5 → #EEEEEE` | `#212121` | `#757575` |
| 深空灰 | `#424242 → #303030 → #212121` | `#E0E0E0` | `#9E9E9E` |
| 薄荷绿 | `#B2DFDB → #80CBC4 → #4DB6AC` | `#004D40` | `#00695C` |
| 樱花粉 | `#F8BBD9 → #F48FB1 → #F06292` | `#880E4F` | `#AD1457` |

#### 使用方式

1. 打开 App → **设置** → **小组件**
2. 在皮肤选择器中选择喜欢的皮肤
3. 桌面 Small Widget 会自动更新背景和文字颜色

#### 扩展新皮肤

如需添加新皮肤：

1. 在 `lib/core/models/widget_skins.dart` 中添加枚举值和配置
2. 在 `android/app/src/main/res/drawable/` 下创建对应的 `widget_small_bg_xxx.xml`
3. 在 `AmberWidgetProvider.kt` 的 `loadSmallWidgetSkin()` 方法中添加 case

## 技术架构

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
│                   SharedPreferences                         │
│                                                             │
│    Key: "widget_tasks"                                      │
│    Value: JSON Array of tasks                               │
│                                                             │
│    [{"id":"xxx","title":"买菜","isCompleted":false,...}]    │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  Android Widget System                      │
│                                                             │
│  ┌───────────────────┐                                     │
│  │AmberWidgetProvider│◀── AppWidgetManager.updateAppWidget │
│  └─────────┬─────────┘                                     │
│            │                                                │
│            ▼                                                │
│  ┌─────────────────┐     ┌─────────────────┐               │
│  │   RemoteViews   │────▶│   Home Screen   │               │
│  └─────────────────┘     └─────────────────┘               │
└─────────────────────────────────────────────────────────────┘
```

### 核心组件

#### 1. Flutter 层

**HomeWidgetService** (`lib/core/services/home_widget_service.dart`)

```dart
class HomeWidgetService {
  // Android Widget Provider 名称（必须与 AndroidManifest 中一致）
  static const String _androidWidgetName = 'AmberWidgetProvider';

  // SharedPreferences Keys
  static const String _keyWidgetTasks = 'widget_tasks';
  static const String _keySmallWidgetSkin = 'widget_small_skin';

  /// 初始化（App 启动时调用）
  Future<void> init();

  /// 更新 Widget 数据（任务变化时调用）
  Future<void> updateWidgetData(List<Task> tasks);

  /// 更新 Small Widget 皮肤设置
  Future<void> updateSmallWidgetSkin(WidgetSkinType skinType);

  /// 筛选 Widget 显示的任务（±3个月范围，最多100条）
  List<Task> _filterWidgetTasks(List<Task> tasks);

  /// 序列化任务为 JSON
  String _serializeTasks(List<Task> tasks);
}
```

**WidgetSettingsProvider** (`lib/presentation/providers/widget_settings_provider.dart`)

```dart
/// 小组件设置状态
class WidgetSettings {
  final WidgetSkinType smallWidgetSkin; // 默认 amber
}

/// 皮肤切换时自动同步到原生 Widget
class WidgetSettingsNotifier extends StateNotifier<WidgetSettings> {
  void setSmallWidgetSkin(WidgetSkinType skin) {
    state = state.copyWith(smallWidgetSkin: skin);
    HomeWidgetService().updateSmallWidgetSkin(skin); // 同步到 Android
  }
}
```

**WidgetSkins** (`lib/core/models/widget_skins.dart`)

```dart
/// 皮肤类型枚举
enum WidgetSkinType { amber, white, dark, mint, pink }

/// 皮肤配置（Flutter 预览用）
class WidgetSkinConfig {
  final WidgetSkinType type;
  final String displayName;
  final Color startColor, centerColor, endColor;
  final Color textColor, secondaryTextColor;
}
```

**TaskProvider 集成** (`lib/presentation/providers/task_provider.dart`)

```dart
void _init() {
  database.watchAllTasks().listen((dbTasks) {
    // ... 处理任务列表 ...
    state = tasks;

    // 同步到移动端桌面小组件
    _updateHomeWidget(tasks);
  });
}

void _updateHomeWidget(List<Task> tasks) {
  if (!Platform.isAndroid && !Platform.isIOS) return;
  HomeWidgetService().updateWidgetData(tasks);
}
```

#### 2. Android 原生层

**AmberWidgetProvider** (`android/app/src/main/kotlin/.../widget/AmberWidgetProvider.kt`)

核心 AppWidgetProvider 实现：
- `onUpdate()`: 接收系统更新请求，读取 SharedPreferences 并渲染 UI
- `onReceive()`: 处理自定义广播（任务点击、打开 App、翻页、月历导航）
- `loadTasks()`: 从 SharedPreferences 读取并解析 JSON
- `loadSmallWidgetSkin()`: 读取皮肤设置，返回 `SmallWidgetSkinConfig`
- `createSmallWidget()`: 应用皮肤背景和文字颜色
- `createMediumWidget()`: 显示日期 + 任务列表
- `createLargeWidget()`: 显示月历视图，有任务的日期显示手绘红圈

```kotlin
// 皮肤配置数据类
data class SmallWidgetSkinConfig(
    val backgroundRes: Int,      // R.drawable.widget_small_bg_xxx
    val textColor: Int,          // 任务标题颜色
    val secondaryTextColor: Int  // 时间、页码等次要文字颜色
)

// 根据皮肤名称加载配置
private fun loadSmallWidgetSkin(context: Context): SmallWidgetSkinConfig {
    val skinName = prefs.getString("widget_small_skin", "amber")
    return when (skinName) {
        "white" -> SmallWidgetSkinConfig(R.drawable.widget_small_bg_white, ...)
        "dark" -> SmallWidgetSkinConfig(R.drawable.widget_small_bg_dark, ...)
        // ...
    }
}
```

**Widget 布局文件**

| 文件 | 用途 |
|------|------|
| `res/layout/widget_small.xml` | Small Widget 布局 |
| `res/layout/widget_medium.xml` | Medium Widget 布局 |
| `res/layout/widget_large.xml` | Large Widget 布局（月历） |
| `res/drawable/widget_background.xml` | Widget 背景（圆角 + 边框） |
| `res/drawable/widget_header_background.xml` | Header 琥珀渐变背景 |
| `res/drawable/widget_small_background.xml` | Small Widget 琥珀皮肤（默认） |
| `res/drawable/widget_small_bg_white.xml` | Small Widget 纯净白皮肤 |
| `res/drawable/widget_small_bg_dark.xml` | Small Widget 深空灰皮肤 |
| `res/drawable/widget_small_bg_mint.xml` | Small Widget 薄荷绿皮肤 |
| `res/drawable/widget_small_bg_pink.xml` | Small Widget 樱花粉皮肤 |
| `res/drawable/widget_task_circle.xml` | Large Widget 任务日期手绘红圈 |
| `res/drawable/widget_today_circle.xml` | Large Widget 今日日期琥珀圆 |
| `res/drawable/ic_checkbox_checked.xml` | 已完成复选框图标 |
| `res/drawable/ic_checkbox_unchecked.xml` | 未完成复选框图标 |

**Widget 配置文件**

| 文件 | 用途 |
|------|------|
| `res/xml/widget_info_small.xml` | Small Widget 配置（2x2） |
| `res/xml/widget_info_medium.xml` | Medium Widget 配置（4x2） |
| `res/xml/widget_info_large.xml` | Large Widget 配置（4x4） |

## 文件结构

```
lib/
├── core/
│   ├── models/
│   │   └── widget_skins.dart           # 皮肤枚举和配置定义
│   └── services/
│       └── home_widget_service.dart    # Flutter Widget 服务
├── main.dart                           # 初始化 HomeWidgetService
└── presentation/
    ├── pages/
    │   └── settings/
    │       └── tabs/
    │           └── widget_tab.dart     # 小组件设置界面（皮肤选择器）
    └── providers/
        ├── task_provider.dart          # 集成 Widget 更新
        └── widget_settings_provider.dart # 小组件设置状态管理

android/app/src/main/
├── kotlin/com/example/amber_list/
│   └── widget/
│       ├── AmberWidgetProvider.kt      # 主 Widget Provider（含皮肤加载）
│       ├── AmberWidgetMediumProvider.kt # Medium 尺寸 Provider
│       ├── AmberWidgetLargeProvider.kt  # Large 尺寸 Provider（月历）
│       ├── ChineseHolidays.kt          # 中国节假日数据
│       └── WidgetTaskService.kt        # 任务数据服务
├── res/
│   ├── layout/
│   │   ├── widget_small.xml
│   │   ├── widget_medium.xml
│   │   └── widget_large.xml
│   ├── drawable/
│   │   ├── widget_background.xml
│   │   ├── widget_header_background.xml
│   │   ├── widget_small_background.xml # 琥珀皮肤（默认）
│   │   ├── widget_small_bg_white.xml   # 纯净白皮肤
│   │   ├── widget_small_bg_dark.xml    # 深空灰皮肤
│   │   ├── widget_small_bg_mint.xml    # 薄荷绿皮肤
│   │   ├── widget_small_bg_pink.xml    # 樱花粉皮肤
│   │   ├── widget_task_circle.xml      # 任务日期手绘红圈
│   │   ├── widget_today_circle.xml     # 今日琥珀圆
│   │   ├── ic_checkbox_checked.xml
│   │   └── ic_checkbox_unchecked.xml
│   ├── xml/
│   │   ├── widget_info_small.xml
│   │   ├── widget_info_medium.xml
│   │   └── widget_info_large.xml
│   └── values/
│       └── strings.xml                 # Widget 名称和描述
└── AndroidManifest.xml                 # Widget Receiver 注册
```

## 配置说明

### AndroidManifest.xml 注册

```xml
<!-- Small Widget -->
<receiver
    android:name=".widget.AmberWidgetProvider"
    android:exported="true"
    android:label="@string/widget_name_small">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
        <action android:name="com.example.amber_list.TOGGLE_TASK" />
        <action android:name="com.example.amber_list.OPEN_APP" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/widget_info_small" />
</receiver>

<!-- Medium Widget -->
<receiver android:name=".widget.AmberWidgetMediumProvider" ... />

<!-- Large Widget -->
<receiver android:name=".widget.AmberWidgetLargeProvider" ... />
```

### pubspec.yaml 依赖

```yaml
dependencies:
  home_widget: ^0.7.0
```

## UI 设计

### 配色

- **主色（琥珀金）**: `#F5A623`
- **主色深**: `#D4891C`
- **背景色**: `#FFFBF5`（米白色）
- **文字色**: `#333333`
- **优先级颜色**:
  - 高: `#E53935`（红）
  - 中: `#FB8C00`（橙）
  - 低: `#43A047`（绿）

### 圆角

- Widget 外框: 16dp
- Header 顶部圆角: 16dp

## 注意事项

### 1. Android API 兼容性

Widget 配置文件中使用了 Android 12+ 的新属性：
- `targetCellWidth` / `targetCellHeight`: Android 12+ 支持
- 旧设备会 fallback 到 `minWidth` / `minHeight`

### 2. RemoteViews 限制

Android Widget 使用 RemoteViews，有以下限制：
- 不支持自定义 View
- 只支持有限的布局和控件（LinearLayout, RelativeLayout, TextView, ImageView 等）
- 不支持 RecyclerView（需要使用 ListView + RemoteViewsService）

当前实现使用静态布局（最多 6 个任务项），避免了 ListView 的复杂性。

### 3. 数据同步时机

Widget 数据在以下时机更新：
1. App 启动时初始化
2. 任务数据变化时（通过 TaskProvider 的 stream 监听）
3. 系统定时刷新（updatePeriodMillis = 30分钟）

### 4. Deep Link 处理

任务点击使用 Deep Link 方式：
```
amberlist://widget/toggle_task?id=<task_id>
```

需要在 App 中处理此 URI 来执行任务切换（待实现）。

## 后续优化

- [ ] iOS Widget 支持（使用 WidgetKit）
- [ ] 处理 Deep Link 实现点击切换任务
- [ ] 添加 Widget 预览图（previewImage）
- [x] ~~支持深色模式~~ → 已通过皮肤系统实现（深空灰皮肤）
- [x] ~~添加 Widget 配置界面~~ → 已实现皮肤设置界面
- [ ] Medium/Large Widget 皮肤支持
- [ ] 更多皮肤选项（用户自定义颜色）
