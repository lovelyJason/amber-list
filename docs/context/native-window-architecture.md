# 原生窗口管理器架构文档

## 概述

通用原生窗口管理器是对 [原生便签窗口架构](./native-sticky-note-architecture.md) 的抽象升级。它提供了一个统一的框架，用于管理所有原生窗口（如 QuickAdd 闪念胶囊、StickyNote 便签等），支持未来扩展更多窗口类型。

## 设计目标

1. **统一接口**：所有原生窗口通过同一个 Platform Channel 通信
2. **可扩展性**：工厂模式支持快速添加新窗口类型
3. **类型安全**：协议/接口定义确保一致性
4. **双端一致**：macOS 和 Windows 实现相同的抽象

## 架构图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Flutter 层                                     │
│  ┌─────────────────────┐     ┌─────────────────────────────────────┐   │
│  │   QuickAddService   │     │       NativeWindowService           │   │
│  │   (业务逻辑层)       │────▶│   (Platform Channel 统一入口)       │   │
│  └─────────────────────┘     └─────────────────────────────────────┘   │
│                                           │                              │
│                     MethodChannel: com.amberlist.native_window          │
│                                           │                              │
└───────────────────────────────────────────┼──────────────────────────────┘
                                            │
         ┌──────────────────────────────────┴──────────────────────────────┐
         │                                                                  │
         ▼                                                                  ▼
┌────────────────────────────────┐                    ┌────────────────────────────────┐
│      macOS (Swift/AppKit)      │                    │      Windows (C++/Win32)       │
│  ┌──────────────────────────┐  │                    │  ┌──────────────────────────┐  │
│  │   NativeWindowManager    │  │                    │  │   NativeWindowManager    │  │
│  │   (单例，管理所有窗口)     │  │                    │  │   (单例，管理所有窗口)     │  │
│  │   - 窗口工厂注册          │  │                    │  │   - 窗口工厂注册          │  │
│  │   - Platform Channel     │  │                    │  │   - Platform Channel     │  │
│  └────────────┬─────────────┘  │                    │  └────────────┬─────────────┘  │
│               │                 │                    │               │                 │
│  ┌────────────▼─────────────┐  │                    │  ┌────────────▼─────────────┐  │
│  │  NativeWindowProtocol    │  │                    │  │   NativeWindowBase       │  │
│  │  (窗口抽象协议)           │  │                    │  │   (窗口抽象基类)          │  │
│  └────────────┬─────────────┘  │                    │  └────────────┬─────────────┘  │
│               │                 │                    │               │                 │
│    ┌──────────┴──────────┐     │                    │    ┌──────────┴──────────┐     │
│    ▼                     ▼     │                    │    ▼                     ▼     │
│ ┌────────────┐    ┌──────────┐ │                    │ ┌────────────┐    ┌──────────┐ │
│ │ QuickAdd   │    │ 未来窗口  │ │                    │ │ QuickAdd   │    │ 未来窗口  │ │
│ │ Window     │    │ ...      │ │                    │ │ Window     │    │ ...      │ │
│ └────────────┘    └──────────┘ │                    │ └────────────┘    └──────────┘ │
└────────────────────────────────┘                    └────────────────────────────────┘
```

## Platform Channel 接口

Channel 名称：`com.amberlist.native_window`

### Flutter → Native 方法

| 方法名 | 参数 | 返回值 | 说明 |
|--------|------|--------|------|
| `createOrShow` | `{windowType, windowId?, arguments?}` | `{success, windowId}` | 创建或显示窗口 |
| `hide` | `{windowType, windowId?}` | `{success}` | 隐藏窗口 |
| `destroy` | `{windowType, windowId?}` | `{success}` | 销毁窗口 |
| `sendMessage` | `{windowType, windowId?, method, arguments?}` | 任意 | 向窗口发送消息 |
| `isWindowOpen` | `{windowType, windowId?}` | `{isOpen}` | 检查窗口是否打开 |
| `getOpenWindows` | 无 | `[{windowType, windowId}]` | 获取所有打开的窗口 |

### Native → Flutter 回调

回调通过 `NativeWindowService.registerCallback()` 注册，按窗口类型分组：

| 回调名 | 参数 | 说明 |
|--------|------|------|
| `onQuickAddTaskCreated` | `{title, dueDate, windowType, windowId?}` | QuickAdd 任务创建 |
| `onQuickAddCancelled` | `{windowType, windowId?}` | QuickAdd 取消 |
| `onDatePickerRequested` | `{currentDate, windowType, windowId?}` | 请求显示日期选择器 |

## 文件结构

### Flutter 端

```
lib/core/services/
├── native_window/
│   └── native_window_service.dart    # Platform Channel 统一服务
│       - NativeWindowService         # 单例，管理所有原生窗口通信
│       - registerCallback()          # 注册窗口回调
│       - createOrShowWindow()        # 创建/显示窗口
│       - sendMessage()               # 向窗口发送消息
│
└── quick_add/
    └── quick_add_service.dart        # 闪念胶囊业务逻辑
        - QuickAddService             # 热键注册、窗口管理
        - onTaskCreated               # 任务创建回调
        - onDatePickerRequested       # 日期选择器回调
```

### macOS 端

```
macos/Runner/
├── NativeWindow/
│   ├── NativeWindowProtocol.swift    # 窗口抽象协议
│   │   - NativeWindowProtocol        # 定义窗口接口
│   │   - WindowType                  # 窗口类型定义
│   │
│   ├── NativeWindowManager.swift     # 窗口管理器
│   │   - shared                      # 单例
│   │   - setup(binaryMessenger)      # 初始化 Platform Channel
│   │   - registerFactory()           # 注册窗口工厂
│   │   - notifyFlutter()             # 回调 Flutter
│   │
│   └── QuickAddWindow.swift          # QuickAdd 窗口实现
│       - QuickAddWindow              # NativeWindowProtocol 实现
│       - QuickAddWindowController    # NSWindowController
│       - QuickAddContentView         # SwiftUI 内容视图
│
└── MainFlutterWindow.swift           # 注册 NativeWindowManager
```

### Windows 端

```
windows/runner/
├── native_window_manager.h/.cpp      # 窗口管理器
│   - NativeWindowManager             # 单例
│   - NativeWindowBase                # 窗口抽象基类
│   - WindowFactory                   # 工厂函数类型
│   - Setup()                         # 初始化 Platform Channel
│   - RegisterFactory()               # 注册窗口工厂
│   - NotifyFlutter()                 # 回调 Flutter
│
├── quick_add_window.h/.cpp           # QuickAdd 窗口实现
│   - QuickAddWindow                  # NativeWindowBase 子类
│   - CreateWindow()                  # 创建 Win32 窗口
│   - EditSubclassProc()              # 输入框子类化（拦截 Enter/ESC）
│
├── flutter_window.cpp                # 注册 NativeWindowManager
└── CMakeLists.txt                    # 添加新文件
```

## 窗口类型定义

当前支持的窗口类型：

| 类型 | windowType | 说明 |
|------|------------|------|
| 闪念胶囊 | `quick_add` | 全局热键唤起的快速任务输入窗口 |

### 添加新窗口类型

1. **定义窗口类型常量**
   - Flutter: `NativeWindowService` 中添加类型
   - macOS: 在工厂注册中添加
   - Windows: 在工厂注册中添加

2. **实现窗口类**
   - macOS: 实现 `NativeWindowProtocol`
   - Windows: 继承 `NativeWindowBase`

3. **注册工厂**
   ```swift
   // macOS
   NativeWindowManager.shared.registerFactory("new_type") { id, args in
       NewWindow(id: id, arguments: args)
   }
   ```
   ```cpp
   // Windows
   NativeWindowManager::GetInstance().RegisterFactory("new_type",
       [](const std::wstring& id, const flutter::EncodableMap* args) {
           return std::make_unique<NewWindow>(id, args);
       });
   ```

4. **创建 Flutter Service**
   - 封装业务逻辑
   - 注册回调

## QuickAdd 闪念胶囊功能

### 功能描述

全局热键唤起的快速任务输入窗口，类似 macOS Spotlight。

### 触发方式

- **双平台统一**: `Ctrl + Shift + A`

### UI 设计

```
┌────────────────────────────────────────────────────────────────┐
│  🪲  │  添加任务到 1月5日...                    │ 📅 │  ↵   │
└────────────────────────────────────────────────────────────────┘
 Logo     输入框（占位符显示日期）              日期  提交
```

- **窗口特性**：无边框、置顶、居中偏上（屏幕 1/4 处）
- **琥珀 Logo**：左侧六边形渐变色图标
- **输入框**：带日期占位符，支持 Enter 提交
- **日期按钮**：点击触发日期选择器回调
- **提交按钮**：点击或 Enter 提交任务

### 键盘快捷键

| 按键 | 功能 |
|------|------|
| `Enter` | 提交任务 |
| `ESC` | 取消并关闭窗口 |

### 数据流

```
1. 用户按 Cmd+Alt+A
       ↓
2. hotkey_manager 触发回调
       ↓
3. QuickAddService.showQuickAdd()
       ↓
4. NativeWindowService.createOrShowWindow("quick_add")
       ↓
5. Platform Channel → NativeWindowManager
       ↓
6. 创建/显示 QuickAddWindow
       ↓
7. 用户输入任务，按 Enter
       ↓
8. 原生代码调用 notifyFlutter("onQuickAddTaskCreated")
       ↓
9. NativeWindowService 触发回调
       ↓
10. QuickAddService.onTaskCreated 处理
       ↓
11. taskProvider.createTask() 保存到数据库
```

## 技术细节

### macOS 实现要点

- 使用 `NSPanel` + `nonactivatingPanel` 样式，实现类似 Spotlight 的行为
- `NSWindowController` 管理窗口生命周期
- 纯 AppKit 实现（NSView/NSTextField/NSTextView）
- `NSTextFieldDelegate` 拦截 Enter/ESC/Tab 键盘事件
- `weak` 引用避免循环引用

#### nonactivatingPanel 的特殊性

使用 `nonactivatingPanel` 是实现 Spotlight 类窗口的关键，但它有很多坑：

1. **事件分发**：工具栏按钮默认不响应点击，需要重写 `mouseDown(with:)` 手动分发
2. **窗口关闭检测**：
   - `windowDidResignKey` 在某些情况下不会触发
   - 需要同时使用 `NSEvent.addGlobalMonitorForEvents`（监听应用外部）和 `NSEvent.addLocalMonitorForEvents`（监听应用内部）
3. **NSPopover 兼容**：打开 NSPopover（如日期选择器）时，需要阻止窗口关闭逻辑

### Windows 实现要点

- `WS_POPUP | WS_EX_TOPMOST | WS_EX_TOOLWINDOW` 创建无边框置顶窗口
- `DwmSetWindowAttribute` 设置 Windows 11 圆角
- 输入框子类化（Subclassing）拦截键盘事件
- `localtime_s` 替代 `localtime` 确保线程安全
- GDI+ 自定义绘制背景和图标

#### Windows QuickAdd 窗口技术架构

**技术栈选型**：Win32 Native Controls + GDI+ + Owner-Draw

从最初的 Direct2D 方案改为 Win32 原生控件方案，主要考虑：
1. **IME 兼容性**：原生 EDIT 控件完美支持中文输入法
2. **系统一致性**：Win32 控件与系统风格统一
3. **稳定性**：避免 Direct2D 渲染和输入框结合的复杂性

**窗口层次结构**：

```
┌─────────────────────────────────────────────────────────────┐
│ QuickAddWindow (WS_POPUP + WS_EX_TOPMOST)                   │
│ ├── OnPaint() - GDI+ 绘制背景、Logo、分隔线                   │
│ │                                                           │
│ ├── Compact Mode (紧凑模式)                                  │
│ │   ├── edit_control_ (EDIT) - 任务标题输入框                │
│ │   └── submit_button_ (BS_OWNERDRAW) - 提交按钮             │
│ │                                                           │
│ └── Expanded Mode (展开模式)                                 │
│     ├── title_label_ (STATIC) - 标题显示                     │
│     ├── content_edit_ (EDIT + ES_MULTILINE) - 详情输入框     │
│     ├── Toolbar Buttons (BS_OWNERDRAW):                     │
│     │   ├── list_button_ - 列表/笔记切换                     │
│     │   ├── tag_button_ - 标签选择（支持多选）               │
│     │   ├── date_button_ - 日期选择                         │
│     │   └── priority_button_ - 优先级选择                    │
│     ├── list_selector_button_ - 收集箱/清单选择              │
│     ├── cancel_button_ - 取消                               │
│     └── confirm_button_ - 确认                              │
└─────────────────────────────────────────────────────────────┘
```

**核心功能实现**：

| 功能 | 实现方式 | 关键代码 |
|------|----------|----------|
| DPI 缩放 | `GetDpiForWindow()` 获取缩放比例 | `dpi_scale_ = GetDpiForWindow(hwnd) / 96.0f` |
| 圆角窗口 | DWM API | `DwmSetWindowAttribute(DWMWA_WINDOW_CORNER_PREFERENCE)` |
| 琥珀 Logo | GDI+ 加载 PNG 资源 | `LoadLogoFromResource()` + `Gdiplus::Bitmap` |
| 按钮绘制 | Owner-Draw | `WM_DRAWITEM` + `DrawRoundedButton()` |
| 图标绘制 | GDI+ 向量绘制 | `Gdiplus::Graphics` 画线、椭圆、多边形 |
| 动态宽度 | 文本测量 | `GetTextExtentPoint32W()` + `SetWindowPos()` |
| 输入拦截 | Edit 子类化 | `SetWindowSubclass()` + `EditSubclassProc()` |

**Owner-Draw 按钮图标类型**：

```cpp
// iconType 定义
// 0 = 无图标
// 1 = 回车箭头 (提交按钮)
// 2 = 三横线 (列表模式)
// 3 = 圆形标签 (标签按钮)
// 4 = 日历 (日期按钮)
// 5 = 旗帜 (优先级按钮)
// 6 = 文档 (笔记模式)
// 7 = 收件箱 (收集箱按钮)
```

**高亮颜色系统**：

```cpp
// highlightColor 定义（匹配 macOS 设计）
// 0 = 灰色 (默认未选中)
// 1 = 琥珀色 (标签/日期选中)
// 2 = 绿色 (低优先级)
// 3 = 橙色 (中优先级)
// 4 = 红色 (高优先级)

// 颜色值
kAmberColor = RGB(245, 166, 35)   // #F5A623
kGreenColor = RGB(76, 175, 80)    // 低优先级
kOrangeColor = RGB(255, 152, 0)   // 中优先级
kRedColor = RGB(244, 67, 54)      // 高优先级
```

**工具栏按钮动态布局**：

```cpp
void QuickAddWindow::RelayoutToolbarButtons() {
    // 从右到左排列：优先级 → 日期 → 标签 → 列表
    int x = windowWidth - margin;
    x -= CalculateButtonWidth(priority_button_);
    SetWindowPos(priority_button_, nullptr, x, btnY, ...);
    x -= spacing + CalculateButtonWidth(date_button_);
    SetWindowPos(date_button_, nullptr, x, btnY, ...);
    // ...
}

int QuickAddWindow::CalculateButtonWidth(HWND button) {
    // 获取按钮文本
    // 使用 GetTextExtentPoint32W 测量宽度
    // 返回：文本宽度 + 图标宽度 + padding
}
```

**资源文件配置**：

```rc
// Runner.rc
IDB_AMBER_LOGO  RCDATA  "resources\\mosquito_amber.png"

// resource.h
#define IDB_AMBER_LOGO  102
```

**CMakeLists.txt 依赖**：

```cmake
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")   # DWM 圆角
target_link_libraries(${BINARY_NAME} PRIVATE "gdiplus.lib")  # GDI+ 绘图
target_link_libraries(${BINARY_NAME} PRIVATE "msimg32.lib")  # Alpha 混合
```

### 热键注册

使用 `hotkey_manager` Flutter 插件：

```dart
final hotKey = HotKey(
  key: PhysicalKeyboardKey.keyA,
  modifiers: [
    HotKeyModifier.control,
    HotKeyModifier.shift,
  ],
  scope: HotKeyScope.system,
);

await hotKeyManager.register(hotKey, callback: (hotKey) {
  showQuickAdd();
});
```

## 踩坑记录与解决方案

### 1. NSTextView 文字不显示

**问题**：展开模式下的 NSTextView 输入框，用户输入的文字看不到，但数据确实存在（能保存成功）。

**原因**：手动创建 `NSScrollView` + `NSTextView` 组合时，NSTextView 的 frame、textContainer、layoutManager 之间的关联没有正确设置，导致文字渲染区域为 0x0。

**解决方案**：使用 Apple 官方工厂方法 `NSTextView.scrollableTextView()`：

```swift
// ❌ 错误方式
contentTextView = NSScrollView()
contentTextField = NSTextView()
contentTextView.documentView = contentTextField

// ✅ 正确方式
contentTextView = NSTextView.scrollableTextView()
contentTextField = contentTextView.documentView as! NSTextView
```

### 2. NSPopover 打开时窗口意外关闭

**问题**：点击日期选择器（NSPopover）内的日期时，整个 QuickAdd 窗口会关闭。

**原因**：
1. NSPopover 打开时会触发 `windowDidResignKey`
2. 全局/本地鼠标监听器检测到点击不在 QuickAdd 窗口内

**解决方案**：
1. 维护 `activePopover` 变量跟踪当前打开的 Popover
2. 在 `windowDidResignKey` 和鼠标监听器中检查是否有 Popover 打开
3. 检测点击是否在 Popover 窗口内

```swift
private var activePopover: NSPopover?

func hasActivePopover() -> Bool {
    return activePopover != nil
}

// 在 windowDidResignKey 中
if contentView.hasActivePopover() {
    return  // 不关闭窗口
}

// 在鼠标监听器中
if let popoverWindow = popover.contentViewController?.view.window {
    isInsidePopover = popoverWindow.frame.contains(screenLocation)
}
```

### 3. NSPopover 按钮不响应点击

**问题**：日期选择器 Popover 中的「确定」「取消」按钮点击没有反应。

**原因**：`objc_setAssociatedObject` 使用字符串字面量作为 key，但每次创建的字符串实例指针地址不同，导致 `objc_getAssociatedObject` 取不到值。

**解决方案**：使用静态变量指针作为 key：

```swift
// ❌ 错误方式
objc_setAssociatedObject(button, "datePicker", datePicker, .OBJC_ASSOCIATION_RETAIN)
objc_getAssociatedObject(button, "datePicker")  // 返回 nil！

// ✅ 正确方式
private static var datePickerKey: UInt8 = 0
objc_setAssociatedObject(button, &Self.datePickerKey, datePicker, .OBJC_ASSOCIATION_RETAIN)
objc_getAssociatedObject(button, &Self.datePickerKey)  // 正确获取
```

### 4. 点击窗口外部不关闭

**问题**：QuickAdd 窗口显示后，点击 Flutter 主窗口或其他区域，QuickAdd 不会关闭。

**原因**：
- `NSEvent.addGlobalMonitorForEvents` 只监听**其他应用**的事件
- `NSEvent.addLocalMonitorForEvents` 监听当前应用事件，但 `nonactivatingPanel` 模式下行为特殊
- 点击 Flutter 主窗口的事件可能不会被 QuickAdd 的监听器捕获

**解决方案**：在本地监听器中检查 `event.window` 是否是 QuickAdd 窗口：

```swift
localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { event in
    let clickedWindow = event.window
    let isClickOnQuickAdd = clickedWindow === self.window

    if !isClickOnQuickAdd && !isInsidePopover {
        self.handleMouseClickOutside()
    }
    return event
}
```

### 5. nonactivatingPanel 中按钮不响应

**问题**：展开模式下的工具栏按钮（列表、标签、日期、优先级）点击无反应。

**原因**：`nonactivatingPanel` 样式的 NSPanel 不会自动将事件传递给非 key view 的控件。

**解决方案**：重写 `mouseDown(with:)` 手动检测点击位置并触发对应的按钮动作：

```swift
override func mouseDown(with event: NSEvent) {
    let location = convert(event.locationInWindow, from: nil)

    if let button = dateButton,
       button.frame.contains(toolbarView.convert(location, from: self)) {
        dateButtonTapped()
        return
    }
    // ... 其他按钮

    super.mouseDown(with: event)
}
```

## 与 StickyNote 的关系

`NativeWindowManager` 是新的统一架构，而 `StickyNoteManager` 是之前的独立实现。两者目前共存：

| 对比项 | StickyNoteManager | NativeWindowManager |
|--------|-------------------|---------------------|
| Channel | `com.amberlist.sticky_note` | `com.amberlist.native_window` |
| 用途 | 仅便签窗口 | 通用窗口框架 |
| 扩展性 | 固定功能 | 工厂模式可扩展 |
| 状态 | 生产使用中 | 新增，用于 QuickAdd |

**未来计划**：将 StickyNote 迁移到 NativeWindowManager 架构，实现统一管理。

## 依赖

### Flutter 端

```yaml
dependencies:
  hotkey_manager: ^0.2.3  # 全局热键
```

### macOS 端

- AppKit
- SwiftUI (macOS 10.15+)
- Carbon (HotKey 相关)

### Windows 端

- Win32 API
- dwmapi.lib (DWM 圆角)

## 原生 Splash 屏幕

> 详细文档已迁移至 [native-splash-screen.md](./native-splash-screen.md)

原生 Splash 屏幕解决 Flutter 应用启动时的黑屏问题，在 Flutter 引擎初始化期间显示琥珀主题的启动画面。

**主要特性**：
- 琥珀背景 + Logo 呼吸动画 + 进度条
- 支持 fadeOut / crossDissolve 两种过渡效果
- Platform Channel: `com.amberlist.splash`
- 双端实现：macOS (NSView) / Windows (Win32 + GDI+)

## 更新日志

### 2026-01-06

- **新增原生 Splash 屏幕功能**：
  - 解决 Flutter 应用启动黑屏问题
  - macOS: SplashView (NSView) 实现，呼吸动画 + 进度条
  - Windows: SplashView (Win32/GDI+) 实现，分层窗口 + 双缓冲
  - Flutter: SplashService 控制隐藏和配置
  - Platform Channel: `com.amberlist.splash`
  - 支持 fadeOut/crossDissolve 两种过渡效果
  - 可配置过渡时长和进度条显示

- **Windows QuickAdd 窗口重大升级**：
  - 从 Direct2D 方案改为 Win32 Native Controls + GDI+ + Owner-Draw
  - 完善 DPI 缩放支持，所有尺寸按 `dpi_scale_` 缩放
  - 实现工具栏按钮动态宽度（`CalculateButtonWidth()` + `RelayoutToolbarButtons()`）
  - 添加高亮颜色系统：标签/日期选中显示琥珀色，优先级按等级显示绿/橙/红
  - 添加收集箱图标（iconType=7）
  - 修复标签多选显示问题，现在显示完整标签列表（如"阅读, 重要, 设计"）
  - 修复日期选中后按钮宽度不足问题
  - 添加 Logo 加载失败时的 fallback 星星图标
  - 添加 MSVC `/utf-8` 编译选项修复中文警告

### 2026-01-05

- 修复展开模式下 NSTextView 文字不显示问题（使用 `NSTextView.scrollableTextView()`）
- 修复 NSPopover 日期选择器导致窗口意外关闭问题
- 修复 NSPopover 确定/取消按钮不响应问题（`objc_setAssociatedObject` key 必须用静态指针）
- 修复点击窗口外部不关闭问题
- 添加「踩坑记录与解决方案」章节

### 2025-01-05

- 创建通用原生窗口管理器架构
- 实现 QuickAdd 闪念胶囊功能
- 支持 macOS (Swift/AppKit) 和 Windows (C++/Win32)
- 全局热键 `Ctrl + Shift + A`（双平台统一）
- 修复 Windows 键盘事件处理（Edit 控件子类化）
- 修复 Windows `localtime` 线程安全问题
