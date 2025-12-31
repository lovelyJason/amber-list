# 琥珀清单 - 项目架构

## 技术栈

| 类别 | 技术 | 版本 | 用途 |
|------|------|------|------|
| 框架 | Flutter | 3.38.3 | 跨平台UI |
| 语言 | Dart | 3.10.1 | 开发语言 |
| 状态管理 | Riverpod | 2.6.1 | 响应式状态 |
| 数据库 | Drift (SQLite) | 2.28.2 | 本地持久化 |
| 窗口管理 | window_manager | 0.4.3 | 桌面窗口控制 |

## 目录结构

```
lib/
├── main.dart                    # 应用入口
├── app.dart                     # MaterialApp 配置
│
├── core/                        # 核心层
│   ├── constants/               # 常量定义
│   │   ├── colors.dart          # 琥珀配色系统
│   │   ├── dimensions.dart      # 尺寸常量
│   │   └── constants.dart       # 导出文件
│   ├── theme/                   # 主题配置
│   │   └── amber_theme.dart     # Material 主题
│   ├── utils/                   # 工具类（预留）
│   └── extensions/              # 扩展方法（预留）
│
├── data/                        # 数据层
│   ├── models/                  # 数据模型
│   │   ├── task.dart            # 任务模型
│   │   ├── task_list.dart       # 清单模型
│   │   ├── note.dart            # 笔记模型
│   │   └── models.dart          # 导出文件
│   ├── repositories/            # 仓库（预留）
│   ├── datasources/             # 数据源
│   │   └── local/
│   │       └── database.dart    # Drift 数据库定义
│   └── services/                # 服务
│       └── export_service.dart  # 导入导出服务
│
└── presentation/                # 表现层
    ├── providers/               # Riverpod 状态管理
    │   ├── app_state.dart       # 应用导航状态
    │   ├── task_provider.dart   # 任务状态
    │   └── providers.dart       # 导出文件
    ├── pages/                   # 页面
    │   ├── home_page.dart       # 主页面（布局框架）
    │   ├── calendar/
    │   │   └── calendar_page.dart  # 日历页面
    │   ├── notes/
    │   │   └── notes_page.dart     # 笔记页面
    │   └── settings/
    │       └── settings_page.dart  # 设置页面
    ├── widgets/                 # 通用组件
    │   ├── narrow_sidebar.dart  # 窄侧边栏
    │   ├── list_sidebar.dart    # 清单侧边栏
    │   ├── task_item.dart       # 任务列表项
    │   ├── task_list_view.dart  # 任务列表视图
    │   ├── task_detail_panel.dart # 任务详情面板
    │   └── widgets.dart         # 导出文件
    └── dialogs/                 # 弹窗（预留）
```

## 架构分层

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │   Pages     │  │  Widgets    │  │  Providers  │     │
│  │  (UI页面)   │  │  (UI组件)   │  │  (状态管理) │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
├─────────────────────────────────────────────────────────┤
│                      Data Layer                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │   Models    │  │ Repositories│  │  Services   │     │
│  │  (数据模型) │  │  (数据操作) │  │  (业务服务) │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
├─────────────────────────────────────────────────────────┤
│                    Datasource Layer                      │
│  ┌─────────────────────┐  ┌─────────────────────┐      │
│  │   Local (SQLite)    │  │   Remote (WebDAV)   │      │
│  └─────────────────────┘  └─────────────────────┘      │
└─────────────────────────────────────────────────────────┘
```

## 状态管理设计

### Provider 结构

```dart
// 导航状态
appNavProvider -> AppNavState
  - currentView: NavView (inbox/today/upcoming/calendar/notes/list)
  - selectedListId: String?
  - selectedTaskId: String?
  - isDetailPanelOpen: bool

// 清单列表
taskListProvider -> List<TaskList>

// 任务列表
taskProvider -> List<Task>

// 派生状态
todayTasksProvider -> List<Task>      // 今日任务
upcomingTasksProvider -> List<Task>   // 未来7天任务
inboxTasksProvider -> List<Task>      // 收集箱任务
tasksByListProvider(listId) -> List<Task>  // 按清单筛选

// 笔记列表
notesProvider -> List<Note>
```

### 数据流

```
User Action
    │
    ▼
Widget (onTap, onChange...)
    │
    ▼
ref.read(xxxProvider.notifier).method()
    │
    ▼
StateNotifier.state = newState
    │
    ▼
ref.watch(xxxProvider) rebuilds Widget
```

## 数据库设计

### 表结构

#### task_lists（清单表）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | TEXT PK | UUID |
| name | TEXT | 清单名称 |
| icon | TEXT | 图标名称 |
| color | INTEGER | 颜色值 |
| sort_order | INTEGER | 排序 |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |

#### tasks（任务表）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | TEXT PK | UUID |
| title | TEXT | 任务标题 |
| description | TEXT | 任务描述 |
| list_id | TEXT FK | 所属清单 |
| due_date | DATETIME | 截止日期 |
| priority | INTEGER | 优先级(0-3) |
| is_completed | BOOLEAN | 是否完成 |
| completed_at | DATETIME | 完成时间 |
| tags | TEXT | 标签JSON数组 |
| sort_order | INTEGER | 排序 |
| parent_id | TEXT | 父任务ID |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |

#### notes（笔记表）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | TEXT PK | UUID |
| title | TEXT | 标题 |
| content | TEXT | Markdown内容 |
| folder_id | TEXT | 文件夹ID |
| tags | TEXT | 标签JSON数组 |
| is_pinned | BOOLEAN | 是否置顶 |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |

## 依赖关系

```yaml
dependencies:
  # 核心
  flutter_riverpod: ^2.6.1      # 状态管理
  riverpod_annotation: ^2.6.1   # 代码生成注解

  # 数据库
  drift: ^2.28.2                # SQLite ORM
  sqlite3_flutter_libs: ^0.5.28 # SQLite库
  path_provider: ^2.1.5         # 路径获取
  path: ^1.9.1                  # 路径处理

  # UI组件
  flutter_slidable: ^3.1.2      # 滑动操作
  table_calendar: ^3.2.0        # 日历组件

  # 工具
  uuid: ^4.5.2                  # UUID生成
  file_picker: ^8.3.7           # 文件选择
  intl: ^0.20.2                 # 国际化/日期格式
  collection: ^1.19.1           # 集合工具

  # 桌面
  window_manager: ^0.4.3        # 窗口管理

dev_dependencies:
  build_runner: ^2.5.4          # 代码生成
  riverpod_generator: ^2.6.5    # Riverpod代码生成
  drift_dev: ^2.28.0            # Drift代码生成
```

## 设置页面架构

### 设计理念

设置页面采用**内容-容器分离**的架构，支持多种显示模式（Dialog/独立窗口/页面跳转），便于未来灵活切换。

### 组件结构

```dart
/// 外层容器 - 负责 Scaffold + AppBar
class SettingsPage extends ConsumerWidget {
  final int? windowId;  // null = Dialog模式，有值 = 独立窗口模式

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: isDialog ? _buildMacOSCloseButton(context) : null,
      ),
      body: const SettingsContent(), // 🔧 核心内容组件
    );
  }
}

/// 核心内容 - 完全独立的业务逻辑
class SettingsContent extends ConsumerWidget {
  // 包含所有设置项、数据管理、WebDAV配置等
  // 不依赖外层 Scaffold，可独立复用
}
```

### 使用示例

```dart
// 方式1: Dialog 模式（当前默认）
showDialog(
  context: context,
  builder: (context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(40),
    child: Container(
      width: 1000,
      height: 700,
      decoration: BoxDecoration(
        color: AmberColors.background,
        borderRadius: BorderRadius.circular(AmberDimens.radiusLg),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AmberDimens.radiusLg),
        child: const SettingsPage(windowId: null), // 显示 macOS 风格关闭按钮
      ),
    ),
  ),
);

// 方式2: 独立窗口（desktop_multi_window）
final window = await DesktopMultiWindow.createWindow('');
window
  ..setFrame(const Offset(0, 0) & const Size(1000, 700))
  ..center()
  ..setTitle('琥珀清单 - 设置');
runApp(ProviderScope(
  child: MaterialApp(
    home: SettingsPage(windowId: window.id), // 不显示关闭按钮
  ),
));

// 方式3: 主窗口页面跳转（Navigator）
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const SettingsContent(), // 直接用内容组件，不要 AppBar
  ),
);

// 方式4: 自定义容器（完全自由）
Container(
  decoration: BoxDecoration(/* 自定义样式 */),
  child: const SettingsContent(), // 只要内容，容器自己控制
);
```

### macOS 风格关闭按钮

Dialog 模式下，左上角显示 macOS 原生风格的红色关闭按钮：

- **尺寸**: 12x12 像素
- **颜色**: `#FF5F57`（macOS 官方红色）
- **Hover 效果**: 悬停时显示深色 ✕ 图标
- **交互**: 点击关闭 Dialog

```dart
class _MacOSCloseButton extends StatefulWidget {
  // 实现 hover 状态切换
  // 未 hover: 红色圆点 + 细边框
  // hover: 红色圆点 + 深色 ✕ 图标
}
```

### 切换模式指南

如需切换显示模式，只需修改调用方式：

1. **改用独立窗口**: 将 `showDialog` 替换为 `DesktopMultiWindow.createWindow`
2. **改用页面跳转**: 将 `SettingsPage` 替换为 `SettingsContent`
3. **自定义容器**: 直接使用 `SettingsContent`，外层自行包装

核心业务逻辑（`SettingsContent`）无需任何改动。

---

## 便签窗口架构

### 概念说明

琥珀清单支持两种类型的便签窗口：

#### 1. 清单便签（List Sticky Note）
- **定义**: 显示整个清单的所有任务的便签窗口
- **触发位置**: `lib/presentation/widgets/list_sidebar.dart`
- **标识ID**: 使用 `list.id`（清单ID）
- **数据来源**: `task_lists` 表
- **窗口内容**:
  - 清单名称作为标题
  - 显示该清单下的所有任务（已完成/未完成）
  - 可以勾选任务完成状态
- **注册Key**: `list.id`

#### 2. 单个任务便签（Task Sticky Note）
- **定义**: 只显示单个任务的详细信息的便签窗口
- **触发位置**: `lib/presentation/widgets/task_item.dart`
- **标识ID**: 使用 `task.id`（任务ID）
- **数据来源**: `tasks` 表
- **窗口内容**:
  - 任务标题
  - 任务描述（description字段）
  - 蓝色主题色（区别于清单便签的黄色）
- **注册Key**: `task.id`

### 便签窗口注册机制

使用 `StickyNoteRegistry` 防止重复打开：

```dart
/// 便签窗口注册表
class StickyNoteRegistry extends StateNotifier<Map<String, int>> {
  // Map<contentId, windowId>
  // contentId: list.id 或 task.id
  // windowId: desktop_multi_window 返回的窗口ID

  void register(String contentId, int windowId);
  void unregister(String contentId);
  bool isOpen(String contentId);
  int? getWindowId(String contentId);
}
```

### 防重复打开机制（Liveness Check）

两种便签窗口都实现了**窗口存活检测**,防止关闭后无法再打开:

```dart
// 打开前检查
if (registry.isOpen(contentId)) {
  final windowId = registry.getWindowId(contentId);

  // 🔍 Ping窗口验证是否真的还活着
  try {
    await DesktopMultiWindow.invokeMethod(
      windowId,
      'ping'
    ).timeout(Duration(milliseconds: 500));

    // ✅ 窗口还活着,显示警告
    ToastManager().show(context, '当前已打开便签', type: ToastType.warning);
    return;
  } catch (e) {
    // ❌ 窗口已死,清理注册表
    registry.unregister(contentId);
    // 继续创建新窗口
  }
}
```

### 窗口关闭清理

便签窗口关闭时,通过IPC通知主窗口清理注册表:

```dart
// sticky_note_page.dart 关闭时
await DesktopMultiWindow.invokeMethod(0, 'stickyNoteClosed', contentId);

// home_page.dart 收到通知
if (call.method == 'stickyNoteClosed') {
  final contentId = call.arguments as String;
  ref.read(stickyNoteRegistryProvider.notifier).unregister(contentId);
  return 'ok';
}
```

### 关键文件

| 文件 | 作用 |
|------|------|
| `lib/presentation/pages/sticky_note/sticky_note_registry.dart` | 注册表Provider定义 |
| `lib/presentation/pages/sticky_note/sticky_note_page.dart` | 便签窗口UI页面,处理ping/关闭通知 |
| `lib/presentation/widgets/list_sidebar.dart` | 清单便签触发点,包含liveness check |
| `lib/presentation/widgets/task_item.dart` | 单个任务便签触发点,包含liveness check |
| `lib/presentation/pages/home_page.dart` | 主窗口,处理stickyNoteClosed消息 |

### 术语对照表

| 术语 | 英文 | 说明 |
|------|------|------|
| 清单便签 | List Sticky Note | 显示整个清单所有任务的窗口 |
| 单个任务便签 | Task Sticky Note | 显示单个任务的窗口 |
| 便签窗口 | Sticky Note Window | 清单便签和单个任务便签的统称 |
| 注册表 | Registry | 记录已打开便签窗口的Map |
| 存活检测 | Liveness Check | Ping窗口验证是否还存在 |

---

## 构建命令

```bash
# 安装依赖
flutter pub get

# 代码生成
dart run build_runner build --delete-conflicting-outputs

# 开发运行
flutter run -d macos
flutter run -d windows

# 构建发布
flutter build macos --release
flutter build windows --release

# 代码分析
flutter analyze
```
