---
name: flutter-release
description: Flutter 应用版本发布助手。用于升级 pubspec.yaml 版本号并自动生成 CHANGELOG.md 内容。当用户说"发布新版本"、"升级版本"、"更新版本号"、"准备发布"、"/flutter-release"时触发此 skill。支持 major/minor/patch 三种版本升级类型。
---

# Flutter Release

Flutter 应用版本发布工作流，自动完成版本号升级和更新日志生成。

## 工作流程

### Step 1: 确定版本类型

询问用户本次发布的版本类型：

| 类型 | 说明 | 版本变化示例 |
|------|------|-------------|
| **patch** (默认) | Bug 修复、小优化 | 1.1.1 → 1.1.2 |
| **minor** | 新功能、较大改进 | 1.1.1 → 1.2.0 |
| **major** | 重大更新、破坏性变更 | 1.1.1 → 2.0.0 |

### Step 2: 升级版本号

在项目根目录运行版本升级脚本：

```bash
# 默认 patch 升级
dart run scripts/bump_version.dart

# minor 升级
dart run scripts/bump_version.dart minor

# major 升级
dart run scripts/bump_version.dart major
```

### Step 3: 收集更新内容

从以下来源收集本版本的改动：

1. **Git 提交日志** (必须)
   ```bash
   # 获取上个版本到现在的所有提交
   git log --oneline $(git describe --tags --abbrev=0 2>/dev/null || echo HEAD~20)..HEAD
   ```

2. **对话上下文** (如有)
   - 回顾当前对话中讨论的功能改动
   - 提取用户提到的新增/修复/优化内容

3. **docs/context 文档** (可选)
   - 如果涉及重大架构改动，查阅相关文档获取准确描述
   - 路径: `docs/context/*.md`

### Step 4: 生成 CHANGELOG 条目

按以下格式生成更新日志条目：

```markdown
## v{版本号} ({YYYY-MM-DD})

- 新增：{新功能描述}
- 优化：{改进描述}
- 修复：{Bug 修复描述}
```

**分类规则：**
- `新增`：全新功能、新增页面/组件
- `优化`：已有功能的改进、性能优化、UI 调整
- `修复`：Bug 修复、问题解决

**撰写原则：**
- 使用用户能理解的语言，避免技术术语
- 每条不超过 30 字
- 合并相关的小改动为一条
- 按重要性排序（新增 > 优化 > 修复）

### Step 5: 更新 CHANGELOG.md

将新条目插入 `assets/CHANGELOG.md` 文件顶部（`# 更新日志` 标题之后）。

**注意：** 保持现有格式，不要修改历史版本记录。

### Step 6: 更新 update.json

更新项目根目录的 `update.json` 文件（用于应用内更新检测）：

```json
{
  "latest_version": "{新版本号}",
  "latest_build_number": "{新构建号}",
  "minimum_version": "{保持不变或按需调整}",
  "release_notes": "{CHANGELOG 中的更新内容，单行格式}",
  "download_urls": {
    "macos": "https://cdn.qdovo.com/hupo/releases/download/v{版本号}/AmberList-{版本号}-macos.zip",
    "windows": "https://cdn.qdovo.com/hupo/releases/download/v{版本号}/AmberList-{版本号}-windows.zip"
  },
  "release_date": "{ISO 8601 格式，如 2026-01-09T19:00:00Z}",
  "update_enabled": true
}
```

**字段说明：**
- `latest_version`: 从 pubspec.yaml 读取的新版本号（如 `1.1.2`）
- `latest_build_number`: 从 pubspec.yaml 读取的构建号（`+` 后面的数字）
- `release_notes`: 将 CHANGELOG 条目转为单行，用 `- ` 分隔
- `download_urls`: 替换版本号部分，保持 URL 模板不变
- `release_date`: 当前时间的 ISO 8601 格式

**注意：** 此文件被 .gitignore 忽略，需手动上传到 CDN 服务器。

### Step 7: 更新 index.html 版本号

更新项目根目录 `index.html` 中的版本常量：

```javascript
// 找到这行并替换版本号
const APP_VERSION = '{新版本号}'
```

**位置：** 约在第 986 行附近，搜索 `APP_VERSION` 即可定位。

## 示例对话

**用户**: 发布新版本

**Claude**:
1. 确认版本类型（默认 patch）
2. 运行 `dart run scripts/bump_version.dart`
3. 执行 `git log` 获取提交记录
4. 生成 CHANGELOG 条目
5. 更新 `assets/CHANGELOG.md`
6. 更新 `update.json`（版本号、构建号、更新说明、下载链接、发布日期）
7. 更新 `index.html` 中的 `APP_VERSION`
8. 执行 `git add .` 暂存所有变更
9. 执行 `git commit` 提交版本发布
10. 执行 `git push` 推送到远程
11. 执行 `git tag` 创建版本标签
12. 执行 `git push origin v{版本号}` 推送标签

### Step 8: Git 提交和推送

完成所有文件更新后，执行 Git 操作：

```bash
# 1. 暂存所有变更
git add .

# 2. 提交（使用 HEREDOC 格式化 commit message）
git commit -m "$(cat <<'EOF'
release: v{版本号} {版本描述}

### 重大更新（仅 major 版本）
- {重大功能1}
- {重大功能2}

### 新功能
- {新功能描述}

### 优化
- {优化描述}

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"

# 3. 推送到远程
git push

# 4. 创建标签
git tag -a v{版本号} -m "v{版本号} {简短描述}"

# 5. 推送标签到远程
git push origin v{版本号}
```

**Commit Message 规范：**
- `release:` 前缀表示版本发布
- 标题简洁概括本次发布
- 正文按分类列出主要改动
- 包含 Claude Code 署名

**标签命名：**
- 格式: `v{major}.{minor}.{patch}`
- 示例: `v2.0.0`, `v1.2.3`

## 注意事项

- 确保在项目根目录执行
- 升级后记得提交 `pubspec.yaml`、`assets/CHANGELOG.md`、`update.json`、`index.html`
- 如果 git 没有 tag，会获取最近 20 条提交
- 推送标签后，记得在 GitHub Releases 页面创建对应的 Release（可选）
- 构建完应用后上传到 CDN 对应路径