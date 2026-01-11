# 统计页面架构设计

本文档记录琥珀清单统计功能的数据来源、计算逻辑和架构设计。

---

## 核心概念

### 柱状图数据 vs 达成率

这两个指标有本质区别：

| 指标 | 数据来源 | 计算方式 | 说明 |
|------|---------|---------|------|
| **柱状图（完成趋势）** | `completedAt` | 当天所有已完成任务数 | 不管任务是否按时完成，只要在那天点了完成就算 |
| **达成率（折线图）** | `postponeCount` | 按时完成数 / 有截止日期的完成数 | 只有 `postponeCount == 0` 才算达成 |

### 关键理解

- **柱状图**：反映用户当天的"产出量"，完成了多少任务
- **达成率**：反映用户的"计划执行力"，有多少任务是按计划完成的

举例：
- 用户昨天设置了 5 个任务在今天完成
- 其中 2 个任务被顺延过（postponeCount > 0）
- 今天全部完成了
- 柱状图显示：5（今天完成了 5 个任务）
- 达成率显示：60%（3/5 按时完成）

---

## 数据库字段

为支持达成率统计，在 `tasks` 表新增两个字段：

```sql
-- 任务首次设置的截止日期（用于统计达成率）
original_due_date INTEGER

-- 任务被顺延的次数（用于统计达成率）
postpone_count INTEGER NOT NULL DEFAULT 0
```

### 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `original_due_date` | INTEGER (nullable) | 首次设置的截止日期，顺延时不修改 |
| `postpone_count` | INTEGER | 顺延次数，每次自动/手动顺延 +1 |

### 迁移逻辑

Schema 版本 10 添加迁移：
```sql
-- 添加新字段
ALTER TABLE tasks ADD COLUMN original_due_date INTEGER;
ALTER TABLE tasks ADD COLUMN postpone_count INTEGER NOT NULL DEFAULT 0;

-- 迁移现有数据：将现有 dueDate 复制到 originalDueDate
UPDATE tasks SET original_due_date = due_date WHERE due_date IS NOT NULL;
```

---

## 统计计算逻辑

### 本周完成数

```dart
// 统计 completedAt 在本周一到周日之间的任务数
final completed = tasks.where((t) =>
    t.isCompleted &&
    !t.isDeleted &&
    t.completedAt != null &&
    t.completedAt.isAfter(monday) &&
    t.completedAt.isBefore(sunday.add(Duration(days: 1)))
).length;
```

### 日均完成数

```dart
// 本周总完成数 / 已过天数（避免拉低平均值）
final today = DateTime.now().weekday; // 1=周一, 7=周日
final dailyAvg = totalCompleted / today;
```

### 每日达成率

**关键：按 `originalDueDate` 分组，不是按 `completedAt` 分组！**

```dart
// 获取所有未删除的任务（包括未完成的！）
final activeTasks = allTasks.where((t) => !t.isDeleted).toList();

// 遍历本周每一天
for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
  final dayDate = monday.add(Duration(days: dayIndex));

  // 跳过未来的天
  if (dayDate.isAfter(DateTime.now())) continue;

  int totalDueTasks = 0;  // "应该"在当天完成的任务数
  int achievedTasks = 0;  // 其中按时完成的（isCompleted && postponeCount == 0）

  for (final task in activeTasks) {
    // ✅ 按 originalDueDate 判断任务"应该"在哪天完成
    if (task.originalDueDate != null && isSameDay(task.originalDueDate, dayDate)) {
      totalDueTasks++;
      // ✅ 达成条件：已完成 + 没有被顺延过
      if (task.isCompleted && task.postponeCount == 0) {
        achievedTasks++;
      }
    }
  }

  // 达成率 = achievedTasks / totalDueTasks
  dailyRates[dayIndex] = totalDueTasks > 0
      ? achievedTasks / totalDueTasks
      : -1; // -1 表示当天无数据
}
```

### 常见错误理解

| 错误理解 | 正确理解 |
|---------|---------|
| 按 `completedAt` 分组 | 按 `originalDueDate` 分组 |
| 只统计已完成的任务 | 未完成的任务也算作"未达成" |
| "当天完成了多少任务" | "应该在当天完成的任务有多少达成了" |

**举例说明：**
- 周一应该完成 5 个任务（`originalDueDate = 周一`）
- 3 个按时完成（周一完成，`postponeCount = 0`）
- 1 个延期完成（周二完成，`postponeCount = 1`）
- 1 个还没完成
- **柱状图周一显示：3**（周一完成了 3 个）
- **达成率周一显示：60%**（3/5 = 应该完成 5 个，按时达成 3 个）

---

## 顺延计数触发点

以下操作会增加 `postponeCount`：

1. **自动顺延**（`performAutoPostpone`）
   - 每日启动时检查 `autoPostpone == true` 且 `dueDate` 已过期的任务
   - 将 `dueDate` 更新为今天，`postponeCount++`

2. **手动顺延**（`postponeTasks`）
   - 用户在已过期区域点击"顺延"按钮
   - 将 `dueDate` 更新为今天，`postponeCount++`

### 不触发顺延计数的情况

- 创建任务时设置截止日期（`postponeCount = 0`）
- 用户手动修改截止日期（非顺延操作）
- 任务完成/取消完成

---

## 文件结构

```
lib/presentation/
├── providers/
│   └── statistics_provider.dart  # 统计数据 Provider
└── pages/statistics/
    └── weekly_view.dart          # 周视图（使用真实数据）
```

---

## 数据流

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│   SQLite    │────▶│ StatisticsProvider│────▶│  WeeklyView │
│   tasks     │     │ (统计聚合)         │     │  (UI 展示)   │
└─────────────┘     └──────────────────┘     └─────────────┘
      │
      │ 字段
      ├── completedAt      → 柱状图
      ├── originalDueDate  → 达成率判断
      └── postponeCount    → 达成率判断
```

---

## 注意事项

1. **收集箱任务**：没有 `dueDate` 的任务不参与达成率计算
2. **历史数据迁移**：迁移时将现有 `dueDate` 复制到 `originalDueDate`，`postponeCount` 默认为 0
3. **周定义**：本周指周一 00:00 到周日 23:59（ISO 周标准）
4. **无数据显示**：折线图中 -1 值的点会被跳过，不显示
5. **性能考虑**：当前使用双层循环 `O(7 × 任务数)`，普通用户（几百个任务）无影响。如果任务量增长到几千上万个，可考虑以下优化：
   - 按 `originalDueDate` 建立索引
   - 使用 SQL 聚合查询代替内存遍历
   - 缓存统计结果

---

## 更新日志

### 2025-01-11
- 添加 `originalDueDate` 和 `postponeCount` 字段
- 创建 `StatisticsProvider` 统计查询
- 集成真实数据到 `WeeklyView`
- 将"专注趋势"改为"达成趋势"
