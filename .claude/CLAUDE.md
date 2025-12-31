# 琥珀清单开发规范

本文档记录琥珀清单项目的开发约定和技术规范,请严格遵守。

---

## 🖼️ macOS 窗口顶部间距规范

### 问题背景
macOS 应用窗口顶部有**红黄绿三个控制按钮**(关闭/最小化/最大化),高度约 22px。Flutter macOS 应用的内容区域从窗口最顶部开始渲染,如果界面元素距离顶部太近,会与系统控制按钮产生视觉冲突。

### 强制规范

**所有顶部固定元素(Logo/头像/AppBar 等)必须距离窗口顶部至少 36px**

#### 实现方式

```dart
// ✅ 正确 - 窄侧边栏顶部间距
Column(
  children: [
    const SizedBox(height: AmberDimens.spacingXl + AmberDimens.spacingXs), // 32 + 4 = 36px
    _buildLogo(),
    // ...
  ],
)

// ✅ 正确 - AppBar 顶部留白(使用 toolbarHeight 调整)
AppBar(
  toolbarHeight: 56 + 36, // 标准高度 + 顶部留白
  title: const Text('设置'),
  // ...
)

// ❌ 错误 - 间距不足
const SizedBox(height: AmberDimens.spacingMd), // 仅 16px,会被窗口控制按钮遮挡
```

#### 推荐常量

| 元素类型 | 推荐间距 | 计算方式 | 说明 |
|---------|---------|---------|------|
| 窄侧边栏 Logo | 36px | `spacingXl + spacingXs` | 32 + 4 |
| AppBar(有返回键) | 36px | `toolbarHeight: 56 + 36` | 标准高度 + 留白 |
| 全屏页面顶部 | 40px | `spacingXl + spacingMd` | 32 + 8 (更宽松) |

---

## 📐 设计规范参考

项目完整设计规范详见: [`docs/design/UI_DESIGN_SPEC.md`](../docs/design/UI_DESIGN_SPEC.md)

核心配色:
- 主色(琥珀金): `#F5A623`
- 主色深: `#D4891C`
- 主色浅: `#FFF3E0`

核心间距常量(已定义在 `AmberDimens`):
- `spacingXs`: 4px
- `spacingSm`: 8px
- `spacingMd`: 16px
- `spacingLg`: 24px
- `spacingXl`: 32px

---

## 🎨 图标设计规范

### 核心原则
1. **优先使用 `_outlined` 系列图标** - 线框风格,简洁现代,符合琥珀清单的极简调性
2. **图标语义要明确** - 一眼能看出功能,避免抽象图标
3. **保持统一风格** - 同一区域的图标使用相同的粗细和风格

### 窄侧边栏导航图标

| 功能 | 图标 | 设计理念 |
|------|------|---------|
| 收集箱 | `Icons.inventory_2_outlined` | 封存物品的箱子,强调"收集待处理"的概念 |
| 今天 | `Icons.wb_sunny_outlined` | 空心太阳,醒目清爽,象征"今日焦点" |
| 最近7天 | `Icons.event_repeat_outlined` | 循环事件图标,强调"一周重复"的时间概念 |
| 日历 | `Icons.calendar_today_outlined` | 日历单页,简洁直观 |
| 笔记 | `Icons.description_outlined` | 文档图标,比传统笔记图标更现代 |
| 设置 | `Icons.settings_outlined` | 齿轮图标,通用设置入口 |

### 替换历史(已废弃的图标)
- ❌ `inbox_rounded` → ✅ `inventory_2_outlined` (收集箱)
- ❌ `today_rounded` → ✅ `wb_sunny_outlined` (今天)
- ❌ `date_range_rounded` → ✅ `event_repeat_outlined` (最近7天)
- ❌ `calendar_month_rounded` → ✅ `calendar_today_outlined` (日历)
- ❌ `note_alt_outlined` → ✅ `description_outlined` (笔记)

---

## 🎯 待办事项

### Logo 优化
- [ ] 设计六边形琥珀 Logo SVG(含昆虫/树叶剪影)
- [ ] 将 SVG 放入 `assets/icons/amber_logo.svg`
- [ ] 更新 `pubspec.yaml` 的 assets 配置
- [ ] 替换 `NarrowSidebar._buildLogo()` 中的临时图标 `Icons.pest_control_outlined`

### 窗口间距审查
- [x] 窄侧边栏顶部间距 (已修复 36px)
- [x] 设置页面 AppBar 顶部间距 (已修复 36px)
- [ ] 日历页面顶部间距
- [ ] 笔记页面顶部间距
- [ ] 所有弹窗/对话框位置校验

### 图标优化
- [x] 窄侧边栏导航图标替换(已全部更换为 outlined 系列)

---

## 🛠️ 开发规范

### 代码风格
- 严格遵循 `analysis_options.yaml` 的 Lint 规则
- 使用 Flutter 最新稳定 API(避免过时方法,如 `withOpacity` → `withValues`)
- 优先使用 `AmberDimens` / `AmberColors` 常量,不要硬编码数值
- 使用到的第三方库或者任何功能，需要同时兼容mac和windows系统
- 开发的代码，包括widget，utils等所有功能都要有完备的中文注释，比如某块界面是干嘛的，设计哲学等
- 涉及到大的变更，要看看docs中对应的文档要不要更新，重要的功能和使用方法必须更新；小的变更，比如ui调整， 图标更换，代码优化等不需要更新
- 改动尽可能缩小范围， 比如我让你改输入框样式，你别修改输入框附近的图标等与本地需求不相干的内容

### Git 提交规范
```
feat: 添加新功能
fix: 修复 Bug
refactor: 重构代码
docs: 更新文档
style: 代码格式调整(不影响功能)
chore: 构建/配置相关
```

---

## 📝 更新日志

### 2025-12-28
- 创建本规范文档
- 修复窄侧边栏顶部间距问题(16px → 36px)
- 修复设置页面 AppBar 顶部间距(默认 → 92px 含 36px 留白)
- 优化 Logo 设计(添加琥珀渐变色 + 昆虫剪影临时图标)
- 升级过时 API: `withOpacity` → `withValues`
- 更新窄侧边栏导航图标(全部替换为 outlined 系列,提升辨识度)
  - 收集箱: `inbox_rounded` → `inventory_2_outlined`
  - 今天: `today_rounded` → `wb_sunny_outlined`
  - 最近7天: `date_range_rounded` → `event_repeat_outlined`
  - 日历: `calendar_month_rounded` → `calendar_today_outlined`
  - 笔记: `note_alt_outlined` → `description_outlined`
