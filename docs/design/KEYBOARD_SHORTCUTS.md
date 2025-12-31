# 琥珀清单 - 快捷键规划

## 全局快捷键

| 快捷键 | macOS | Windows | 功能 |
|--------|-------|---------|------|
| `Cmd/Ctrl + N` | ✓ | ✓ | 新建任务 |
| `Cmd/Ctrl + Shift + N` | ✓ | ✓ | 新建笔记 |
| `Cmd/Ctrl + F` | ✓ | ✓ | 全局搜索 |
| `Cmd/Ctrl + ,` | ✓ | ✓ | 打开设置 |
| `Cmd/Ctrl + Q` | ✓ | - | 退出应用（macOS） |
| `Alt + F4` | - | ✓ | 退出应用（Windows） |

## 视图切换

| 快捷键 | 功能 |
|--------|------|
| `Cmd/Ctrl + 1` | 切换到收集箱 |
| `Cmd/Ctrl + 2` | 切换到今天 |
| `Cmd/Ctrl + 3` | 切换到最近7天 |
| `Cmd/Ctrl + 4` | 切换到日历视图 |
| `Cmd/Ctrl + 5` | 切换到笔记视图 |

## 任务操作

| 快捷键 | 功能 |
|--------|------|
| `Enter` | 编辑选中任务 |
| `Space` | 切换任务完成状态 |
| `Delete` / `Backspace` | 删除选中任务 |
| `Cmd/Ctrl + D` | 复制任务 |
| `Cmd/Ctrl + Shift + D` | 设置截止日期为今天 |
| `↑` / `↓` | 上下移动选择 |
| `Cmd/Ctrl + ↑` | 移动任务到上方 |
| `Cmd/Ctrl + ↓` | 移动任务到下方 |

## 优先级设置

| 快捷键 | 功能 |
|--------|------|
| `!` + `1` | 设置高优先级 |
| `!` + `2` | 设置中优先级 |
| `!` + `3` | 设置低优先级 |
| `!` + `0` | 取消优先级 |

## 日历视图

| 快捷键 | 功能 |
|--------|------|
| `←` / `→` | 上/下一天 |
| `Cmd/Ctrl + ←` | 上一个月 |
| `Cmd/Ctrl + →` | 下一个月 |
| `T` | 回到今天 |
| `M` | 切换到月视图 |
| `W` | 切换到周视图 |

## 笔记视图

| 快捷键 | 功能 |
|--------|------|
| `Cmd/Ctrl + Shift + P` | 置顶/取消置顶笔记 |
| `Cmd/Ctrl + G` | 切换网格/列表视图 |

## 编辑操作（通用）

| 快捷键 | 功能 |
|--------|------|
| `Cmd/Ctrl + Z` | 撤销 |
| `Cmd/Ctrl + Shift + Z` | 重做 |
| `Cmd/Ctrl + A` | 全选 |
| `Cmd/Ctrl + C` | 复制 |
| `Cmd/Ctrl + V` | 粘贴 |
| `Cmd/Ctrl + X` | 剪切 |

## 侧边栏

| 快捷键 | 功能 |
|--------|------|
| `Cmd/Ctrl + B` | 切换侧边栏显示/隐藏 |
| `Cmd/Ctrl + Shift + B` | 切换详情面板显示/隐藏 |

## 实现状态

| 状态 | 说明 |
|------|------|
| ✅ | 已实现 |
| 🚧 | 开发中 |
| 📋 | 计划中 |

### 当前实现状态

- 📋 全部快捷键待实现（MVP版本暂未实现快捷键）

## 实现方案

### Flutter 快捷键实现

```dart
// 使用 Shortcuts + Actions
Shortcuts(
  shortcuts: {
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyN):
        const CreateTaskIntent(),
  },
  child: Actions(
    actions: {
      CreateTaskIntent: CallbackAction<CreateTaskIntent>(
        onInvoke: (intent) => _createTask(),
      ),
    },
    child: Focus(
      autofocus: true,
      child: // ...
    ),
  ),
);
```

### 快捷键提示

在菜单项和按钮上显示快捷键提示：

```dart
Tooltip(
  message: '新建任务 (⌘N)',
  child: IconButton(...),
)
```

## 自定义快捷键（未来功能）

计划支持用户自定义快捷键：

1. 在设置页面添加"快捷键"配置项
2. 允许用户修改默认快捷键
3. 支持导入/导出快捷键配置
4. 检测快捷键冲突
