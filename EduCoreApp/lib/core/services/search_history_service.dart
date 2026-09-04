import 'dart:convert';
import 'dart:io';

import 'educore_db_bootstrap.dart';

class SearchHistoryService {
  SearchHistoryService._();

  static const _fileName = 'search_history.json';
  static const maxItems = 12;

  static Future<List<String>> load() async {
    try {
      final db = await EduCoreDbBootstrap.ensureReady();
      final file = File('${db.path}${Platform.pathSeparator}$_fileName');
      if (!file.existsSync()) return const [];

      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .take(maxItems)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<String>> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return load();

    final existing = await load();
    final next = [
      trimmed,
      ...existing.where((item) => item.toLowerCase() != trimmed.toLowerCase()),
    ].take(maxItems).toList();

    final db = await EduCoreDbBootstrap.ensureReady();
    final file = File('${db.path}${Platform.pathSeparator}$_fileName');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(next),
      encoding: utf8,
    );
    return next;
  }

  static Future<void> clear() async {
    try {
      final db = await EduCoreDbBootstrap.ensureReady();
      final file = File('${db.path}${Platform.pathSeparator}$_fileName');
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
