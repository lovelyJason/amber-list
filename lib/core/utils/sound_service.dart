import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sound_service.g.dart';

@Riverpod(keepAlive: true)
SoundService soundService(SoundServiceRef ref) {
  return SoundService();
}

class SoundService {
  final AudioPlayer _player = AudioPlayer();

  // 预加载音效以减少延迟
  Future<void> init() async {
    // 桌面端通常不需要显式预加载，但为了保险
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
      debugPrint('SoundService init error: $e');
    }
  }

  /// 播放任务完成音效
  Future<void> playCompletion() async {
    await _playSound('audio/completion.mp3');
  }

  /// 播放删除音效
  Future<void> playDelete() async {
    await _playSound('audio/trash.mp3');
  }

  /// 播放成功/同步完成音效
  Future<void> playSuccess() async {
    await _playSound('audio/success.mp3');
  }

  /// 播放添加任务音效
  Future<void> playAdd() async {
    await _playSound('audio/add.mp3');
  }

  /// 播放错误音效
  Future<void> playError() async {
    await _playSound('audio/error.mp3');
  }

  /// 播放番茄时钟开始/暂停音效 (Tick)
  Future<void> playPomodoroTick() async {
    await _playSound('audio/tick.mp3');
  }

  /// 播放番茄时钟结束音效
  Future<void> playPomodoroEnd() async {
    await _playSound('audio/pomodoro_end.mp3');
  }

  Future<void> _playSound(String assetPath) async {
    try {
      // debugPrint('[SoundService] Playing: $assetPath');
      // 允许声音重叠，不调用 stop()
      // 创建新的临时播放器实例以支持并发播放效果更好，
      // 但为了性能先尝试复用 player。如果复用有问题，改为每次 new AudioPlayer()。
      if (_player.state == PlayerState.playing) {
        await _player.stop();
      }
      await _player.setSource(AssetSource(assetPath));
      await _player.resume();
    } catch (e) {
      debugPrint('[SoundService] Error playing sound $assetPath: $e');
    }
  }
}
