# 技能：添加音效 (Add Sound Effect)

## 描述
本技能用于指导 AI 助手为琥珀清单 (Amber List) 应用添加新的 UI 音效，确保流程符合 `docs/sound_effects_guide.md` 中定义的项目架构规范。

## 工作流

当用户请求添加新音效（例如：“给点击 X 添加一个音效”）时，请遵循以下标准流程：

### 1. 搜索与下载素材
*   **搜索**: 寻找高质量、免版税的 MP3 文件。
    *   使用 Google 搜索: `site:raw.githubusercontent.com "[关键词].mp3"` (例如: `success.mp3`, `click.mp3`, `pop.mp3`)。
    *   **首选源**: `rse/soundfx`, `vinceliuice/WhiteSur-gtk-theme`, `modmii`。
*   **下载**: 使用 `curl` 命令直接将文件下载到资源目录。
    ```bash
    curl -L -o assets/audio/[sound_name].mp3 [raw_url]
    ```

### 2. 更新代码 (`SoundService`)
*   **文件**: `lib/core/utils/sound_service.dart`
*   **操作**: 为新音效添加一个播放方法。
    ```dart
    Future<void> play[SoundName]() async {
      await _playSound('audio/[sound_name].mp3');
    }
    ```

### 3. 集成 UI
*   **定位**: 找到负责触发该事件的 Widget 或逻辑块。
*   **导入**: `import '../../core/utils/sound_service.dart';` (根据实际层级调整路径)。
*   **调用**:
    ```dart
    ref.read(soundServiceProvider).play[SoundName]();
    ```

### 4. 验证
*   确保由正确的逻辑触发（例如：对于自定义 Widget 应在 `onTap` 中触发，而不是 `onChanged`）。
*   验证 `pubspec.yaml` 中是否已包含 `assets/audio/`（正常情况下应已包含）。

## 参考
详细实现细节请参阅 `docs/sound_effects_guide.md`。
