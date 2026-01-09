# 每日任务顺延功能架构

## 功能概述

"每日任务顺延"功能用于处理过期任务，提供两种策略：

1. **自动顺延**：App 启动时自动将过期任务的截止日期修改为今天
2. **手动顺延**：在"今天"视图的"已过期"区域显示过期任务，用户手动点击顺延

## 核心设计

### 双重控制机制

| 控制层 | 字段 | 位置 | 作用 |
|--------|------|------|------|
| 全局开关 | `enableAutoPostpone` | TaskManagementSettings | 控制是否启用自动顺延功能 |
| 任务级别 | `autoPostpone` | Task Model | 控制单个任务是否参与自动顺延 |

### 行为矩阵

| 全局开关 | 任务 autoPostpone | 过期任务行为 |
|----------|-------------------|--------------|
| ON | true | App 启动时自动顺延到今天 |
| ON | false | 显示在"已过期"区域，需手动顺延 |
| OFF | true/false | 全部显示在"已过期"区域 |

### 新旧数据兼容

- **新任务**：`autoPostpone` 默认 `true`（自动顺延）
- **旧数据迁移**：数据库迁移时 `auto_postpone` 默认值为 `0`（false），不自动顺延

## 文件变更清单

### 数据层

| 文件 | 变更 |
|------|------|
| `lib/data/datasources/local/database.dart` | Tasks 表添加 `autoPostpone` 列，数据库版本 8 → 9 |
| `lib/data/models/task.dart` | Task 模型添加 `autoPostpone` 字段 |

### Provider 层

| 文件 | 变更 |
|------|------|
| `lib/presentation/providers/task_management_settings_provider.dart` | **新文件** - 任务管理设置，包含 `enableAutoPostpone` 和 `waitForLoad()` |
| `lib/presentation/providers/task_provider.dart` | 添加 `performAutoPostpone()`、`postponeTasks()`、`overdueTasksProvider`、`todayViewTasksProvider` |

### UI 层

| 文件 | 变更 |
|------|------|
| `lib/presentation/widgets/overdue_tasks_section.dart` | **新文件** - 红色高亮过期任务区域 |
| `lib/presentation/widgets/today_view.dart` | **新文件** - 今天视图，整合过期区域 |
| `lib/presentation/pages/home_page.dart` | "今天"导航改用 `TodayView` |
| `lib/presentation/pages/settings/tabs/task_management_tab.dart` | **新文件** - 任务管理设置页 |
| `lib/presentation/pages/settings/settings_tab_type.dart` | 添加 `taskManagement` 枚举值 |
| `lib/presentation/pages/settings/settings_tab_config.dart` | 注册任务管理 Tab |

### 应用层

| 文件 | 变更 |
|------|------|
| `lib/app.dart` | 添加 `_performAutoPostpone()` 方法，启动时调用 |

## 关键代码

### 数据库迁移 (version 9)

```dart
// database.dart
BoolColumn get autoPostpone => boolean().withDefault(const Constant(true))();

// Migration
if (from < 9) {
  // 旧数据默认 false（不自动顺延），新任务默认 true
  await customStatement(
    'ALTER TABLE tasks ADD COLUMN auto_postpone INTEGER NOT NULL DEFAULT 0',
  );
}
```

### 自动顺延逻辑

```dart
// task_provider.dart
Future<int> performAutoPostpone() async {
  // 1. 检查全局开关
  final taskManagementSettings = ref.read(taskManagementSettingsProvider);
  if (!taskManagementSettings.enableAutoPostpone) return 0;

  // 2. 筛选符合条件的任务
  final tasksToPostpone = state.where((task) {
    if (!task.autoPostpone) return false;           // 任务级开关
    if (task.isCompleted || task.isDeleted) return false;
    if (task.dueDate == null) return false;
    return AmberDateUtils.isOverdue(task.dueDate!); // 已过期
  }).toList();

  // 3. 批量修改 dueDate 为今天
  final today = AmberDateUtils.normalizeToUtcDate(DateTime.now());
  for (final task in tasksToPostpone) {
    await database.updateTask(
      db.TasksCompanion(
        id: drift.Value(task.id),
        dueDate: drift.Value(today),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }
  return tasksToPostpone.length;
}
```

### 启动时执行

```dart
// app.dart
Future<void> _performAutoPostpone() async {
  // 等待 TaskManagementSettings 加载完成（避免竞态条件）
  await ref.read(taskManagementSettingsProvider.notifier).waitForLoad();

  // 等待 TaskNotifier 加载数据库数据
  await Future.delayed(const Duration(milliseconds: 300));

  final count = await ref.read(taskProvider.notifier).performAutoPostpone();
  if (count > 0) {
    debugPrint('[App] 自动顺延完成，已顺延 $count 个任务到今天');
  }
}
```

## UI 设计

### 已过期区域 (OverdueTasksSection)

- **位置**：今天视图顶部
- **颜色**：红色高亮（使用 `displaySettings.overdueLabelColorValue`）
- **交互**：
  - 可折叠/展开
  - "全部顺延"按钮（批量操作，有二次确认弹窗）
  - 每个任务 hover 时显示"顺延"按钮

### 今天视图 (TodayView)

```
┌──────────────────────────────┐
│ ▼ ⚠ 已过期 (3) [全部顺延]    │  ← 红色高亮区域
├──────────────────────────────┤
│   [任务1] 12/25 过期    [顺延]│
│   [任务2] 12/26 过期    [顺延]│
│   [任务3] 12/27 过期    [顺延]│
├──────────────────────────────┤
│ 今天的任务                    │  ← 正常任务区域
│   [任务4]                     │
│   [任务5]                     │
└──────────────────────────────┘
```

### 设置页面

设置页面新增"任务管理"Tab，包含：
- 自动顺延过期任务开关
- 功能说明卡片

## 注意事项

### Bug 修复记录

1. **Task.toggleComplete() 丢失 autoPostpone**
   - 问题：取消完成任务时，手动创建 Task 对象遗漏了 `autoPostpone` 字段
   - 修复：添加 `autoPostpone: autoPostpone` 到构造函数

2. **竞态条件**
   - 问题：`performAutoPostpone()` 可能在设置加载前执行，导致使用默认值
   - 修复：添加 `waitForLoad()` Completer 机制，确保设置加载完成

### 日期处理

使用 `AmberDateUtils` 工具类处理日期：
- `normalizeToUtcDate()` - 标准化日期到 UTC 零点
- `isOverdue()` - 判断日期是否已过期（早于今天）
- `isToday()` - 判断日期是否是今天

## 移动端小组件规划 (Android/iOS)

### Android 方案

| 方案 | 说明 |
|------|------|
| **ContentProvider** | 经典方案，小组件通过 ContentResolver 查询数据 |
| **Room + WorkManager** | 数据库 + 定时同步，小组件读数据库文件 |
| **App Widget Provider** | 通过 `onUpdate()` 主动推送数据到小组件 |

推荐用 **home_widget** 插件 + 原生 ContentProvider：
```
Flutter App → Drift DB → 导出 JSON → SharedPreferences
                                         ↓
Android Widget ← ContentProvider ← 读取 SharedPreferences
```

### iOS 方案

| 方案 | 说明 |
|------|------|
| **App Groups** | 创建共享容器，App 和 Widget 都能读写 |
| **UserDefaults (suiteName)** | 通过 App Group 共享 UserDefaults |
| **Core Data (shared container)** | 共享数据库文件 |

推荐用 **home_widget** 插件 + App Groups：
```
Flutter App → Drift DB → 导出 JSON → UserDefaults (App Group)
                                         ↓
iOS Widget (WidgetKit) ← 读取 UserDefaults
```

### 完成任务处理

小组件点击"完成"按钮的流程：
```
用户点击小组件 Checkbox
        ↓
触发 Intent / URL Scheme
        ↓
唤起主 App (后台处理)
        ↓
主 App 更新 Drift 数据库
        ↓
通知小组件刷新 (WidgetCenter.reloadAllTimelines)
```

## 测试要点

1. 新建任务，设置昨天的截止日期，重启 App 验证自动顺延
2. 关闭全局开关，验证不自动顺延
3. 在"已过期"区域点击"顺延"，验证任务移到今天
4. 点击"全部顺延"，验证批量操作和确认弹窗
5. 完成/取消完成任务，验证 `autoPostpone` 字段保留
