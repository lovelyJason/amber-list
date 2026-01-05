/// 重新生成 .env 相关代码
///
/// 修改 .env 文件后，必须先清理再重新生成，否则 envied 不会更新
/// 使用方法：dart run scripts/rebuild_env.dart
///
/// 原理：envied 使用 build_runner 生成 env.g.dart 文件
/// 如果不先 clean，build_runner 会认为文件没有变化而跳过生成

import 'dart:io';

void main() async {
  print('🔄 重新生成 .env 代码...\n');

  // 检查是否在项目根目录
  if (!File('pubspec.yaml').existsSync()) {
    print('❌ 错误: 请在项目根目录运行此脚本');
    exit(1);
  }

  // 检查 .env 文件是否存在
  if (!File('.env').existsSync()) {
    print('❌ 错误: .env 文件不存在');
    exit(1);
  }

  // 步骤 1: 清理 build_runner 缓存
  print('📦 步骤 1/2: 清理 build_runner 缓存...');
  final cleanResult = await Process.run(
    'dart',
    ['run', 'build_runner', 'clean'],
    runInShell: true,
  );

  if (cleanResult.exitCode != 0) {
    print('⚠️  警告: 清理失败（可能是首次运行）');
    print(cleanResult.stderr);
  } else {
    print('✅ 缓存已清理');
  }

  // 步骤 2: 重新生成代码
  print('\n🔨 步骤 2/2: 重新生成代码...');
  final buildResult = await Process.run(
    'dart',
    ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
    runInShell: true,
  );

  stdout.write(buildResult.stdout);

  if (buildResult.exitCode != 0) {
    print('❌ 生成失败');
    print(buildResult.stderr);
    exit(1);
  }

  print('\n✅ .env 代码重新生成完成！');
  print('   生成的文件: lib/env/env.g.dart');
}
