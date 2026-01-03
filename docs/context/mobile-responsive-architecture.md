# 移动端响应式适配架构

本文档记录琥珀清单从桌面端（macOS/Windows）适配到移动端（Android/iOS）的完整技术方案、设计思路和最佳实践。

---

## 一、核心设计原则

### 1.1 桌面优先，移动兼容

项目最初是为 macOS/Windows 桌面端设计的，移动端适配遵循以下原则：

- **桌面端代码100%保留**：所有原有功能、UI、交互保持不变
- **渐进式适配**：使用条件渲染，而非重构
- **最小改动原则**：只在必要时修改，不过度设计

### 1.2 响应式断点

```dart
class ResponsiveHelper {
  /// 移动端断点：600px
  /// - 小于600px：移动端布局（单栏 + 底部导航）
  /// - 大于等于600px：桌面端布局（多栏 + 侧边栏）
  static const double mobileBreakpoint = 600.0;
}
```

**为什么选择600px？**
- Material Design 推荐的 compact/medium 分界线
- 大多数手机竖屏宽度在 360-428px 之间
- 小平板横屏约 600-800px，可作为桌面端使用

---

## 二、技术架构

### 2.1 响应式工具类

文件位置：`lib/core/utils/responsive_helper.dart`

```dart
class ResponsiveHelper {
  static const double mobileBreakpoint = 600.0;

  /// 判断当前是否为移动端布局
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// 判断是否为桌面操作系统（macOS/Windows/Linux）
  static bool isDesktopOS() {
    if (kIsWeb) return false;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  /// 根据平台返回不同值
  static T valueWhen<T>(BuildContext context, {
    required T mobile,
    required T desktop,
  }) {
    return isMobile(context) ? mobile : desktop;
  }
}
```

### 2.2 LayoutBuilder vs MediaQuery

**推荐使用 LayoutBuilder：**

```dart
// 推荐：基于约束的响应式
return LayoutBuilder(
  builder: (context, constraints) {
    final isMobile = constraints.maxWidth < ResponsiveHelper.mobileBreakpoint;
    return isMobile ? _buildMobileLayout() : _buildDesktopLayout();
  },
);

// 不推荐：直接使用 MediaQuery
// 问题：会导致不必要的重建，且无法正确处理嵌套布局
final isMobile = MediaQuery.of(context).size.width < 600;
```

**LayoutBuilder 优势：**
1. 基于父组件约束，而非全局屏幕尺寸
2. 更精确的重建控制
3. 支持嵌套响应式布局

---

## 三、导航适配方案

### 3.1 桌面端导航结构

```
┌─────────────────────────────────────────────────┐
│ NarrowSidebar │ ListSidebar │ Content │ Detail  │
│   (72px)      │  (220px)    │ (flex)  │ (320px) │
└─────────────────────────────────────────────────┘
```

### 3.2 移动端导航结构

```
┌─────────────────────────────┐
│          AppBar             │
├─────────────────────────────┤
│                             │
│         Content             │
│                             │
├─────────────────────────────┤
│      BottomNavigationBar    │
└─────────────────────────────┘
   ↑
  Drawer (ListSidebar)
```

### 3.3 导航组件映射

| 桌面端组件 | 移动端组件 | 说明 |
|-----------|-----------|------|
| NarrowSidebar | BottomNavigationBar | 5个核心入口保持一致 |
| ListSidebar | Drawer | 抽屉式清单列表 |
| TaskDetailPanel | BottomSheet | 可拖动的底部面板 |

### 3.4 新增组件

文件位置：`lib/presentation/widgets/adaptive/`

| 文件 | 功能 |
|------|------|
| `bottom_nav_bar.dart` | 移动端底部导航栏（5个入口） |
| `drawer_list_sidebar.dart` | 抽屉式清单列表容器 |
| `detail_bottom_sheet.dart` | 任务详情底部面板 |
| `adaptive_scaffold.dart` | 自适应脚手架（可选） |

---

## 四、页面适配详解

### 4.1 HomePage 适配

**核心改动：**

```dart
@override
Widget build(BuildContext context) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final isMobile = constraints.maxWidth < ResponsiveHelper.mobileBreakpoint;

      if (isMobile) {
        return _buildMobileLayout(context, navState, tasks);
      } else {
        return _buildDesktopLayout(context, navState, tasks);
      }
    },
  );
}
```

**移动端布局特点：**
- AppBar 替代顶部拖动区域
- Drawer 替代左侧 ListSidebar
- BottomNavigationBar 替代 NarrowSidebar
- 隐藏 TaskDetailPanel（使用 BottomSheet）

### 4.2 CalendarPage 适配

**桌面端：** 左侧边栏(260px) + 日历主体

**移动端：**
- 隐藏左侧边栏
- AppBar 显示月份标题
- SegmentedButton 切换视图模式（月/周/日）
- 添加 BottomNavigationBar

### 4.3 NotesPage 适配

**桌面端：** 笔记网格 + 详情面板(320px)

**移动端：**
- 列表/详情分离式导航
- 点击笔记进入全屏编辑
- 编辑页使用独立 AppBar + 返回按钮

### 4.4 PomodoroPage 适配

**桌面端：** 左侧番茄钟(flex:2) + 右侧任务队列(flex:1)

**移动端：**
- 垂直布局：上方番茄钟(flex:3) + 下方任务队列(flex:2)
- 简化 UI：缩小计时器尺寸、精简队列列表

### 4.5 SettingsPage 适配

**桌面端：** 左侧导航栏 + 右侧内容

**移动端：**
- 列表式导航替代侧边栏
- 点击进入详情页
- 详情页使用返回按钮

---

## 五、ListSidebar 抽屉适配

### 5.1 核心改动

```dart
class ListSidebar extends ConsumerStatefulWidget {
  /// 是否嵌入抽屉中（移动端模式）
  final bool inDrawer;

  const ListSidebar({super.key, this.inDrawer = false});
}
```

### 5.2 适配逻辑

```dart
Container(
  // 抽屉模式下自适应宽度，桌面端固定宽度
  width: widget.inDrawer ? null : AmberDimens.listSidebarWidth,
  child: Column(
    children: [
      // 抽屉模式下隐藏头部（DrawerListSidebar 已有头部）
      if (!widget.inDrawer) ...[
        _buildHeader(context, taskLists),
        const Divider(height: 1),
      ],
      // ... 其余内容
    ],
  ),
)
```

---

## 六、常见问题与解决方案

### 6.1 Overflow 问题

**问题：** TaskItem 标签在移动端窄屏幕上溢出

**解决：** 使用 Flexible 包裹

```dart
// 修复前
Row(
  children: task.tags.map((tag) => TagChip(tag)).toList(),
)

// 修复后
Flexible(
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: task.tags.take(3).map((tag) {
      return Flexible(child: TagChip(tag));
    }).toList(),
  ),
)
```

### 6.2 平台特定功能

**问题：** window_manager 在移动端不可用

**解决：** 使用平台判断

```dart
// 仅在桌面端初始化多窗口服务
if (ResponsiveHelper.isDesktopOS()) {
  ref.watch(nativeStickyNoteProvider);
}
```

### 6.3 DragToMoveArea 在移动端

**问题：** 桌面端的窗口拖动区域在移动端无意义

**解决：** 保持原样，DragToMoveArea 在移动端会自动退化为普通容器

---

## 七、测试检查清单

### 7.1 功能测试

- [ ] 桌面端所有功能正常（无回归）
- [ ] 移动端底部导航切换正常
- [ ] 抽屉打开/关闭正常
- [ ] 清单/标签选择正常
- [ ] 任务创建/编辑/删除正常
- [ ] 日历视图切换正常
- [ ] 笔记编辑/保存正常
- [ ] 番茄钟计时正常

### 7.2 UI 测试

- [ ] 无 Overflow 警告
- [ ] 文字不被截断
- [ ] 图标大小合适
- [ ] 点击区域足够大（最小44px）
- [ ] 滚动流畅

### 7.3 兼容性测试

- [ ] Android 10+ 正常
- [ ] iOS 12+ 正常
- [ ] macOS 保持不变
- [ ] Windows 保持不变

---

## 八、文件变更清单

### 新增文件

| 文件路径 | 描述 |
|---------|------|
| `lib/core/utils/responsive_helper.dart` | 响应式工具类 |
| `lib/presentation/widgets/adaptive/bottom_nav_bar.dart` | 移动端底部导航 |
| `lib/presentation/widgets/adaptive/drawer_list_sidebar.dart` | 抽屉式清单列表 |
| `lib/presentation/widgets/adaptive/detail_bottom_sheet.dart` | 任务详情面板 |
| `lib/presentation/widgets/adaptive/adaptive_scaffold.dart` | 自适应脚手架 |

### 修改文件

| 文件路径 | 改动描述 |
|---------|---------|
| `lib/presentation/pages/home_page.dart` | 添加 LayoutBuilder 响应式布局 |
| `lib/presentation/pages/calendar/calendar_page.dart` | 移动端隐藏侧边栏 |
| `lib/presentation/pages/notes/notes_page.dart` | 移动端列表/详情分离 |
| `lib/presentation/pages/pomodoro/pomodoro_page.dart` | 移动端垂直布局 |
| `lib/presentation/pages/settings/settings_page.dart` | 移动端列表导航 |
| `lib/presentation/widgets/list_sidebar/list_sidebar.dart` | 添加 inDrawer 参数 |
| `lib/presentation/widgets/task_item.dart` | 修复标签 Overflow |

---

## 九、后续优化建议

1. **手势优化**：添加左滑删除、右滑完成等手势
2. **动画优化**：页面切换添加 Hero 动画
3. **离线支持**：移动端更需要离线功能
4. **推送通知**：任务提醒推送
5. **Widget 小组件**：iOS/Android 桌面小组件
6. **深色模式**：移动端系统级深色模式适配

---

## 更新日志

### 2026-01-01
- 完成移动端响应式适配
- 新增 ResponsiveHelper 工具类
- 适配 HomePage、CalendarPage、NotesPage、PomodoroPage、SettingsPage
- 修复 TaskItem 标签 Overflow 问题
- 创建本文档
