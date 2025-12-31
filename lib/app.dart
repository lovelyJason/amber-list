import 'package:flutter/material.dart';
import 'core/theme/amber_theme.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/widgets/app_menu_bar.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

/// 琥珀清单应用
class AmberListApp extends StatelessWidget {
  const AmberListApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      home: const AmberMenuBar(child: HomePage()),
    );
  }
}
