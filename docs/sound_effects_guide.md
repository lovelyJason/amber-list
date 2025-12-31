# 音效系统实施指南 (Sound Effects Implementation Guide)

本文档记录了为应用添加音效反馈的完整流程，包括素材获取、代码封装及组件集成。

## 1. 素材获取 (Asset Sourcing)

为了避免版权问题并获取高质量素材，我们采用**GitHub 开源仓库搜索**的策略。

### 1.1 搜索策略
我们主要通过 Browser Tool 或 Google Search 查找包含 `.mp3` 文件的开源 UI 主题或音效库。

**常用搜索关键词:**
*   `site:github.com "ui sounds" mp3`
*   `site:raw.githubusercontent.com "success.mp3"`
*   `github "trash.mp3" OR "delete.mp3"`

**推荐仓库:**
*   **rse/soundfx**: 一个非常全面的音效库。
    *   URL: `https://github.com/rse/soundfx/tree/master/soundfx.d`
*   **vinceliuice/WhiteSur-gtk-theme**: 包含一套优雅的系统音效。
*   **modmii/modmii.github.io**: 包含基础 UI 音效。

### 1.2 素材下载
确定素材后，通过 `curl` 命令直接下载 `raw` 文件到项目目录。

**此次使用的素材:**
1.  **Sync Success (同步成功)**: `bling1.mp3`
    ```bash
    curl -L -o assets/audio/success.mp3 https://raw.githubusercontent.com/rse/soundfx/master/soundfx.d/bling1.mp3
    ```
2.  **Delete/Trash (删除)**: `throw1.mp3`
    ```bash
    curl -L -o assets/audio/trash.mp3 https://raw.githubusercontent.com/rse/soundfx/master/soundfx.d/throw1.mp3
    ```
3.  **Task Complete (完成任务)**: `chime1.mp3`
    ```bash
    curl -L -o assets/audio/completion.mp3 https://raw.githubusercontent.com/rse/soundfx/master/soundfx.d/chime1.mp3
    ```

**目录结构:**
```
assets/
  ├── audio/
  │   ├── completion.mp3
  │   ├── success.mp3
  │   └── trash.mp3
```

## 2. 项目配置 (Configuration)

### 2.1 添加依赖
在 `pubspec.yaml` 中添加 `audioplayers`:

```yaml
dependencies:
  audioplayers: ^6.5.1
```

### 2.2 注册资源
在 `pubspec.yaml` 中声明资源目录:

```yaml
flutter:
  assets:
    - assets/audio/
```

## 3. 代码封装 (Implementation)

创建 `lib/core/utils/sound_service.dart` 统一管理播放逻辑。

```dart
// 核心代码片段
@Riverpod(keepAlive: true)
SoundService soundService(SoundServiceRef ref) => SoundService();

class SoundService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> _playSound(String assetPath) async {
    try {
      // 允许声音重叠，不调用 stop()
      if (_player.state == PlayerState.playing) {
          await _player.stop();
      }
      await _player.setSource(AssetSource(assetPath));
      await _player.resume();
    } catch (e) {
      debugPrint('[SoundService] Error: $e');
    }
  }

  Future<void> playCompletion() async => await _playSound('audio/completion.mp3');
  Future<void> playDelete() async => await _playSound('audio/trash.mp3');
  Future<void> playSuccess() async => await _playSound('audio/success.mp3');
}
```

## 4. 组件集成 (Integration)

在交互触发点调用 Service。

### 4.1 任务勾选 (TaskItem)
**注意**: 自定义 Checkbox 需要在 `onTap` 中处理，而不是 `onChanged`。

```dart
// lib/presentation/widgets/task_item.dart
Widget _buildCheckbox(WidgetRef ref) {
  return GestureDetector(
    onTap: () {
      if (!task.isCompleted) {
        ref.read(soundServiceProvider).playCompletion(); // 播放音效
      }
      ref.read(taskProvider.notifier).toggleTaskComplete(task.id);
    },
    // ...
  );
}
```

### 4.2 删除 (ListSidebar / TaskItem)
```dart
// lib/presentation/widgets/list_sidebar.dart
onPressed: () {
  ref.read(soundServiceProvider).playDelete(); // 播放音效
  ref.read(taskListProvider.notifier).deleteList(list.id);
  Navigator.pop(context);
},
```

### 4.3 同步成功 (WebDavConfigSection)
```dart
// lib/presentation/widgets/webdav_config_section.dart
if (success) {
  ref.read(soundServiceProvider).playSuccess(); // 播放音效
}
```

## 5. 后续扩展
如果需要添加新音效：
1.  重复 Step 1 搜索新素材。
2.  下载到 `assets/audio/`。
3.  并在 `SoundService` 中添加新的 `playXxx()` 方法。
