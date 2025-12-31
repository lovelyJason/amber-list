import 'dart:io';

void main(List<String> args) {
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('Error: pubspec.yaml not found in current directory.');
    exit(1);
  }

  final content = pubspecFile.readAsStringSync();
  final lines = content.split('\n');
  final versionRegex = RegExp(r'^version:\s+(\d+)\.(\d+)\.(\d+)(\+(\d+))?');

  bool updated = false;
  final newContent = lines.map((line) {
    final match = versionRegex.firstMatch(line);
    if (match != null && !updated) {
      int major = int.parse(match.group(1)!);
      int minor = int.parse(match.group(2)!);
      int patch = int.parse(match.group(3)!);
      int build = match.group(5) != null ? int.parse(match.group(5)!) : 0;

      // Default behavior: increment patch and build number
      // Args can be used to override (e.g. 'major', 'minor') - simplify for now to patch
      if (args.contains('major')) {
        major++;
        minor = 0;
        patch = 0;
      } else if (args.contains('minor')) {
        minor++;
        patch = 0;
      } else {
        patch++;
      }
      build++;

      final newVersion = '$major.$minor.$patch+$build';
      print('Bumping version: ${match.group(0)?.substring(9)} -> $newVersion');
      updated = true;
      return 'version: $newVersion';
    }
    return line;
  }).join('\n');

  if (updated) {
    pubspecFile.writeAsStringSync(newContent);
    print('✅ Version bumped successfully.');
  } else {
    print('Error: Could not find version line in pubspec.yaml');
    exit(1);
  }
}
