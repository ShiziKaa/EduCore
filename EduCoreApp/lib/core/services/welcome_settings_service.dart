import 'dart:convert';
import 'dart:io';

import '../models/welcome_settings.dart';
import 'educore_db_bootstrap.dart';

class WelcomeSettingsService {
  WelcomeSettingsService._();

  static const _fileName = 'welcome_settings.json';

  static Future<WelcomeSettings> load() async {
    try {
      final db = await EduCoreDbBootstrap.ensureReady();
      final file = File('${db.path}${Platform.pathSeparator}$_fileName');
      if (!file.existsSync()) return WelcomeSettings.defaults;

      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return WelcomeSettings.fromJson(json);
    } catch (_) {
      return WelcomeSettings.defaults;
    }
  }

  static WelcomeSettings loadSync() {
    try {
      final db = EduCoreDbBootstrap.runtimeDirectory;
      if (db == null) return WelcomeSettings.defaults;

      final file = File('${db.path}${Platform.pathSeparator}$_fileName');
      if (!file.existsSync()) return WelcomeSettings.defaults;

      final raw = file.readAsStringSync();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return WelcomeSettings.fromJson(json);
    } catch (_) {
      return WelcomeSettings.defaults;
    }
  }

  static Future<WelcomeSettings> save(WelcomeSettings settings) async {
    final db = await EduCoreDbBootstrap.ensureReady();
    final file = File('${db.path}${Platform.pathSeparator}$_fileName');
    final encoded = const JsonEncoder.withIndent('  ').convert(settings.toJson());
    await file.writeAsString(encoded, encoding: utf8);
    return settings;
  }
}
