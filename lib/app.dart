import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/amber_theme.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/providers/app_update_provider.dart';
import 'presentation/widgets/app_menu_bar.dart';
import 'presentation/widgets/app_update_dialog.dart';

/// 琥珀清单应用
class AmberListApp extends ConsumerStatefulWidget {
  const AmberListApp({super.key});

  @override
  ConsumerState<AmberListApp> createState() => _AmberListAppState();
}

class _AmberListAppState extends ConsumerState<AmberListApp> {
  @override
  void initState() {
    super.initState();
    // 延迟检查更新，避免阻塞启动流程
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdatesOnStartup();
    });
  }

  /// 应用启动时自动检查更新
  Future<void> _checkForUpdatesOnStartup() async {
    // 静默检查更新，不显示对话框（除非是强制更新）
    final result = await ref.read(appUpdateProvider.notifier).checkForUpdates(
          showDialogOnForce: true,
        );

    // 如果需要强制更新，且用户没有关闭对话框，则显示强制更新页面
    // 这里的逻辑是：检查完成后，如果是强制更新，Provider 会设置 showForceUpdateDialog = true
    // 下面的 build 方法会监听这个状态并显示强制更新页面
    if (result.isForceUpdate && mounted) {
      debugPrint('[App] 检测到强制更新要求');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听更新状态
    final updateState = ref.watch(appUpdateProvider);

    return MaterialApp(
      title: '琥珀清单',
      debugShowCheckedModeBanner: false,
      theme: AmberTheme.lightTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'), // 中文简体
      ],
      locale: const Locale('zh', 'CN'), // 强制使用中文
      // 如果需要强制更新，显示强制更新页面，否则显示正常主页
      home: updateState.showForceUpdateDialog &&
              updateState.lastCheckResult != null &&
              updateState.isForceUpdate
          ? ForceUpdateScreen(result: updateState.lastCheckResult!)
          : const AmberMenuBar(child: HomePage()),
    );
  }
}
