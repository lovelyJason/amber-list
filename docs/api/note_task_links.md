# 笔记-任务双向关联

## 概述

笔记与任务之间的双向关联功能，支持在笔记中链接任务、在任务中链接笔记，点击可跨页跳转，完成任务时提示回顾关联笔记。

## 数据库设计

### NoteTaskLinks 表（schema v14）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | TEXT (PK) | UUID 主键 |
| noteId | TEXT (FK → Notes.id) | 笔记 ID |
| taskId | TEXT (FK → Tasks.id) | 任务 ID |
| createdAt | DATETIME | 创建时间 |

**约束**：同一 `noteId + taskId` 组合不允许重复（代码层面防重）。

## 架构分层

```
┌─────────────────────────────────────────┐
│  UI 层                                   │
│  ├─ note_detail_panel.dart   (笔记详情)   │
│  ├─ task_detail_panel.dart   (任务详情)   │
│  ├─ embedded_task_card.dart  (任务卡片)   │
│  ├─ embedded_note_card.dart  (笔记卡片)   │
│  └─ appflowy_markdown_editor (斜线命令)   │
├─────────────────────────────────────────┤
│  Provider 层                             │
│  ├─ linkedTasksProvider(noteId)          │
│  ├─ linkedNotesProvider(taskId)          │
│  └─ noteTaskLinkRepositoryProvider       │
├─────────────────────────────────────────┤
│  Repository 层                           │
│  └─ NoteTaskLinkRepository               │
├─────────────────────────────────────────┤
│  数据库层                                 │
│  └─ NoteTaskLinks 表 + JOIN 查询          │
└─────────────────────────────────────────┘
```

## 入口方式

### 1. 底部工具栏按钮

笔记编辑器底部工具栏的"关联任务"按钮（`Icons.add_task_outlined`），点击弹出任务选择器，选择后创建关联并在编辑器末尾插入 `[任务标题](task:任务ID)` 链接。

### 2. 斜线命令 `/link`

在 AppFlowy 编辑器中输入 `/`，弹出斜线命令菜单，选择"关联任务"项。选择任务后在光标位置插入链接文本，同时创建数据库关联。

**实现**：使用 `customSlashCommand()` 替换默认的 `slashCommand`，在 `standardSelectionMenuItems` 基础上追加自定义菜单项。

### 3. 任务详情面板

任务详情的"关联笔记"区域点击"+"按钮，弹出笔记选择器，选择后创建关联。

## 关联数据流

```
创建关联:
  用户选择 → NoteTaskLinkRepository.linkNoteToTask()
    → 检查重复 → 插入 NoteTaskLinks 记录
    → Stream 自动推送更新到 UI

删除关联:
  用户点击 × → NoteTaskLinkRepository.unlinkNoteFromTask()
    → 删除记录 → Stream 自动推送更新

级联清理:
  笔记删除 → deleteAllLinksForNote(noteId)
  任务删除 → deleteAllLinksForTask(taskId)
```

## 跨页跳转

- **笔记 → 任务**：调用 `AppNavNotifier.navigateToTask(taskId)`，切换到今天视图并选中目标任务
- **任务 → 笔记**：调用 `AppNavNotifier.navigateToNote(noteId)`，切换到笔记页并通过 `targetNoteId` 自动选中

## 嵌入卡片

### EmbeddedTaskCard（笔记中的任务卡片）

显示内容：任务标题、完成状态复选框、截止日期、优先级标签
交互：点击跳转任务详情，点击 × 取消关联

### EmbeddedNoteCard（任务中的笔记卡片）

显示内容：笔记标题、内容预览（前 100 字符，去除 Markdown 标记）、更新时间
交互：点击跳转笔记详情，点击 × 取消关联

## 完成回顾提示

当用户完成一个有关联笔记的任务时：
- `toggleTaskComplete()` 返回关联笔记数量
- UI 层显示 SnackBar："该任务关联了 N 条笔记，是否查看？"
- 点击"查看"跳转到任务详情页面查看关联笔记

## 涉及文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `database.dart` | 修改 | NoteTaskLinks 表 + schema v14 |
| `note_task_link_repository.dart` | 新建 | 关联关系 CRUD |
| `note_task_link_provider.dart` | 新建 | Riverpod Provider |
| `note_detail_panel.dart` | 修改 | 工具栏按钮 + 关联任务卡片列表 |
| `task_detail_panel.dart` | 修改 | 关联笔记卡片列表 |
| `appflowy_markdown_editor.dart` | 修改 | 斜线命令 /link |
| `app_state.dart` | 修改 | navigateToNote/Task 导航方法 |
| `notes_page.dart` | 修改 | targetNoteId 消费 |
| `task_provider.dart` | 修改 | toggleTaskComplete 返回关联笔记数 |
| `task_item.dart` | 修改 | 完成回顾 SnackBar |
| `embedded_task_card.dart` | 新建 | 嵌入式任务卡片 |
| `embedded_note_card.dart` | 新建 | 嵌入式笔记卡片 |
