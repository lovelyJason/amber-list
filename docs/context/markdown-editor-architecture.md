# Markdown 所见即所得编辑器架构

## 概述

笔记模块使用自研的 Markdown 所见即所得编辑器，基于原生 `TextField` 实现，通过 `TextEditingController.buildTextSpan` 实现语法高亮和格式化渲染。

## 核心文件

```
lib/presentation/pages/notes/widgets/markdown_editor/
├── markdown_editor_controller.dart  # 控制器，核心逻辑
├── markdown_wysiwyg_editor.dart     # 编辑器 Widget
├── editor_toolbar.dart              # 底部工具栏
├── heading_indicator.dart           # 左侧标题级别指示器 (H1, H2...)
├── line_plus_menu.dart              # 空行加号菜单
├── slash_command_menu.dart          # 斜线 `/` 命令菜单
├── checkbox_indicator.dart          # 复选框指示器
└── link_picker_dialog.dart          # 链接选择对话框
```

## MarkdownEditorController

继承 `TextEditingController`，核心功能：

### 1. 光标位置追踪

```dart
LineInfo? _currentLineInfo;

// 每次光标移动时更新当前行信息
void _updateCurrentLineInfo() {
  _currentLineInfo = LineInfo(
    lineNumber: lineNumber,
    lineStart: lineStart,
    lineEnd: lineEnd,
    lineText: lineText,
    headingLevel: _detectHeadingLevel(lineText),
    isListItem: _detectListItem(lineText),
    isCheckbox: _detectCheckbox(lineText),
    isQuote: lineText.trimLeft().startsWith('>'),
    isCodeBlock: lineText.trimLeft().startsWith('```'),
  );
}
```

### 2. LineInfo 类

存储当前行的所有信息，包括渲染参数：

```dart
class LineInfo {
  final int lineNumber;      // 行号
  final int lineStart;       // 行起始位置
  final int lineEnd;         // 行结束位置
  final String lineText;     // 行文本
  final int headingLevel;    // 标题级别 (0=非标题, 1-6=H1-H6)
  final bool isListItem;     // 是否列表项
  final bool isCheckbox;     // 是否复选框
  final bool isQuote;        // 是否引用
  final bool isCodeBlock;    // 是否代码块

  // 渲染参数 getter
  double get fontSize;                  // 当前行字体大小
  double get lineHeight;                // 当前行行高 (fontSize * 1.5)
  double get cursorHeight;              // 光标高度 (固定 18px)
  double get indicatorVerticalOffset;   // 指示器垂直居中偏移量
}
```

### 3. 格式化方法

```dart
void toggleBold();           // 切换粗体 **text**
void toggleItalic();         // 切换斜体 *text*
void toggleStrikethrough();  // 切换删除线 ~~text~~
void toggleUnderline();      // 切换下划线 ++text++
void insertLink();           // 插入链接 [text](url)
void setHeading(int level);  // 设置标题级别
void insertQuote();          // 插入引用
void insertCheckbox();       // 插入复选框
```

### 4. buildTextSpan 渲染

重写 `buildTextSpan` 方法，实现 Markdown 语法的可视化渲染：

- **标题**：隐藏 `# ` 前缀，放大字号
- **引用**：`> ` 显示为琥珀色细竖线 `▏`
- **复选框**：`- [ ]` 显示为 Material Design 图标
- **粗体**：隐藏 `**`，文字加粗
- **斜体**：隐藏 `*`，文字倾斜
- **链接**：蓝色显示，Cmd+点击可跳转

## 标题字号规范

字号差距缩小，视觉更统一：

| 级别 | 字号 | 行高 |
|-----|-----|-----|
| H1 | 20px | 30px |
| H2 | 18px | 27px |
| H3 | 16px | 24px |
| H4 | 15px | 22.5px |
| H5 | 14.5px | 21.75px |
| H6 | 14px | 21px |
| 正文 | 14px | 21px |

## 光标高度规范

**光标高度固定 18px**，不随标题级别变化。

理由：
- 动态光标高度会导致视觉跳动
- 统一高度更简洁稳定

## 左侧指示器对齐

使用 `LineInfo.indicatorVerticalOffset` 计算垂直居中偏移：

```dart
// 计算指示器位置
final verticalOffset = lineInfo?.indicatorVerticalOffset ?? 0.0;
final topPosition = textFieldPaddingTop + cursorY + verticalOffset - scrollOffset;

// 放置指示器
Positioned(
  left: 2,
  top: topPosition,
  child: HeadingIndicator(...),
)
```

## 引用样式实现

引用行 `> text` 的渲染方式：

```dart
// 用琥珀色细竖线字符替代 `>`
TextSpan(text: '▏', style: barStyle),  // 字号 20px
TextSpan(text: ' ', style: baseStyle),  // 空格保持间距
..._parseInlineFormatting(content, quoteStyle),
```

- `▏` 是 Unicode 左侧 1/8 块字符，最细的竖线
- 字号设为 20px 让竖线更高
- 引用内容用斜体灰色显示

## 快捷键支持

| 快捷键 | 功能 |
|-------|------|
| Cmd+B | 粗体 |
| Cmd+I | 斜体 |
| Cmd+K | 插入链接 |
| Cmd+U | 下划线 |
| Cmd+Shift+S | 删除线 |

## 斜线命令菜单

输入 `/` 触发命令菜单，支持快速插入：
- 标题 (H1-H3)
- 引用
- 复选框
- 无序列表
- 有序列表
- 代码块
- 分割线

## 注意事项

1. **标题检测**：必须是 `# ` (井号+空格) 才识别为标题，单独的 `#` 不触发
2. **引用行隐藏加号菜单**：引用行不显示左侧加号菜单
3. **WidgetSpan 影响光标**：在文本流中使用 WidgetSpan 会影响光标位置计算，需谨慎
4. **字符替换显示**：用 Unicode 字符替换 Markdown 语法时，字符数必须对应，否则光标位置会错乱
