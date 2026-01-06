# 原生 Splash 屏幕

> 本文档描述琥珀清单的原生启动画面实现。窗口管理相关的通用架构请参考 [native-window-architecture.md](./native-window-architecture.md)。

## 概述

原生 Splash 屏幕解决 Flutter 应用启动时的黑屏问题。在 Flutter 引擎初始化期间显示琥珀主题的启动画面，包含 Logo 呼吸动画和进度条。

**适用平台**：macOS、Windows（移动端不受影响）

## 设计目标

1. **消除黑屏**：在 Flutter 首帧渲染前显示品牌画面
2. **平滑过渡**：支持淡出/交叉溶解两种过渡效果
3. **视觉反馈**：呼吸动画 + 进度条提示加载中
4. **双端一致**：macOS 和 Windows 实现相同的视觉效果

## 架构图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Flutter 层                                     │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                       SplashService                               │   │
│  │   - hideSplash()           // 隐藏 Splash                         │   │
│  │   - configure()            // 配置过渡效果                         │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                           │                              │
│                     MethodChannel: com.amberlist.splash                  │
│                                           │                              │
└───────────────────────────────────────────┼──────────────────────────────┘
                                            │
         ┌──────────────────────────────────┴──────────────────────────────┐
         │                                                                  │
         ▼                                                                  ▼
┌────────────────────────────────────┐          ┌────────────────────────────────┐
│      macOS (Swift/AppKit)          │          │      Windows (C++/Win32/GDI+)  │
│  ┌──────────────────────────────┐  │          │  ┌──────────────────────────┐  │
│  │        SplashView            │  │          │  │        SplashView        │  │
│  │   (NSView 子类)               │  │          │  │   (Win32 + GDI+ 渲染)     │  │
│  │   - 琥珀背景 #FFF8E1          │  │          │  │   - 分层窗口 WS_EX_LAYERED │  │
│  │   - Logo 呼吸动画             │  │          │  │   - 双缓冲防闪烁           │  │
│  │   - 进度条                    │  │          │  │   - Timer 驱动动画         │  │
│  │   - 淡出过渡                  │  │          │  │   - Alpha 渐变淡出         │  │
│  └──────────────────────────────┘  │          │  └──────────────────────────┘  │
│                                    │          │                                │
│  MainFlutterWindow.swift           │          │  flutter_window.cpp            │
│   - setupSplashView()              │          │   - SetupSplashView()          │
│   - setupSplashChannel()           │          │   - SetupSplashChannel()       │
│   - hideSplash()                   │          │   - HideSplash()               │
└────────────────────────────────────┘          └────────────────────────────────┘
```

## Platform Channel 接口

Channel 名称：`com.amberlist.splash`

| 方法名 | 参数 | 说明 |
|--------|------|------|
| `hideSplash` | 无 | 触发 Splash 淡出动画并销毁 |
| `configureSplash` | `{transitionType, transitionDuration, showProgressBar}` | 配置 Splash 选项 |

## 文件结构

### Flutter 端

```
lib/core/services/
└── splash_service.dart           # Splash 控制服务
    - SplashService               # 静态类
    - hideSplash()                # 隐藏 Splash
    - configure()                 # 配置选项
    - SplashTransitionType        # 过渡类型枚举
```

### macOS 端

```
macos/Runner/
├── SplashView.swift              # Splash 视图实现
│   - SplashView                  # NSView 子类
│   - transitionType              # 过渡类型（静态变量）
│   - transitionDuration          # 过渡时长
│   - showProgressBar             # 是否显示进度条
│   - startAnimation()            # 开始呼吸+进度动画
│   - hide(completion:)           # 淡出并回调
│
└── MainFlutterWindow.swift       # 集成 Splash
    - splashView                  # Splash 视图实例
    - setupSplashView()           # 创建并添加到窗口
    - setupSplashChannel()        # 注册 Platform Channel
    - hideSplash()                # 响应 Flutter 调用
```

### Windows 端

```
windows/runner/
├── splash_view.h                 # Splash 视图头文件
│   - SplashTransitionType        # 过渡类型枚举
│   - SplashView                  # 窗口类
│
├── splash_view.cpp               # Splash 视图实现
│   - Create()                    # 创建子窗口
│   - StartAnimation()            # 启动 Timer 动画
│   - Hide()                      # 淡出并回调
│   - OnPaint()                   # GDI+ 双缓冲绘制
│   - DrawBackground()            # 绘制琥珀背景
│   - DrawLogo()                  # 绘制呼吸 Logo
│   - DrawProgressBar()           # 绘制圆角进度条
│
├── flutter_window.h              # 添加 splash_view_ 成员
└── flutter_window.cpp            # 集成 Splash
    - SetupSplashView()           # 创建 Splash
    - SetupSplashChannel()        # 注册 Platform Channel
    - HideSplash()                # 响应 Flutter 调用
```

## 视觉设计

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                    琥珀背景 #FFF8E1                          │
│                                                             │
│                                                             │
│                    ┌─────────────┐                          │
│                    │             │                          │
│                    │  🪲 Logo    │  ← 呼吸动画 0.95x~1.05x   │
│                    │             │                          │
│                    └─────────────┘                          │
│                                                             │
│                    ╭───────────────╮                        │
│                    │███████░░░░░░░░│ ← 进度条（可选）        │
│                    ╰───────────────╯                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 颜色方案

| 元素 | 颜色 | 说明 |
|------|------|------|
| 背景色 | `#FFF8E1` | 琥珀浅色 |
| 进度条轨道 | `#F5E0B2` | 琥珀更浅 |
| 进度条填充 | `#F5A623` | 琥珀主色 |

### 动画参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 呼吸动画缩放 | 0.95x ~ 1.05x | Logo 缩放范围 |
| 动画帧率 | ~60fps | 16ms 间隔 |
| 进度条初始 | 0% → ~80% | 渐进加载 |
| 进度条完成 | ~80% → 100% | 隐藏时快速完成 |
| 淡出时长 | 0.3s（默认） | 可配置 |

## 使用方式

```dart
// 在 app.dart 的 initState 中
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // 首帧渲染后隐藏 Splash
    if (Platform.isMacOS || Platform.isWindows) {
      SplashService.hideSplash();
    }
  });
}

// 可选：配置过渡效果（在隐藏前调用）
await SplashService.configure(
  transitionType: SplashTransitionType.crossDissolve,
  transitionDuration: 0.5,
  showProgressBar: true,
);
```

## 技术细节

### macOS 实现要点

- `NSView` 子类覆盖在 Flutter 视图之上
- `NSTimer` 驱动呼吸动画（16ms 间隔，约 60fps）
- `NSAnimationContext` 实现淡出过渡
- 从 Flutter assets 加载 `mosquito_amber.png`

### Windows 实现要点

- `WS_CHILD | WS_EX_LAYERED` 创建分层子窗口
- `SetLayeredWindowAttributes` 控制整体透明度
- GDI+ 双缓冲绘制防止闪烁
- `SetTimer` 驱动动画（16ms 间隔）
- `Gdiplus::GraphicsPath` 绘制圆角进度条
- 从 `data\flutter_assets\assets\images\` 加载 Logo

## 过渡类型对比

| 类型 | 效果 | 适用场景 |
|------|------|----------|
| `fadeOut` | Splash 单独淡出，Flutter 视图立即可见 | 快速启动，干净利落 |
| `crossDissolve` | Splash 淡出同时 Flutter 视图淡入 | 平滑过渡，更柔和 |

## 已知问题

### Windows 端 Splash 不消失（调试中）

**现象**：Splash 显示正常，但 Flutter 调用 `hideSplash()` 后不消失。

**排查进度**：
1. ✅ Platform Channel 注册（channel 作为成员变量保持存活）
2. ✅ Z-order 问题（Splash 在 Flutter view 设置后创建）
3. 🔍 调试中：添加了 `OutputDebugStringW` 日志追踪

**临时方案**：当前 `Hide()` 方法跳过淡出动画，直接隐藏窗口以验证 Channel 是否正常工作。

## 更新日志

### 2026-01-06

- 创建原生 Splash 屏幕功能
- macOS: SplashView (NSView) 实现，呼吸动画 + 进度条
- Windows: SplashView (Win32/GDI+) 实现，分层窗口 + 双缓冲
- Flutter: SplashService 控制隐藏和配置
- Platform Channel: `com.amberlist.splash`
- 支持 fadeOut/crossDissolve 两种过渡效果
- 可配置过渡时长和进度条显示
