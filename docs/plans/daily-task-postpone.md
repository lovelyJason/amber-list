# 每日任务顺延功能 - 架构设计

## 一、核心需求

### 1.1 功能目标
- 过期任务自动顺延到"今天"（真实修改 dueDate）
- 兼容旧数据（不自动顺延，但在"今天"视图显示）
- 支持手动批量顺延

### 1.2 用户场景
1. **新任务**：创建时 `autoPostpone=true`（默认），过期后自动顺延
2. **旧数据**：`autoPostpone=false`（数据库迁移默认值），显示在"已过期"区域
3. **手动关闭**：用户可针对特定任务关闭自动顺延

---

## 二、数据层设计

### 2.1 Tasks 表扩展

```sql
ALTER TABLE tasks ADD COLUMN auto_postpone INTEGER NOT NULL DEFAULT 0;
-- 0 = false (旧数据兼容)
-- 1 = true (新任务默认)
```

**迁移策略**：
- 旧数据：`auto_postpone = 0`（不自动顺延，显示在已过期区域）
- 新数据：`auto_postpone = 1`（自动顺延）

### 2.2 Task Model 扩展

```dart
class Task {
  // ... 现有字段
  final bool autoPostpone; // 新增：是否自动顺延

  const Task({
    // ...
    this.autoPostpone = true, // 新任务默认开启
  });
}
```

### 2.3 设置扩展 (DisplaySettings)

```dart
class DisplaySettings {
  // ... 现有字段
  final bool enableAutoPostpone; // 全局开关：是否启用自动顺延功能

  // 默认开启
}
```

---

## 三、业务逻辑层设计

### 3.1 自动顺延触发时机

**App 启动时**（TaskNotifier 初始化后）：

```dart
Future<void> performAutoPostpone() async {
  // 1. 检查全局开关是否开启
  if (!displaySettings.enableAutoPostpone) return;

  // 2. 查询所有需要自动顺延的任务
  //    条件：autoPostpone=true AND dueDate < today AND !isCompleted AND !isDeleted
  final tasksToPostpone = await _getTasksNeedingPostpone();

  // 3. 批量更新 dueDate 为今天
  for (final task in tasksToPostpone) {
    await updateTask(task.copyWith(
      dueDate: AmberDateUtils.normalizeToUtcDate(DateTime.now()),
      updatedAt: DateTime.now(),
    ));
  }

  // 4. 记录日志（可选：显示 Toast 提示用户）
  if (tasksToPostpone.isNotEmpty) {
    debugPrint('[AutoPostpone] Postponed ${tasksToPostpone.length} tasks to today');
  }
}
```

### 3.2 Provider 设计

```dart
/// 已过期任务 Provider
/// 条件：dueDate < today AND !isCompleted AND !isDeleted
/// 注意：这里包含 autoPostpone=true 和 false 的任务
///       因为 autoPostpone=true 的任务在启动时已经被顺延了
///       所以运行时这里只会有 autoPostpone=false 的过期任务
final overdueTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(taskNotifierProvider);
  final today = AmberDateUtils.today();

  return tasks.where((task) {
    if (task.isCompleted || task.isDeleted) return false;
    if (task.dueDate == null) return false;
    return AmberDateUtils.isOverdue(task.dueDate!);
  }).toList();
});

/// 今天视图的任务 Provider（含已过期）
final todayViewTasksProvider = Provider<TodayViewTasks>((ref) {
  final allTasks = ref.watch(taskNotifierProvider);
  final today = AmberDateUtils.today();

  final todayTasks = <Task>[];
  final overdueTasks = <Task>[];

  for (final task in allTasks) {
    if (task.isCompleted || task.isDeleted) continue;
    if (task.dueDate == null) continue;

    if (AmberDateUtils.isToday(task.dueDate!)) {
      todayTasks.add(task);
    } else if (AmberDateUtils.isOverdue(task.dueDate!)) {
      overdueTasks.add(task);
    }
  }

  return TodayViewTasks(
    todayTasks: todayTasks,
    overdueTasks: overdueTasks,
  );
});

/// 今天视图数据模型
class TodayViewTasks {
  final List<Task> todayTasks;
  final List<Task> overdueTasks;

  const TodayViewTasks({
    required this.todayTasks,
    required this.overdueTasks,
  });

  bool get hasOverdue => overdueTasks.isNotEmpty;
  int get totalCount => todayTasks.length + overdueTasks.length;
}
```

### 3.3 批量顺延方法

```dart
/// 批量顺延过期任务到今天
Future<void> postponeOverdueTasks(List<String> taskIds) async {
  final today = AmberDateUtils.normalizeToUtcDate(DateTime.now());
  final now = DateTime.now();

  for (final taskId in taskIds) {
    final task = state.firstWhere((t) => t.id == taskId);
    await updateTask(task.copyWith(
      dueDate: today,
      updatedAt: now,
    ));
  }
}

/// 顺延所有过期任务
Future<void> postponeAllOverdueTasks() async {
  final overdueTasks = state.where((task) {
    if (task.isCompleted || task.isDeleted) return false;
    if (task.dueDate == null) return false;
    return AmberDateUtils.isOverdue(task.dueDate!);
  }).toList();

  await postponeOverdueTasks(overdueTasks.map((t) => t.id).toList());
}
```

---

## 四、UI 层设计

### 4.1 今天视图结构

```
┌─────────────────────────────────────┐
│  已过期 (3)              [全部顺延]  │  ← 过期区域（红色背景）
├─────────────────────────────────────┤
│  ⚠️ 任务A (1月5日)         [顺延]   │
│  ⚠️ 任务B (1月3日)         [顺延]   │
│  ⚠️ 任务C (1月1日)         [顺延]   │
├─────────────────────────────────────┤
│  今天 (5)                           │  ← 今天区域
├─────────────────────────────────────┤
│  ☐ 任务D                            │
│  ☐ 任务E                            │
│  ...                                │
└─────────────────────────────────────┘
```

### 4.2 过期区域组件

```dart
class OverdueTasksSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdueTasks = ref.watch(overdueTasksProvider);

    if (overdueTasks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏：已过期 (N) + 全部顺延按钮
        _buildHeader(context, ref, overdueTasks.length),

        // 过期任务列表
        ...overdueTasks.map((task) => OverdueTaskTile(
          task: task,
          onPostpone: () => _postponeTask(ref, task),
        )),

        const Divider(),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, int count) {
    return Row(
      children: [
        Icon(Icons.warning_amber_rounded, color: Colors.red),
        Text('已过期 ($count)', style: TextStyle(color: Colors.red)),
        const Spacer(),
        TextButton(
          onPressed: () => ref.read(taskNotifierProvider.notifier)
              .postponeAllOverdueTasks(),
          child: const Text('全部顺延'),
        ),
      ],
    );
  }
}
```

### 4.3 设置页面

```dart
// 在 display_tab.dart 中添加
SwitchListTile(
  title: const Text('每日任务自动顺延'),
  subtitle: const Text('自动将过期任务移动到今天'),
  value: settings.enableAutoPostpone,
  onChanged: (value) {
    ref.read(displaySettingsProvider.notifier)
        .setEnableAutoPostpone(value);
  },
),
```

---

## 五、数据流程图

```
App 启动
    │
    ▼
TaskNotifier 初始化
    │
    ▼
performAutoPostpone()
    │
    ├─── 全局开关关闭 ──→ 跳过
    │
    ▼
查询过期任务 (autoPostpone=true AND dueDate<today)
    │
    ▼
批量更新 dueDate = today
    │
    ▼
UI 刷新
    │
    ├─── 今天视图：显示今天的任务 + 剩余过期任务(autoPostpone=false)
    │
    ▼
用户操作
    ├─── 点击"顺延"按钮 ──→ 单个任务 dueDate = today
    ├─── 点击"全部顺延" ──→ 所有过期任务 dueDate = today
    └─── 关闭全局开关 ──→ 下次启动不自动顺延
```

---

## 六、实现清单

### Phase 1: 数据层
- [ ] 1.1 修改 `tasks.drift` 添加 `auto_postpone` 列
- [ ] 1.2 添加数据库迁移脚本 (版本号 +1)
- [ ] 1.3 修改 `Task` model 添加 `autoPostpone` 字段
- [ ] 1.4 修改 `TaskDao` 的 CRUD 方法支持新字段

### Phase 2: 设置层
- [ ] 2.1 修改 `DisplaySettings` 添加 `enableAutoPostpone` 字段
- [ ] 2.2 修改 `DisplaySettingsNotifier` 添加设置方法
- [ ] 2.3 在设置页面添加开关 UI

### Phase 3: 业务逻辑层
- [ ] 3.1 添加 `overdueTasksProvider`
- [ ] 3.2 添加 `todayViewTasksProvider` (返回今天+过期)
- [ ] 3.3 添加 `performAutoPostpone()` 方法
- [ ] 3.4 添加 `postponeOverdueTasks()` 批量顺延方法
- [ ] 3.5 在 App 启动时调用自动顺延

### Phase 4: UI 层
- [ ] 4.1 创建 `OverdueTasksSection` 组件
- [ ] 4.2 创建 `OverdueTaskTile` 组件（带顺延按钮）
- [ ] 4.3 修改 `TaskListView` 集成过期区域
- [ ] 4.4 在今天视图顶部显示过期区域

### Phase 5: 测试
- [ ] 5.1 测试旧数据迁移（autoPostpone=false）
- [ ] 5.2 测试新任务创建（autoPostpone=true）
- [ ] 5.3 测试自动顺延逻辑
- [ ] 5.4 测试手动顺延按钮
- [ ] 5.5 测试全局开关效果

---

## 七、未来扩展：Widget 数据同步

### 7.1 数据同步策略
- 主 App 在任务变更时同步数据到 SharedPreferences
- Widget 只读取 SharedPreferences，不直接访问 SQLite
- 格式：JSON 数组，包含今天和过期的任务

### 7.2 同步触发点
- 任务创建/更新/删除
- 自动顺延执行后
- App 进入后台时

### 7.3 Widget 刷新
- iOS: `WidgetCenter.shared.reloadAllTimelines()`
- Android: `AppWidgetManager.updateAppWidget()`

（Widget 功能将在后续版本实现）
