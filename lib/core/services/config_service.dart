import 'dart:convert';
import 'dart:io';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  String get _configPath {
    String home = '';
    if (Platform.isMacOS) {
      home = Platform.environment['HOME'] ?? '';
    } else if (Platform.isWindows) {
      home = Platform.environment['USERPROFILE'] ?? '';
    }
    
    // Fallback or empty check
    if (home.isEmpty) {
      // Should probably log or handle robustly, but for now assumption is Desktop OS
      return 'config.json'; 
    }
    
    return '$home/amber-list/config.json';
  }

  String get configPath => _configPath;

  Future<File> get _configFile async {
    final path = _configPath;
    final file = File(path);
    if (!await file.exists()) {
      await file.create(recursive: true);
      await file.writeAsString('{}');
    }
    return file;
  }

  Future<Map<String, dynamic>> _readConfig() async {
    try {
      final file = await _configFile;
      final content = await file.readAsString();
      if (content.isEmpty) return {};
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      // If error (e.g. corrupted json), return empty
      return {};
    }
  }

  Future<void> _writeConfig(Map<String, dynamic> config) async {
    final file = await _configFile;
    await file.writeAsString(jsonEncode(config));
  }

  // === Specific Flags ===

  Future<bool> hasSeenCalendarTour() async {
    final config = await _readConfig();
    return config['has_seen_calendar_tour'] == true;
  }

  Future<void> markCalendarTourSeen() async {
    final config = await _readConfig();
    config['has_seen_calendar_tour'] = true;
    await _writeConfig(config);
  }
}
