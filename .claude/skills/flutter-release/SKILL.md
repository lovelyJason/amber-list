---
name: flutter-release
description: Flutter 应用完整版本发布工作流。包含两大阶段：Phase 1 生成更新日志草稿（draft release notes），Phase 2 执行完整发布（版本号升级 → 文件更新 → Git 提交/标签 → 本地 macOS 打包 → GitHub Release 发布）。当用户说"发布新版本"、"升级版本"、"更新版本号"、"准备发布"、"/flutter-release"时触发此 skill。支持 major/minor/patch 三种版本升级类型。
---

# Flutter Release - 完整发布工作流

琥珀清单（Amber List）版本发布的完整自动化流程，分为两大阶段执行。

---

## Phase 1: Draft Release Notes（生成更新日志草稿）

> 此阶段负责收集变更、生成中文更新说明草稿，供用户审核后再进入正式发布。

### Step 1.1: 获取 Git 变更记录

```bash
# 获取上个版本标签到当前 HEAD 的所有提交（忽略 merge commits）
git log $(git describe --tags --abbrev=0 2>/dev/null || echo HEAD~20)..HEAD --no-merges --pretty=format:"- %s"
```

### Step 1.2: 智能归纳更新说明

根据 git log 输出 + 当前对话上下文 + `docs/context/*.md` 文档，智能归纳中文更新说明。

**过滤规则：**
- 忽略 `chore`、`wip`、`bump version`、`merge` 等琐碎提交
- 合并相关的小改动为一条
- 使用用户能理解的语言，避免技术术语

**分类规则：**
- `新增`：全新功能、新增页面/组件
- `优化`：已有功能的改进、性能优化、UI 调整
- `修复`：Bug 修复、问题解决

**撰写原则：**
- 每条不超过 30 字
- 按重要性排序（新增 > 优化 > 修复）
- major 版本需额外添加"重大更新"分类

### Step 1.3: 写入 RELEASE_DRAFT.md

将生成的更新说明写入项目根目录 `RELEASE_DRAFT.md` 临时文件：

```markdown
## v{预测的下一个版本号}

### 重大更新（仅 major 版本需要）
- {重大功能描述}

### 新增
- {新功能描述}

### 优化
- {改进描述}

### 修复
- {Bug 修复描述}
```

### Step 1.4: 展示草稿并等待用户审核

将 `RELEASE_DRAFT.md` 内容展示给用户，等待用户：
- 确认内容无误 → 进入 Phase 2
- 提出修改意见 → 修改后重新展示
- 补充遗漏内容 → 更新草稿

**重要：必须等用户明确确认后才能进入 Phase 2！**

---

## Phase 2: Release（完整发布流程）

> 此阶段执行正式发布：版本号升级 → 文件更新 → Git 操作 → 本地打包 → GitHub Release。

### Step 2.1: 确定版本类型

询问用户本次发布的版本类型（如果 Phase 1 中未确定）：

| 类型 | 说明 | 版本变化示例 |
|------|------|-------------|
| **patch** (默认) | Bug 修复、小优化 | 1.1.1 → 1.1.2 |
| **minor** | 新功能、较大改进 | 1.1.1 → 1.2.0 |
| **major** | 重大更新、破坏性变更 | 1.1.1 → 2.0.0 |

### Step 2.2: 升级版本号

```bash
# 默认 patch 升级
dart run scripts/bump_version.dart

# minor 升级
dart run scripts/bump_version.dart minor

# major 升级
dart run scripts/bump_version.dart major
```

执行后从 `pubspec.yaml` 读取新版本号和构建号，后续步骤都使用这个值。

### Step 2.3: 更新 RELEASE_DRAFT.md 版本号

将 `RELEASE_DRAFT.md` 中的预测版本号替换为实际版本号：

```bash
# macOS sed
sed -i '' "1s/^## v.*/## v{实际版本号} ($(date +%Y-%m-%d))/" RELEASE_DRAFT.md
```

### Step 2.4: 更新 assets/CHANGELOG.md

将 RELEASE_DRAFT.md 的内容转换为 CHANGELOG 格式，插入 `assets/CHANGELOG.md` 文件顶部（`# 更新日志` 标题之后）。

**CHANGELOG 条目格式：**

```markdown
## v{版本号} ({YYYY-MM-DD})

- 新增：{新功能描述}
- 优化：{改进描述}
- 修复：{Bug 修复描述}
```

**注意：**
- 保持现有格式，不要修改历史版本记录
- major 版本额外添加 `### 重大更新` 子标题

### Step 2.5: 更新 update.json

更新项目根目录的 `update.json` 文件（用于应用内更新检测）：

```json
{
  "latest_version": "{新版本号}",
  "latest_build_number": "{新构建号}",
  "minimum_version": "{保持不变或按需调整}",
  "release_notes": "{CHANGELOG 中的更新内容，单行格式，用 | 分隔分类}",
  "download_urls": {
    "macos": "https://cdn.qdovo.com/hupo/releases/download/v{版本号}/AmberList-{版本号}-macos.zip",
    "windows": "https://cdn.qdovo.com/hupo/releases/download/v{版本号}/AmberList-{版本号}-windows.zip"
  },
  "release_date": "{ISO 8601 格式，如 2026-01-09T19:00:00Z}",
  "update_enabled": true
}
```

**字段说明：**
- `latest_version`: 从 pubspec.yaml 读取的新版本号（如 `2.1.0`）
- `latest_build_number`: 从 pubspec.yaml 读取的构建号（`+` 后面的数字）
- `release_notes`: 将 CHANGELOG 条目转为单行，用 `| ` 分隔分类
- `download_urls`: 替换版本号部分，保持 URL 模板不变
- `release_date`: 当前时间的 ISO 8601 格式

**注意：** 此文件被 .gitignore 忽略，需手动上传到 CDN 服务器。

### Step 2.6: 更新 index.html 版本号

更新项目根目录 `index.html` 中的版本常量：

```javascript
// 搜索 APP_VERSION 并替换版本号（约在第 986 行附近）
const APP_VERSION = '{新版本号}'
```

### Step 2.7: Git 提交、标签和推送

```bash
# 1. 暂存所有变更（排除 RELEASE_DRAFT.md 临时文件）
git add .
git reset HEAD RELEASE_DRAFT.md 2>/dev/null || true

# 2. 提交（使用 HEREDOC 格式化 commit message）
git commit -m "$(cat <<'EOF'
release: v{版本号} {版本描述}

### 重大更新（仅 major 版本）
- {重大功能1}

### 新功能
- {新功能描述}

### 优化
- {优化描述}

### 修复
- {修复描述}

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"

# 3. 推送到远程
git push

# 4. 创建标签
git tag -a v{版本号} -m "v{版本号} {简短描述}"

# 5. 推送标签到远程（这会触发 GitHub Actions CI 构建 Windows 产物）
git push origin v{版本号}
```

**Commit Message 规范：**
- `release:` 前缀表示版本发布
- 标题简洁概括本次发布
- 正文按分类列出主要改动
- 包含 Co-Authored-By 署名

**标签命名：**
- 格式: `v{major}.{minor}.{patch}`
- 示例: `v2.0.0`, `v1.2.3`

### Step 2.8: 本地构建 macOS 包

```bash
# 1. 清理旧构建
flutter clean

# 2. 获取依赖
flutter pub get

# 3. 构建 macOS Release
flutter build macos --release

# 4. 进入构建产物目录
cd build/macos/Build/Products/Release

# 5. 打包为 zip（注意 app 名称为 "amber_list.app"）
# 先确认实际的 .app 文件名
ls *.app

# 6. 创建 zip 包并重命名
zip -r "AmberList-{版本号}-macos.zip" "amber_list.app"

# 7. 回到项目根目录
cd -
```

**产物路径：** `build/macos/Build/Products/Release/AmberList-{版本号}-macos.zip`

**注意：** 打包前先用 `ls *.app` 确认实际的 .app 文件名，可能是 `amber_list.app` 或其他名称。

### Step 2.9: 发布 GitHub Release

使用 `gh` CLI 创建 GitHub Release，上传本地 macOS 产物：

```bash
# 创建 Release 并上传 macOS 包
gh release create "v{版本号}" \
  "build/macos/Build/Products/Release/AmberList-{版本号}-macos.zip" \
  --title "v{版本号}" \
  --notes-file RELEASE_DRAFT.md
```

**GitHub Release 产物清单：**

| 产物 | 文件名格式 | 来源 |
|------|-----------|------|
| macOS 压缩包 | `AmberList-{版本号}-macos.zip` | 本地构建上传 |
| Windows 安装程序 | `AmberList_Setup_{版本号}.exe` | CI 自动上传 |
| Windows 免安装包 | `AmberList-{版本号}-windows-raw.zip` | CI 自动上传 |

> **Windows 产物说明：** push tag 后会自动触发 `.github/workflows/build_windows.yml`，CI 使用 `softprops/action-gh-release@v2` 自动将 Windows 安装程序和免安装包上传到同一个 GitHub Release，无需手动操作。

### Step 2.10: 清理临时文件

```bash
# 删除临时的 RELEASE_DRAFT.md
rm -f RELEASE_DRAFT.md
```

---

## 完整流程概览

```
Phase 1: Draft Release Notes
  ├── 1.1 获取 Git 变更记录
  ├── 1.2 智能归纳更新说明
  ├── 1.3 写入 RELEASE_DRAFT.md
  └── 1.4 用户审核确认
          │
          ▼
Phase 2: Release
  ├── 2.1 确定版本类型 (patch/minor/major)
  ├── 2.2 dart run scripts/bump_version.dart
  ├── 2.3 更新 RELEASE_DRAFT.md 版本号
  ├── 2.4 更新 assets/CHANGELOG.md
  ├── 2.5 更新 update.json
  ├── 2.6 更新 index.html APP_VERSION
  ├── 2.7 Git commit → push → tag → push tag
  │        └── (自动触发 CI 构建 Windows 产物并上传到 Release)
  ├── 2.8 本地构建 macOS 包 (flutter build macos)
  ├── 2.9 gh release create (上传 macOS 包)
  └── 2.10 清理临时文件 RELEASE_DRAFT.md
          │
          ▼
Post-Release (手动):
  └── 上传 update.json 到 CDN 服务器
```

---

## 示例对话

**用户**: 发布新版本

**Claude**:

**Phase 1:**
1. 执行 `git log` 获取提交记录
2. 归纳更新内容，生成 `RELEASE_DRAFT.md`
3. 展示草稿，等待用户确认

**用户**: 内容确认，patch 版本

**Claude**:

**Phase 2:**
1. 运行 `dart run scripts/bump_version.dart` 升级版本号
2. 更新 RELEASE_DRAFT.md 中的版本号
3. 更新 `assets/CHANGELOG.md`
4. 更新 `update.json`
5. 更新 `index.html` 中的 `APP_VERSION`
6. `git add` → `git commit` → `git push` → `git tag` → `git push tag`
7. `flutter clean && flutter build macos --release`
8. 打包 zip 并重命名为 `AmberList-{版本号}-macos.zip`
9. `gh release create` 上传 macOS 包 + 更新说明
10. 清理 `RELEASE_DRAFT.md`
11. 提醒用户：CI 正在自动构建并上传 Windows 产物到 Release

---

## 注意事项

- 确保在项目根目录执行所有命令
- 如果 git 没有 tag，会获取最近 20 条提交
- push tag 会自动触发 GitHub Actions 构建 Windows 产物（`.github/workflows/build_windows.yml`）
- `update.json` 被 .gitignore 忽略，发布后需手动上传到 CDN 服务器
- macOS 打包前先 `flutter clean` 确保干净构建
- 如果遇到网络问题（git push / gh release），先执行 `export all_proxy=http://127.0.0.1:7897`
- `RELEASE_DRAFT.md` 是临时文件，不要提交到 git，发布完成后删除
- Windows Inno Setup 安装程序的版本号由 CI 自动从 pubspec.yaml 提取替换
