# 原生便签窗口架构文档

## 背景

由于 Flutter 的 `desktop_multi_window` 插件在 macOS 和 Windows 上存在多个已知 bug（参见 flutter/flutter#155685, #158450, #152299），导致便签窗口关闭后重新打开时应用崩溃。为了绕过这些问题，我们实现了原生便签窗口方案。

## 架构概述

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter 主应用                          │
│  ┌──────────────────┐    ┌──────────────────────────────┐  │
│  │  ListSidebar     │    │  NativeStickyNoteService     │  │
│  │  (打开便签入口)   │───▶│  (Platform Channel 客户端)    │  │
│  └──────────────────┘    └──────────────────────────────┘  │
│                                      │                      │
│                          MethodChannel: com.amberlist.sticky_note
│                                      │                      │
└──────────────────────────────────────┼──────────────────────┘
                                       │
        ┌──────────────────────────────┴──────────────────────────────┐
        │                                                              │
        ▼                                                              ▼
┌───────────────────────────┐                        ┌───────────────────────────┐
│     macOS (Swift/AppKit)  │                        │   Windows (C++/Win32)     │
│  ┌─────────────────────┐  │                        │  ┌─────────────────────┐  │
│  │ StickyNoteManager   │  │                        │  │ StickyNoteManager   │  │
│  │ (单例，管理所有窗口)  │  │                        │  │ (单例，管理所有窗口)  │  │
│  └──────────┬──────────┘  │                        │  └──────────┬──────────┘  │
│             │              │                        │             │              │
│  ┌──────────▼──────────┐  │                        │  ┌──────────▼──────────┐  │
│  │ StickyNoteWindow-   │  │                        │  │ StickyNoteWindow    │  │
│  │ Controller          │  │                        │  │ (Win32 HWND)        │  │
│  │ (NSWindow)          │  │                        │  │                     │  │
│  └──────────┬──────────┘  │                        │  └─────────────────────┘  │
│             │              │                        │                           │
│  ┌──────────▼──────────┐  │                        │                           │
│  │ StickyNoteContent-  │  │                        │                           │
│  │ View (NSView)       │  │                        │                           │
│  └─────────────────────┘  │                        │                           │
└───────────────────────────┘                        └───────────────────────────┘
```

## Platform Channel 接口定义

Channel 名称：`com.amberlist.sticky_note`

### Flutter → Native 方法

| 方法名 | 参数 | 返回值 | 说明 |
|--------|------|--------|------|
| `createStickyNote` | `{id, title, themeColor, active[], completed[]}` | `{success, windowId}` | 创建便签窗口 |
| `closeStickyNote` | `{id}` | `{success}` | 关闭指定便签 |
| `updateStickyNote` | `{id, active[], completed[]}` | `{success}` | 更新便签内容 |
| `focusStickyNote` | `{id}` | `{success}` | 聚焦便签窗口 |
| `isWindowOpen` | `{id}` | `{isOpen}` | 检查窗口是否打开 |

### Native → Flutter 方法

| 方法名 | 参数 | 说明 |
|--------|------|------|
| `onTaskToggled` | `{taskId, isCompleted}` | 任务状态变化通知 |
| `onStickyNoteClosed` | `{id}` | 窗口关闭通知 |

### 数据结构

```dart
// 任务项
{
  'id': String,        // 任务 ID
  'title': String,     // 任务标题
  'isCompleted': bool  // 是否完成
}

// 主题色（ARGB 十六进制字符串）
'0xFFFFF7D1'  // 黄色（默认）
'0xFFE1F5FE'  // 蓝色
'0xFFFFEBEE'  // 粉色
'0xFFE8F5E9'  // 绿色
```

## 文件结构

### Flutter 端

```
lib/
├── core/
│   └── services/
│       └── native_sticky_note_service.dart   # Platform Channel 服务
└── presentation/
    ├── providers/
    │   └── native_sticky_note_provider.dart  # Riverpod Provider
    └── widgets/
        └── list_sidebar.dart                  # 调用入口（已修改）
```

### macOS 端

```
macos/Runner/
├── StickyNoteManager.swift           # Platform Channel 处理 + 窗口管理
├── StickyNoteWindowController.swift  # NSWindowController 子类
├── StickyNoteContentView.swift       # 便签内容视图
└── MainFlutterWindow.swift           # 初始化 StickyNoteManager（已修改）
```

### Windows 端

```
windows/runner/
├── sticky_note_manager.h/.cpp   # Platform Channel 处理 + 窗口管理
├── sticky_note_window.h/.cpp    # Win32 窗口实现
├── flutter_window.cpp           # 初始化 StickyNoteManager（已修改）
├── main.cpp                     # 清理逻辑（已修改）
└── CMakeLists.txt               # 添加新文件（已修改）
```

## 实现细节

### macOS 实现

- 使用 `NSWindow` + `NSWindowController` 创建独立窗口
- `NSWindowDelegate` 监听窗口关闭事件
- 使用 SF Symbols 图标（macOS 11+）
- 支持窗口拖拽、置顶、主题色切换
- 任务列表使用 `NSStackView` + `NSScrollView`

### Windows 实现

- 使用 Win32 `CreateWindowEx` 创建窗口
- 自定义窗口类 `AMBER_STICKY_NOTE_WINDOW`
- 使用 GDI 绘制背景和文字
- 任务复选框使用 `BS_AUTOCHECKBOX` 样式
- 支持 DPI 感知

### Flutter 端

- `NativeStickyNoteService` 单例管理 Platform Channel
- `nativeStickyNoteProvider` 设置回调，处理 Native→Flutter 通信
- `_showStickyNoteWindow()` 优先使用原生实现，失败时 fallback 到 Flutter 多窗口

## 双向同步机制

### 便签窗口 → Flutter 主窗口

1. 用户在便签窗口勾选任务
2. 原生代码更新本地 UI
3. 原生代码调用 `onTaskToggled` 通知 Flutter
4. `nativeStickyNoteProvider` 收到回调
5. 调用 `taskProvider.toggleTaskComplete()` 更新数据库

### Flutter 主窗口 → 便签窗口

1. 用户在主窗口勾选任务
2. `taskProvider` 更新数据库
3. 检查便签窗口是否打开
4. 如果打开，调用 `updateStickyNote` 同步数据
5. 原生代码更新便签 UI

## Fallback 机制

当原生便签创建失败时（如 Platform Channel 未注册），会自动 fallback 到 `desktop_multi_window` 实现：

```dart
if (nativeService.isSupported) {
  final success = await nativeService.createStickyNote(...);
  if (success) return;
}
// Fallback 到 Flutter 多窗口
final window = await DesktopMultiWindow.createWindow(...);
```

## 已知限制

1. Windows 端的颜色选择器 UI 较简陋（使用 emoji 按钮）
2. 便签窗口不支持保存位置和大小
3. 主题色变化不会持久化

## 相关 Issue

- flutter/flutter#155685 - Windows 多窗口崩溃
- flutter/flutter#158450 - macOS 窗口关闭后进程残留
- flutter/flutter#152299 - 多窗口通信不稳定

## 更新日志

### 2025-12-31
- 初始实现原生便签窗口功能
- 支持 macOS (Swift/AppKit) 和 Windows (C++/Win32)
- 实现双向数据同步
- 添加 Fallback 机制
