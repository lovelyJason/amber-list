import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../data/datasources/local/database.dart';
import '../services/config_service.dart';

import 'package:package_info_plus/package_info_plus.dart';

class StartupLogger {
  static Future<void> printInfo() async {
    try {
      final dbPath = await AppDatabase.getDatabasePath();
      final configPath = ConfigService().configPath;
      String prefsPath = 'Unknown';
      
      if (Platform.isMacOS) {
        final packageInfo = await PackageInfo.fromPlatform();
        final bundleId = packageInfo.packageName;
        prefsPath =
            '${Platform.environment['HOME']}/Library/Preferences/$bundleId.plist';
      } else if (Platform.isWindows) {
        prefsPath = 'AppData\\Local\\...'; // Generic placeholder
      }

      // ANSI Colors
      const String reset = '\x1B[0m';
      const String cyan = '\x1B[36m';
      const String green = '\x1B[32m';
      const String yellow = '\x1B[33m';
      const String bold = '\x1B[1m';
      const String magenta = '\x1B[35m';

      // Print Banner (using print to avoid flutter: prefix)
      // ignore: avoid_print
      print('\n$cyan$bold==============================================================$reset');
      // ignore: avoid_print
      print('$cyan$bold              💎  AMBER LIST STARTUP INFO  💎$reset');
      // ignore: avoid_print
      print('$cyan$bold==============================================================$reset');
      // ignore: avoid_print
      print('$green$bold[DATABASE]   $reset$dbPath');
      // ignore: avoid_print
      print('$yellow$bold[CONFIG]     $reset$configPath');
      // ignore: avoid_print
      print('$magenta$bold[PREFS_DIR]  $reset$prefsPath');
      // ignore: avoid_print
      print('$cyan$bold==============================================================$reset\n');
    } catch (e) {
      debugPrint('Error getting paths: $e');
    }
  }
}
