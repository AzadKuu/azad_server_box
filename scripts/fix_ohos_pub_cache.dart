// Fix TargetPlatform.ohos exhaustive switch errors in Pub Cache packages.
//
// The HarmonyOS Flutter SDK adds TargetPlatform.ohos to the enum, but several
// packages have exhaustive switches that don't handle it. This script patches
// those packages in Pub Cache so both Windows and OHOS builds compile.
//
// Run: dart scripts/fix_ohos_pub_cache.dart
//
// Idempotent: safe to run multiple times. Skips files already patched.

import 'dart:io';

void main() {
  final pubCache = _findPubCache();
  if (pubCache == null) {
    stderr.writeln('Could not locate Pub Cache directory.');
    exit(1);
  }

  final hostedDir = Directory('${pubCache.path}/hosted/pub.flutter-io.cn');
  if (!hostedDir.existsSync()) {
    stderr.writeln('Pub Cache hosted dir not found: ${hostedDir.path}');
    exit(1);
  }

  var fixed = 0;

  // 1. material_ui: fix "ohos =>" to "ohos ||" and add missing ohos cases
  fixed += _fixMaterialUi(hostedDir);

  // 2. cupertino_ui: fix "ohos =>" to "ohos ||"
  fixed += _fixCupertinoUi(hostedDir);

  // 3. responsive_framework: add ohos enum + case
  fixed += _fixResponsiveFramework(hostedDir);

  // 4. flutter_math_fork: add ohos case (fall through to android)
  fixed += _fixFlutterMathFork(hostedDir);

  stdout.writeln('Done. $fixed file(s) patched.');
}

/// Find the Pub Cache directory from PUB_CACHE env var or default locations.
Directory? _findPubCache() {
  final env = Platform.environment['PUB_CACHE'];
  if (env != null && Directory(env).existsSync()) return Directory(env);

  if (Platform.isWindows) {
    final local = Platform.environment['LOCALAPPDATA'];
    if (local != null) {
      final d = Directory('$local/Pub/Cache');
      if (d.existsSync()) return d;
    }
  } else {
    final home = Platform.environment['HOME'];
    if (home != null) {
      for (final p in ['$home/.pub-cache', '$home/.pub-cache/hosted/pub.flutter-io.cn']) {
        final d = Directory(p);
        if (d.existsSync()) return d;
      }
    }
  }
  return null;
}

String _read(File f) => f.readAsStringSync();
void _write(File f, String content) => f.writeAsStringSync(content);

/// Check if file already has ohos in || chain (already patched).
bool _hasOhosOr(String text) =>
    RegExp(r'TargetPlatform\.ohos\s*\|\|').hasMatch(text);

/// Check if file already has "case TargetPlatform.ohos:" (already patched).
bool _hasOhosCase(String text) =>
    RegExp(r'case\s+TargetPlatform\.ohos:').hasMatch(text);

int _fixFile(File file, String name, String Function(String) patchFn) {
  if (!file.existsSync()) {
    stderr.writeln('  SKIP (not found): $name');
    return 0;
  }
  final original = _read(file);
  final patched = patchFn(original);
  if (patched != original) {
    _write(file, patched);
    stdout.writeln('  PATCHED: $name');
    return 1;
  }
  stdout.writeln('  OK (already patched or no change): $name');
  return 0;
}

int _fixMaterialUi(Directory hostedDir) {
  stdout.writeln('\n=== material_ui ===');
  final dir = Directory('${hostedDir.path}/material_ui-1.1.0/lib/src');
  if (!dir.existsSync()) {
    stderr.writeln('  material_ui not found');
    return 0;
  }
  var count = 0;

  // Files where "ohos =>" should be "ohos ||" (previous bad patch)
  final arrowFiles = [
    'bottom_sheet.dart', 'app_bar.dart', 'dialog.dart', 'drawer.dart',
    'dropdown_menu.dart', 'flexible_space_bar.dart', 'scaffold.dart',
    'search_anchor.dart', 'selection_area.dart', 'theme_data.dart',
    'tooltip.dart', 'typography.dart',
  ];

  for (final name in arrowFiles) {
    count += _fixFile(File('${dir.path}/$name'), 'material_ui/$name', (text) {
      // Fix "ohos =>" followed by "windows =>" → "ohos ||" + "windows =>"
      return text.replaceAllMapped(
        RegExp(r'TargetPlatform\.ohos\s*=>\s*\n(\s*)TargetPlatform\.windows\s*=>'),
        (m) => 'TargetPlatform.ohos ||\n${m.group(1)}TargetPlatform.windows =>',
      );
    });
  }

  // page.dart: add ohos to || chain
  count += _fixFile(File('${dir.path}/page.dart'), 'material_ui/page.dart', (text) {
    if (_hasOhosOr(text)) return text;
    // Add "TargetPlatform.ohos ||" before "TargetPlatform.linux =>"
    return text.replaceFirst(
      RegExp(r'TargetPlatform\.windows\s*\|\|\n\s*TargetPlatform\.linux\s*=>'),
      'TargetPlatform.windows ||\n          TargetPlatform.ohos ||\n          TargetPlatform.linux =>',
    );
  });

  // page_transitions_theme.dart: add ohos to || chain
  count += _fixFile(File('${dir.path}/page_transitions_theme.dart'),
      'material_ui/page_transitions_theme.dart', (text) {
    if (_hasOhosOr(text)) return text;
    return text.replaceFirst(
      RegExp(r'TargetPlatform\.macOS\s*\|\|\n\s*TargetPlatform\.linux\s*=>'),
      'TargetPlatform.macOS ||\n          TargetPlatform.ohos ||\n          TargetPlatform.linux =>',
    );
  });

  return count;
}

int _fixCupertinoUi(Directory hostedDir) {
  stdout.writeln('\n=== cupertino_ui ===');
  final dir = Directory('${hostedDir.path}/cupertino_ui-1.0.1/lib/src');
  if (!dir.existsSync()) {
    stderr.writeln('  cupertino_ui not found');
    return 0;
  }
  var count = 0;

  for (final name in ['button.dart', 'checkbox.dart']) {
    count += _fixFile(File('${dir.path}/$name'), 'cupertino_ui/$name', (text) {
      return text.replaceAllMapped(
        RegExp(r'TargetPlatform\.ohos\s*=>\s*\n(\s*)TargetPlatform\.windows\s*=>'),
        (m) => 'TargetPlatform.ohos ||\n${m.group(1)}TargetPlatform.windows =>',
      );
    });
  }

  return count;
}

int _fixResponsiveFramework(Directory hostedDir) {
  stdout.writeln('\n=== responsive_framework ===');
  final file = File('${hostedDir.path}/responsive_framework-1.5.1/lib/src/utils/responsive_utils.dart');
  return _fixFile(file, 'responsive_framework/responsive_utils.dart', (text) {
    var patched = text;

    // Add ohos to enum (after windows, before web)
    if (!patched.contains('  ohos,\n  web,')) {
      patched = patched.replaceFirst(
        '  windows,\n  web,\n}',
        '  windows,\n  ohos,\n  web,\n}',
      );
    }

    // Add ohos case to switch (after windows case)
    if (!patched.contains('case TargetPlatform.ohos:')) {
      patched = patched.replaceFirst(
        'case TargetPlatform.windows:\n        return ResponsiveTargetPlatform.windows;\n    }',
        'case TargetPlatform.windows:\n        return ResponsiveTargetPlatform.windows;\n      case TargetPlatform.ohos:\n        return ResponsiveTargetPlatform.ohos;\n    }',
      );
    }

    return patched;
  });
}

int _fixFlutterMathFork(Directory hostedDir) {
  stdout.writeln('\n=== flutter_math_fork ===');
  final base = '${hostedDir.path}/flutter_math_fork-0.7.4/lib/src';
  var count = 0;

  final files = [
    '$base/widgets/selectable.dart',
    '$base/render/layout/line_editable.dart',
    '$base/widgets/selection/gesture_detector_builder_selectable.dart',
  ];

  for (final path in files) {
    final name = path.split('flutter_math_fork-0.7.4/')[1];
    count += _fixFile(File(path), 'flutter_math_fork/$name', (text) {
      if (_hasOhosCase(text)) return text;
      // Add "case TargetPlatform.ohos:" after non-commented "case TargetPlatform.android:"
      // But NOT after "//     case TargetPlatform.android:" (commented out)
      return text.replaceAllMapped(
        RegExp(r'^(\s*)case TargetPlatform\.android:\n', multiLine: true),
        (m) => '${m.group(1)}case TargetPlatform.android:\n${m.group(1)}case TargetPlatform.ohos:\n',
      );
    });
  }

  return count;
}
