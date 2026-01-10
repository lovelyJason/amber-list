# 琥珀清单 - 数据模型文档

## 概述

本文档定义了琥珀清单应用的核心数据模型，包括任务、清单、笔记等实体的结构定义。

---

## Task（任务）

### 定义

```dart
class Task {
  final String id;           // UUID
  final String title;        // 任务标题
  final String? description; // 任务描述
  final String? listId;      // 所属清单ID
  final DateTime? dueDate;   // 截止日期
  final TaskPriority priority; // 优先级
  final bool isCompleted;    // 是否完成
  final DateTime? completedAt; // 完成时间
  final List<String> tags;   // 标签列表
  final int sortOrder;       // 排序序号
  final String? parentId;    // 父任务ID（子任务用）
  final DateTime createdAt;  // 创建时间
  final DateTime updatedAt;  // 更新时间
}
```

### 优先级枚举

```dart
enum TaskPriority {
  none(0),    // 无优先级
  low(1),     // 低
  medium(2),  // 中
  high(3);    // 高

  final int value;
  const TaskPriority(this.value);
}
```

### 字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | String | ✓ | UUID v4 格式的唯一标识符 |
| title | String | ✓ | 任务标题，不能为空 |
| description | String? | | 任务的详细描述，支持多行文本 |
| listId | String? | | 所属清单的ID，null表示在收集箱 |
| dueDate | DateTime? | | 任务截止日期（仅日期，不含时间） |
| priority | TaskPriority | ✓ | 优先级，默认为 none |
| isCompleted | bool | ✓ | 完成状态，默认为 false |
| completedAt | DateTime? | | 完成时间，完成时自动设置 |
| tags | List<String> | ✓ | 标签列表，默认为空列表 |
| sortOrder | int | ✓ | 排序序号，默认为 0 |
| parentId | String? | | 父任务ID，用于子任务 |
| createdAt | DateTime | ✓ | 创建时间，自动设置 |
| updatedAt | DateTime | ✓ | 更新时间，每次修改自动更新 |

### 方法

```dart
// 切换完成状态
Task toggleComplete() {
  return copyWith(
    isCompleted: !isCompleted,
    completedAt: !isCompleted ? DateTime.now() : null,
    updatedAt: DateTime.now(),
  );
}
```

---

## TaskList（清单）

### 定义

```dart
class TaskList {
  final String id;        // UUID
  final String name;      // 清单名称
  final IconData icon;    // 图标
  final Color color;      // 颜色
  final int sortOrder;    // 排序序号
  final DateTime createdAt; // 创建时间
  final DateTime updatedAt; // 更新时间
}
```

### 字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | String | ✓ | UUID v4 格式的唯一标识符 |
| name | String | ✓ | 清单名称，不能为空 |
| icon | IconData | ✓ | Material图标，默认为 Icons.list_rounded |
| color | Color | ✓ | 清单颜色，用于标识 |
| sortOrder | int | ✓ | 排序序号 |
| createdAt | DateTime | ✓ | 创建时间 |
| updatedAt | DateTime | ✓ | 更新时间 |

### 预设清单

```dart
// 默认清单
[
  TaskList(id: 'work', name: '工作', color: AmberColors.primary),
  TaskList(id: 'personal', name: '生活', color: AmberColors.info),
  TaskList(id: 'shopping', name: '购物', color: AmberColors.success),
]
```

---

## Note（笔记）

### 定义

```dart
class Note {
  final String id;        // UUID
  final String title;     // 标题
  final String content;   // 内容（Markdown格式）
  final String? folderId; // 文件夹ID
  final List<String> tags; // 标签列表
  final bool isPinned;    // 是否置顶
  final DateTime createdAt; // 创建时间
  final DateTime updatedAt; // 更新时间
}
```

### 字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | String | ✓ | UUID v4 格式的唯一标识符 |
| title | String | ✓ | 笔记标题 |
| content | String | ✓ | Markdown格式的内容，默认为空 |
| folderId | String? | | 所属文件夹ID |
| tags | List<String> | ✓ | 标签列表 |
| isPinned | bool | ✓ | 是否置顶，默认为 false |
| createdAt | DateTime | ✓ | 创建时间 |
| updatedAt | DateTime | ✓ | 更新时间 |

### 计算属性

```dart
// 获取内容摘要（用于卡片展示）
String get summary {
  if (content.isEmpty) return '';
  final lines = content.split('\n')
    .where((l) => l.trim().isNotEmpty)
    .toList();
  if (lines.isEmpty) return '';
  final text = lines.take(3).join(' ');
  return text.length > 100 ? '${text.substring(0, 100)}...' : text;
}
```

---

## Tag（标签）

### 定义

```dart
class Tag {
  final String id;        // UUID
  final String name;      // 标签名称
  final Color color;      // 标签颜色
  final DateTime createdAt; // 创建时间
}
```

### 字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | String | ✓ | UUID v4 |
| name | String | ✓ | 标签名称，唯一 |
| color | Color | ✓ | 标签颜色 |
| createdAt | DateTime | ✓ | 创建时间 |

---

## 导航状态

### NavView（视图类型）

```dart
enum NavView {
  inbox,    // 收集箱
  today,    // 今天
  upcoming, // 最近7天
  calendar, // 日历
  notes,    // 笔记
  list,     // 自定义清单
}
```

### AppNavState（应用导航状态）

```dart
class AppNavState {
  final NavView currentView;     // 当前视图
  final String? selectedListId;  // 选中的清单ID
  final String? selectedTaskId;  // 选中的任务ID
  final bool isDetailPanelOpen;  // 详情面板是否打开
}
```

---

## JSON 序列化

### Task JSON 格式

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "完成UI设计",
  "description": "包括配色、布局等",
  "listId": "work",
  "dueDate": "2024-12-28T00:00:00.000Z",
  "priority": 3,
  "isCompleted": false,
  "completedAt": null,
  "tags": ["设计", "重要"],
  "sortOrder": 0,
  "parentId": null,
  "createdAt": "2024-12-26T10:00:00.000Z",
  "updatedAt": "2024-12-28T15:30:00.000Z"
}
```

### Note JSON 格式

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440001",
  "title": "项目笔记",
  "content": "## 概述\n\n这是项目的主要笔记...",
  "folderId": null,
  "tags": ["工作", "项目"],
  "isPinned": true,
  "createdAt": "2024-12-25T09:00:00.000Z",
  "updatedAt": "2024-12-28T14:00:00.000Z"
}
```

---

## 数据验证规则

### Task

- `title` 不能为空，最大长度 500 字符
- `description` 最大长度 10000 字符
- `tags` 最多 10 个标签，每个标签最大 50 字符
- `priority` 必须在 0-3 范围内

### TaskList

- `name` 不能为空，最大长度 100 字符
- `color` 必须是有效的颜色值

### Note

- `title` 不能为空，最大长度 200 字符
- `content` 最大长度 100000 字符
- `tags` 最多 10 个标签

---

## 数据库存储

### SQLite 表结构

使用 Flutter Drift ORM，数据库文件名：`amber_list.db`

#### tasks 表

```sql
CREATE TABLE tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  list_id TEXT REFERENCES task_lists(id),
  due_date INTEGER,           -- Unix 时间戳（秒级！不是毫秒）
  priority INTEGER DEFAULT 0,
  is_completed INTEGER DEFAULT 0,
  is_in_progress INTEGER DEFAULT 0,
  is_deleted INTEGER DEFAULT 0,
  completed_at INTEGER,       -- Unix 时间戳（秒级）
  tags TEXT DEFAULT '[]',     -- JSON 数组
  sort_order INTEGER DEFAULT 0,
  parent_id TEXT,
  auto_postpone INTEGER DEFAULT 1,
  created_at INTEGER NOT NULL, -- Unix 时间戳（秒级）
  updated_at INTEGER NOT NULL  -- Unix 时间戳（秒级）
);
```

#### task_lists 表

```sql
CREATE TABLE task_lists (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  icon TEXT DEFAULT 'list',
  color INTEGER NOT NULL,
  sort_order INTEGER DEFAULT 0,
  parent_id TEXT,
  is_folder INTEGER DEFAULT 0,
  tags TEXT DEFAULT '[]',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

#### notes 表

```sql
CREATE TABLE notes (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  content TEXT DEFAULT '',
  folder_id TEXT,
  tags TEXT DEFAULT '[]',
  is_pinned INTEGER DEFAULT 0,
  sort_order INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

#### tags 表

```sql
CREATE TABLE tags (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  color INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);
```

### 时间戳格式

**重要**：所有 `DateTime` 类型字段在 SQLite 中存储为 **秒级 Unix 时间戳**（INTEGER），不是毫秒！

```dart
// Flutter Drift 存储示例
// due_date = 1768003200 表示 2026-01-09 00:00:00 UTC

// 转换为 DateTime
final dueDate = DateTime.fromMillisecondsSinceEpoch(dbValue * 1000);

// 或使用秒级转换
final dueDate = DateTime.fromMicrosecondsSinceEpoch(dbValue * 1000000);
```

```swift
// iOS Swift 读取示例
let dueDateSeconds = sqlite3_column_int64(statement, 4)
let dueDate = Date(timeIntervalSince1970: Double(dueDateSeconds))
```

```kotlin
// Android Kotlin 读取示例
val dueDateSeconds = cursor.getLong(cursor.getColumnIndex("due_date"))
val dueDate = Date(dueDateSeconds * 1000)
```

### JSON 字段

标签列表在数据库中以 JSON 字符串形式存储：

```sql
-- 存储格式
tags TEXT DEFAULT '[]'

-- 示例
'["设计", "重要", "会议"]'
```

读取和写入时进行 JSON 序列化/反序列化。

### iOS Widget 数据共享

iOS Widget Extension 通过 App Group 共享目录直接访问 SQLite 数据库：

- **App Group ID**: `group.com.amberlist.amberList`
- **数据库路径**: `{AppGroupContainer}/amber_list.db`
- **访问方式**: SQLite3 C API 直接读写

详见 [iOS Home Widget 架构文档](../context/ios-home-widget-architecture.md)
