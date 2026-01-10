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

## 桌面端启动同步 + 自动顺延

### 背景问题

多设备场景下，自动顺延可能在多端同时执行，导致同步冲突：
- 设备 A 启动：任务 X 的 `due_date` 从"3天前"顺延到"今天"
- 设备 B 启动：任务 X 的 `due_date` 也从"3天前"顺延到"今天"
- 同步时：检测到两端都修改了 `due_date`，触发冲突

### 解决方案

1. **桌面端启动顺序**：`Cloud Sync → Auto Postpone → Hide Splash`
2. **移动端启动顺序**：`Auto Postpone → UI`（不阻塞同步）
3. **dueDate-only 冲突自动合并**：检测到仅 `due_date` 变化时，自动选择更晚的日期

### 文件变更

| 文件 | 变更 |
|------|------|
| `lib/presentation/providers/sync_provider.dart` | 添加 `waitForInitialSync()` 方法 |
| `lib/app.dart` | 添加 `_executeStartupSequence()` 统一入口 |
| `lib/data/services/sync/three_way_merge.dart` | 添加 `isDueDateOnlyConflict` 检测 + 自动合并逻辑 |
| `lib/data/services/sync/sync_manager.dart` | 修改 `ConflictResolutionCallback` 签名 |
| `lib/presentation/widgets/sync_conflict_dialog.dart` | 添加自动顺延合并 Banner |

### 关键代码

#### 桌面端启动序列

```dart
// app.dart
Future<void> _desktopStartupSequence() async {
  // 步骤1: 等待云同步完成（超时 30 秒）
  final syncSuccess = await _waitForCloudSync();

  // 步骤2: 执行自动顺延
  await _performAutoPostpone();

  // 步骤3: 隐藏 Splash
  await _hideSplash();
}
```

#### dueDate-only 冲突检测

```dart
// three_way_merge.dart - RecordConflict
bool get isDueDateOnlyConflict {
  if (tableName != 'tasks' || type != ConflictType.bothModified) return false;
  if (local == null || remote == null || base == null) return false;

  const allowedChangedFields = {'due_date', 'updated_at'};

  final localChangedFields = _getChangedFields(base!, local!);
  final remoteChangedFields = _getChangedFields(base!, remote!);

  // 确保变化字段都在允许列表内，且 due_date 确实变了
  return localChangedFields.every((f) => allowedChangedFields.contains(f)) &&
         remoteChangedFields.every((f) => allowedChangedFields.contains(f)) &&
         localChangedFields.contains('due_date') &&
         remoteChangedFields.contains('due_date');
}
```

#### 自动合并逻辑

```dart
// three_way_merge.dart - _mergeTasks()
if (conflict.isDueDateOnlyConflict) {
  // 自动合并：保留 due_date 更大的版本（更晚的日期）
  final localDueDate = local['due_date'] as int? ?? 0;
  final remoteDueDate = remote['due_date'] as int? ?? 0;
  if (remoteDueDate > localDueDate) {
    _updateRow(localDb, 'tasks', id, remote);
  }
  stats.autoPostponeMergedCount++;
} else {
  stats.pendingConflicts.add(conflict);
}
```

### 冲突弹窗 Banner

当存在自动合并的冲突且还有其他需要用户决策的冲突时，弹窗顶部显示绿色 Banner：

```
┌──────────────────────────────────────────┐
│ ✨ 已自动合并 3 个因自动顺延产生的冲突      │  ← 绿色 Banner
├──────────────────────────────────────────┤
│ ⚠️ 数据冲突                               │
│ 第 1 / 2 个冲突                           │
│ ...                                       │
└──────────────────────────────────────────┘
```

### 行为矩阵

| 平台 | 启动时同步 | 启动时顺延 | 同步冲突处理 |
|------|-----------|-----------|-------------|
| macOS/Windows | ✅ 阻塞（30s 超时） | ✅ 同步后执行 | 自动合并 dueDate-only |
| Android/iOS App | ✅ 后台非阻塞 | ✅ 同步后执行 | 自动合并 dueDate-only |
| Android Widget | ❌ 不同步 | ✅ onUpdate 时执行 | 无（只改本地数据库） |

### 测试要点

1. **桌面端启动同步**
   - 未配置云同步：跳过同步，正常进入
   - 首次同步：显示"检测到数据差异"弹窗
   - 同步超时：30 秒后继续启动

2. **多端自动顺延冲突**
   - 两端都将同一任务顺延到今天 → 自动合并，无弹窗
   - 两端顺延到不同日期 → 自动选择更晚的日期
   - 混合冲突（部分 dueDate，部分其他字段） → Banner + 弹窗

3. **移动端行为**
   - 启动不阻塞同步
   - 用户手动点刷新按钮触发同步

## 调试工具

### 重置自动顺延检查状态

位置：调试工具箱（Debug 模式下，点击右下角 🐛 按钮）→ 重置自动顺延检查

功能：清除 `lastAutoPostponeDate`，下次启动 App 时会重新执行自动顺延检查

使用场景：
- 测试自动顺延功能时，无需等到第二天
- 验证多端同步冲突处理逻辑

### lastAutoPostponeDate 机制

| 字段 | 位置 | 格式 | 作用 |
|------|------|------|------|
| `lastAutoPostponeDate` | TaskManagementSettings | `yyyy-MM-dd` | 记录上次执行自动顺延的日期 |

**检查逻辑：**

```dart
// task_management_settings_provider.dart
bool hasCheckedToday() {
  if (state.lastAutoPostponeDate == null) return false;
  final todayStr = '${today.year}-${today.month}-${today.day}';
  return state.lastAutoPostponeDate == todayStr;
}
```

**使用流程：**

```dart
// task_provider.dart - performAutoPostpone()
Future<int> performAutoPostpone() async {
  // 1. 检查今天是否已执行过
  if (notifier.hasCheckedToday()) {
    debugPrint('[TaskProvider] 今天已执行过自动顺延，跳过');
    return 0;
  }

  // 2. 执行顺延逻辑...

  // 3. 标记今天已检查
  notifier.setLastAutoPostponeDate(getTodayDateString());
}
```

**存储格式：**

```json
// SharedPreferences key: task_management_settings
{
  "enableAutoPostpone": true,
  "overdueExpanded": true,
  "lastAutoPostponeDate": "2025-01-10"
}
```

这个机制保证：
- 同一天内多次启动 App 只会执行一次顺延
- 跨天后重新执行顺延检查
- 不会每次启动都扫描数据库

## 原有测试要点

1. 新建任务，设置昨天的截止日期，重启 App 验证自动顺延
2. 关闭全局开关，验证不自动顺延
3. 在"已过期"区域点击"顺延"，验证任务移到今天
4. 点击"全部顺延"，验证批量操作和确认弹窗
5. 完成/取消完成任务，验证 `autoPostpone` 字段保留

## 移动端 (Android/iOS App) 启动序列

### 背景

移动端与桌面端的启动行为不同：
- **桌面端**：阻塞同步 → 阻塞顺延 → 显示 UI
- **移动端**：非阻塞同步 → 非阻塞顺延 → 立即显示 UI

移动端需要更快的启动速度，同时保证数据一致性。

### 实现

```dart
// app.dart
void _mobileStartupSequence() {
  debugPrint('[Startup] 移动端启动序列');
  _performMobileSyncAndPostpone(); // 后台执行，不阻塞
}

Future<void> _performMobileSyncAndPostpone() async {
  // 步骤1: 后台云同步
  final syncType = ref.read(syncTypeProvider);
  if (syncType != null) {
    final syncSuccess = await ref.read(syncStateProvider.notifier).manualSync();
    if (syncSuccess && mounted) {
      ToastManager().show(context, '☁️ 云同步完成', type: ToastType.success);
    }
  }

  // 步骤2: 自动顺延
  await ref.read(taskManagementSettingsProvider.notifier).waitForLoad();
  await Future.delayed(const Duration(milliseconds: 300));
  final count = await ref.read(taskProvider.notifier).performAutoPostpone();
  if (count > 0 && mounted) {
    ToastManager().show(context, '📅 已顺延 $count 个过期任务到今天', type: ToastType.info);
  }
}
```

### 用户体验

| 动作 | 结果 |
|------|------|
| 打开 App | 立即显示 UI |
| 后台同步完成 | Toast: "☁️ 云同步完成" |
| 后台顺延完成 | Toast: "📅 已顺延 X 个过期任务到今天" |

## Android Widget 自动顺延

### 背景

Android Widget 运行在独立进程，不依赖 Flutter App。需要在 Widget 刷新时（`onUpdate()`）独立执行自动顺延。

### 架构

```
┌───────────────────────────────────────────────────────────────────┐
│                    SharedPreferences                               │
│  Key: "flutter.task_management_settings"                          │
│  Value: {"enableAutoPostpone":true,"lastAutoPostponeDate":"..."}  │
└───────────────────────────────────────────────────────────────────┘
         ↑                                     ↑
         │ 读/写                                │ 读/写
         │                                     │
┌─────────────────┐                  ┌─────────────────────────────┐
│   Flutter App   │                  │      Android Widget         │
│                 │                  │                             │
│  启动时:        │                  │  onUpdate() 时:             │
│  1. 云同步      │                  │  1. performAutoPostpone()   │
│  2. 顺延        │                  │  2. 更新 Widget UI          │
│  3. Toast       │                  │                             │
└─────────────────┘                  └─────────────────────────────┘
         │                                     │
         │ 读/写                                │ 读/写
         ↓                                     ↓
┌───────────────────────────────────────────────────────────────────┐
│                      SQLite Database                               │
│  Path: /data/data/com.example.amber_list/app_flutter/amber_list.db│
│  Table: tasks (id, title, due_date, is_completed, auto_postpone)  │
└───────────────────────────────────────────────────────────────────┘
```

### 文件清单

| 文件 | 作用 |
|------|------|
| `WidgetSettingsHelper.kt` | 读写 SharedPreferences，管理 lastAutoPostponeDate |
| `WidgetDatabaseHelper.kt` | 直接操作 SQLite，执行 performAutoPostpone() |
| `AmberWidgetProvider.kt` | 小号 Widget，onUpdate() 中调用顺延 |
| `AmberWidgetMediumProvider.kt` | 中号 Widget，继承父类 onUpdate() |
| `AmberWidgetLargeProvider.kt` | 大号 Widget，继承父类 onUpdate() |

### 关键代码

#### WidgetSettingsHelper.kt

```kotlin
object WidgetSettingsHelper {
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val KEY = "flutter.task_management_settings"

    // 检查今天是否已执行顺延
    fun hasCheckedToday(context: Context): Boolean {
        val json = getSettingsJson(context) ?: return false
        val lastDate = json.optString("lastAutoPostponeDate", "")
        if (lastDate.length < 10) return false
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        return lastDate.substring(0, 10) == today
    }

    // 标记今天已执行顺延
    fun setCheckedToday(context: Context) {
        val json = getSettingsJson(context) ?: JSONObject()
        val now = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())
        json.put("lastAutoPostponeDate", now)
        saveSettingsJson(context, json)
    }

    // 检查全局开关
    fun isAutoPostponeEnabled(context: Context): Boolean {
        val json = getSettingsJson(context) ?: return true
        return json.optBoolean("enableAutoPostpone", true)
    }
}
```

#### WidgetDatabaseHelper.kt - performAutoPostpone()

```kotlin
fun performAutoPostpone(context: Context): Int {
    // 1. 检查全局开关
    if (!WidgetSettingsHelper.isAutoPostponeEnabled(context)) return 0

    // 2. 检查今天是否已执行
    if (WidgetSettingsHelper.hasCheckedToday(context)) return 0

    // 3. 打开数据库
    val database = SQLiteDatabase.openDatabase(dbPath, null, OPEN_READWRITE)

    // 4. 计算今天的时间戳（秒）
    val calendar = Calendar.getInstance()
    calendar.set(HOUR_OF_DAY, 0); calendar.set(MINUTE, 0); calendar.set(SECOND, 0)
    val todayStartSeconds = calendar.timeInMillis / 1000

    // 5. 更新过期任务
    database.execSQL("""
        UPDATE tasks
        SET due_date = ?, updated_at = ?
        WHERE is_deleted = 0
          AND is_completed = 0
          AND auto_postpone = 1
          AND due_date IS NOT NULL
          AND due_date < ?
    """, arrayOf(todayStartSeconds, nowSeconds, todayStartSeconds))

    // 6. 标记今天已检查
    WidgetSettingsHelper.setCheckedToday(context)

    return overdueCount
}
```

#### AmberWidgetProvider.kt - onUpdate()

```kotlin
override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
    Log.d(TAG, "onUpdate: ${appWidgetIds.size} widgets")

    // 先执行自动顺延
    val postponedCount = WidgetDatabaseHelper.performAutoPostpone(context)
    if (postponedCount > 0) {
        Log.d(TAG, "Auto-postponed $postponedCount overdue tasks to today")
    }

    // 再更新 Widget UI
    for (appWidgetId in appWidgetIds) {
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }
}
```

### 共享标记位机制

App 和 Widget 共享同一个 `lastAutoPostponeDate` 字段，保证同一天只执行一次顺延：

| 场景 | 执行顺延 | 原因 |
|------|---------|------|
| App 先启动 | ✅ App 执行 | Widget 读到 lastDate == today，跳过 |
| Widget 先刷新 | ✅ Widget 执行 | App 读到 lastDate == today，跳过 |
| 用户重置调试 | ✅ 下次执行 | lastDate 被清空 |

### 时间戳格式

| 来源 | 格式 | 示例 |
|------|------|------|
| Flutter App | `yyyy-MM-dd HH:mm:ss` | `2025-01-10 14:30:00` |
| Android Widget | `yyyy-MM-dd HH:mm:ss` | `2025-01-10 14:30:00` |
| SQLite due_date | Unix timestamp (秒) | `1736467200` |

**注意**：Drift 存储时间戳使用秒而非毫秒，Widget 代码需要 `/1000` 转换。

### 测试要点

1. **App 先启动**
   - 创建过期任务（昨天截止）
   - 启动 App，验证 Toast "已顺延 X 个过期任务"
   - 检查 Widget 显示的任务列表已更新

2. **Widget 先刷新**
   - 创建过期任务（昨天截止）
   - 重启手机或等待 Widget 自动刷新
   - 检查 Widget 显示的过期任务变成今天的任务
   - 启动 App，验证不再重复顺延

3. **关闭全局开关**
   - 设置 → 任务管理 → 关闭"自动顺延"
   - Widget 刷新时不应顺延过期任务

4. **任务级别控制**
   - 创建两个过期任务，其中一个 `autoPostpone = false`
   - Widget 刷新后只顺延 `autoPostpone = true` 的任务

## iOS Widget 自动顺延

### 背景

iOS Widget 运行在 WidgetKit Extension 进程，与主 App 分离。需要在 Widget Timeline 刷新时独立执行自动顺延。

### 架构

```
┌───────────────────────────────────────────────────────────────────┐
│                 App Group UserDefaults                             │
│  Suite: "group.com.amberlist.amberList"                           │
│  Key: "task_management_settings"                                  │
│  Value: {"enableAutoPostpone":true,"lastAutoPostponeDate":"..."}  │
└───────────────────────────────────────────────────────────────────┘
         ↑                                     ↑
         │ 读/写 (HomeWidget)                   │ 读/写 (UserDefaults)
         │                                     │
┌─────────────────┐                  ┌─────────────────────────────┐
│   Flutter App   │                  │      iOS Widget             │
│                 │                  │     (WidgetKit)             │
│  启动时:        │                  │                             │
│  1. 云同步      │                  │  timeline() 时:             │
│  2. 顺延        │                  │  1. performAutoPostpone()   │
│  3. Toast       │                  │  2. 加载任务列表            │
│                 │                  │  3. 返回 Timeline           │
└─────────────────┘                  └─────────────────────────────┘
         │                                     │
         │ 读/写                                │ 读/写
         ↓                                     ↓
┌───────────────────────────────────────────────────────────────────┐
│                      SQLite Database                               │
│  Path: App Group Container/amber_list.db                          │
│  Table: tasks (id, title, due_date, is_completed, auto_postpone)  │
└───────────────────────────────────────────────────────────────────┘
```

### 文件清单

| 文件 | 作用 |
|------|------|
| `ios/AmberWidget/Models/WidgetSettingsHelper.swift` | **新文件** - 读写 App Group UserDefaults |
| `ios/AmberWidget/Models/WidgetDatabaseHelper.swift` | 添加 `performAutoPostpone()` 方法 |
| `ios/AmberWidget/Views/SmallWidgetView.swift` | `timeline()` 中调用顺延 |
| `ios/AmberWidget/Views/MediumWidgetView.swift` | `timeline()` 中调用顺延 |
| `ios/AmberWidget/Views/LargeWidgetView.swift` | `timeline()` 中调用顺延 |
| `lib/presentation/providers/task_management_settings_provider.dart` | iOS 平台同步设置到 App Group |

### 关键代码

#### WidgetSettingsHelper.swift

```swift
class WidgetSettingsHelper {
    private static let appGroupID = "group.com.amberlist.amberList"
    private static let settingsKey = "task_management_settings"

    /// 检查今天是否已执行顺延
    static func hasCheckedToday() -> Bool {
        guard let json = loadSettingsJson(),
              let lastDate = json["lastAutoPostponeDate"] as? String,
              !lastDate.isEmpty else { return false }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let lastDatePart = lastDate.count >= 10 ? String(lastDate.prefix(10)) : lastDate

        return lastDatePart == today
    }

    /// 标记今天已执行顺延
    static func setCheckedToday() {
        var json = loadSettingsJson() ?? [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        json["lastAutoPostponeDate"] = formatter.string(from: Date())
        saveSettingsJson(json)
    }

    /// 检查全局开关
    static func isAutoPostponeEnabled() -> Bool {
        guard let json = loadSettingsJson() else { return true }
        return json["enableAutoPostpone"] as? Bool ?? true
    }
}
```

#### WidgetDatabaseHelper.swift - performAutoPostpone()

```swift
static func performAutoPostpone() -> Int {
    // 1. 检查全局开关
    guard WidgetSettingsHelper.isAutoPostponeEnabled() else { return 0 }

    // 2. 检查今天是否已执行
    guard !WidgetSettingsHelper.hasCheckedToday() else { return 0 }

    // 3. 打开数据库
    guard let db = openDatabase() else { return 0 }
    defer { closeDatabase(db) }

    // 4. 计算今天的时间戳（秒）
    var calendar = Calendar.current
    calendar.timeZone = TimeZone.current
    let todayStart = calendar.startOfDay(for: Date())
    let todayStartSeconds = Int64(todayStart.timeIntervalSince1970)
    let nowSeconds = Int64(Date().timeIntervalSince1970)

    // 5. 统计过期任务数
    // SELECT COUNT(*) FROM tasks WHERE ... due_date < todayStartSeconds

    // 6. 更新过期任务
    // UPDATE tasks SET due_date = todayStartSeconds, updated_at = nowSeconds
    // WHERE is_deleted = 0 AND is_completed = 0 AND auto_postpone = 1
    //   AND due_date IS NOT NULL AND due_date < todayStartSeconds

    // 7. 仅在 UPDATE 成功时标记今天已检查
    if sqlite3_step(updateStmt) == SQLITE_DONE {
        WidgetSettingsHelper.setCheckedToday()
        return overdueCount
    }
    return 0
}
```

#### Timeline Provider 调用

```swift
// SmallWidgetView.swift, MediumWidgetView.swift, LargeWidgetView.swift
func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
    // 先执行自动顺延（在加载任务之前）
    let postponedCount = WidgetDatabaseHelper.performAutoPostpone()
    if postponedCount > 0 {
        print("[Widget] Auto-postponed \(postponedCount) overdue tasks to today")
    }

    // 再加载任务列表
    let tasks = WidgetDataStore.loadTodayTasks()
    // ... 构建 Timeline Entry
}
```

#### Flutter 端同步设置

```dart
// task_management_settings_provider.dart
Future<void> _saveSettings() async {
    final jsonStr = jsonEncode(state.toJson());

    // Android: SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonStr);

    // iOS: App Group UserDefaults (通过 home_widget 插件)
    if (Platform.isIOS) {
        await HomeWidget.saveWidgetData<String>(_configKey, jsonStr);
    }
}

Future<bool> hasCheckedToday() async {
    String? jsonStr;
    if (Platform.isIOS) {
        // iOS: 从 App Group 读取（Widget 也写入这里）
        jsonStr = await HomeWidget.getWidgetData<String>(_configKey);
    } else {
        // Android: 从 SharedPreferences 读取
        final prefs = await SharedPreferences.getInstance();
        jsonStr = prefs.getString(_configKey);
    }
    // ... 比较日期
}
```

### 与 Android Widget 的差异

| 项目 | Android Widget | iOS Widget |
|------|----------------|------------|
| **数据共享方式** | FlutterSharedPreferences | App Group UserDefaults |
| **数据库路径** | `/data/data/{pkg}/app_flutter/` | App Group Container |
| **设置读取** | SharedPreferences (直接) | HomeWidget.getWidgetData() |
| **刷新触发点** | `onUpdate()` | `timeline()` |
| **最小刷新间隔** | 30 分钟 | 系统智能调度 |

### 共享标记位机制

iOS 平台的 App 和 Widget 通过 App Group UserDefaults 共享 `lastAutoPostponeDate`：

| 场景 | 执行顺延 | 原因 |
|------|---------|------|
| App 先启动 | ✅ App 执行 | Widget 读到 lastDate == today，跳过 |
| Widget 先刷新 | ✅ Widget 执行 | App 读到 lastDate == today，跳过 |
| 用户重置调试 | ✅ 下次执行 | lastDate 被清空 |

### iOS Widget 测试要点

1. **App 先启动**
   - 创建过期任务（昨天截止）
   - 启动 App，验证 Toast "已顺延 X 个过期任务"
   - 检查 Widget 显示的任务列表已更新

2. **Widget 先刷新**
   - 创建过期任务（昨天截止）
   - 等待 Widget Timeline 自动刷新
   - 检查 Widget 显示的过期任务变成今天的任务
   - 启动 App，验证不再重复顺延

3. **关闭全局开关**
   - 设置 → 任务管理 → 关闭"自动顺延"
   - Widget 刷新时不应顺延过期任务

4. **App Group 共享验证**
   - App 中修改设置后，Widget 应能读取到最新值
   - Widget 执行顺延后，App 应能感知到 lastDate 已更新

## 已修复 Bug

### 移动端启动列表抖动 (2025-01-10)

#### 现象

移动端（Android/iOS）启动 App 时，任务列表会"抖动一下"：
- 列表已经加载完成（比如 47 条任务）
- 然后整个列表闪一下，刷新了一次
- 刷新前后数据完全相同

用户体验极差，看起来像是 bug。

#### 排查过程

1. **最初误判**：以为是 `launch_background.xml` 只有白色背景没 Logo（错误方向）

2. **第一次尝试**：在 `TaskNotifier._init()` 添加 `_isTaskListEqual()` 比较新旧列表
   - 结果：还是抖动
   - 原因：问题不在列表比较，而在上游

3. **第二次尝试**：将 `HomePage` 中 watch `syncStateProvider`/`syncTypeProvider` 的代码抽成独立的 `_MobileSyncButton` ConsumerWidget
   - 结果：还是抖动
   - 原因：问题不在 Provider watch 范围

4. **加调试日志**：在 stream 监听处打印日志
   ```dart
   debugPrint('[TaskNotifier] stream 触发，更新数据: ${state.length} -> ${tasks.length}');
   ```

5. **关键发现**：日志显示 TWO 次 `stream 触发，更新数据: 0 -> 47`
   ```
   [SyncProvider] 同步成功，刷新数据库连接...
   [TaskNotifier] stream 触发，更新数据: 0 -> 47
   [TaskNotifier] stream 触发，更新数据: 0 -> 47
   ```

6. **根因定位**：
   - 同步完成（即使"双端无变化"）后调用了 `_ref.invalidate(databaseProvider)`
   - `invalidate` 导致 `TaskNotifier` 被重建，状态从 `[]` 开始
   - 数据库 stream 重新触发 `0 -> 47` 的更新
   - 用户看到的就是列表从无到有的"闪烁"

#### 根本原因

```dart
// sync_provider.dart - 旧代码
_syncManager!.onSyncComplete = (success) {
  if (success) {
    debugPrint('[SyncProvider] 同步成功，刷新数据库连接...');
    _ref.invalidate(databaseProvider);  // ← 无论是否有数据变化都 invalidate！
  }
};
```

问题：**"双端无变化"时也执行了 `invalidate(databaseProvider)`**

`invalidate` 会导致所有依赖 `databaseProvider` 的 Provider 重建：
1. `TaskNotifier` 被重建，`state` 初始化为 `[]`
2. 新的数据库 stream 触发，`state` 从 `[]` 变成 `[47条任务]`
3. Riverpod 触发 UI 重建 → 用户看到列表"刷新"

#### 解决方案

**Step 1: 在 `SyncManager` 添加 `hasDataChanged` 标记**

```dart
// sync_manager.dart
class SyncManager {
  /// 最后一次同步是否有数据变化
  bool _hasDataChanged = false;
  bool get hasDataChanged => _hasDataChanged;

  Future<bool> sync({...}) async {
    _isSyncing = true;
    _hasDataChanged = true;  // 默认有变化

    // ... 同步逻辑 ...

    // 双端无变化时
    if (localHash == remoteHash) {
      _hasDataChanged = false;  // ← 标记无变化
      return true;
    }

    // ... 有变化的处理 ...
  }
}
```

**Step 2: 在 `sync_provider.dart` 检查 `hasDataChanged`**

```dart
// sync_provider.dart
_syncManager!.onSyncComplete = (success) {
  if (success && _syncManager!.hasDataChanged) {
    debugPrint('[SyncProvider] 同步成功且有数据变化，刷新数据库连接...');
    _ref.invalidate(databaseProvider);
  } else if (success) {
    debugPrint('[SyncProvider] 同步成功但无数据变化，跳过刷新');
  }
};
```

**Step 3: 保留列表比较作为兜底**

```dart
// task_provider.dart
void _init() {
  database.watchAllTasks().listen((dbTasks) {
    final tasks = _sortTasks(dbTasks.map(_mapDbTaskToModel).toList());
    // 避免数据相同时重复刷新 UI（防止启动闪屏）
    if (_isTaskListEqual(state, tasks)) {
      return;
    }
    state = tasks;
    _updateHomeWidget(tasks);
  });
}

bool _isTaskListEqual(List<Task> oldList, List<Task> newList) {
  if (oldList.length != newList.length) return false;
  for (int i = 0; i < oldList.length; i++) {
    if (oldList[i].id != newList[i].id ||
        oldList[i].title != newList[i].title ||
        oldList[i].isCompleted != newList[i].isCompleted ||
        oldList[i].dueDate != newList[i].dueDate ||
        oldList[i].priority != newList[i].priority ||
        oldList[i].updatedAt != newList[i].updatedAt) {
      return false;
    }
  }
  return true;
}
```

#### 修改文件清单

| 文件 | 变更 |
|------|------|
| `lib/data/services/sync/sync_manager.dart` | 添加 `_hasDataChanged` 标记，"双端无变化"时设为 false |
| `lib/presentation/providers/sync_provider.dart` | 检查 `hasDataChanged` 后再 `invalidate` |
| `lib/presentation/providers/task_provider.dart` | 添加 `_isTaskListEqual()` 兜底比较 |
| `lib/presentation/pages/home_page.dart` | 抽离 `_MobileSyncButton` 独立组件（优化，非必须） |

#### 经验总结

1. **Provider `invalidate` 是核心杀器**：它会重建整个依赖链，用之前要三思
2. **"无变化"场景容易被忽略**：同步成功 ≠ 有数据变化，这两个概念要区分
3. **调试日志是破案利器**：当 UI 行为诡异时，在关键节点打 log 能快速定位
4. **多层防御**：即使修了根因，也保留 `_isTaskListEqual` 兜底，防止其他路径触发相同问题
