import 'dart:io';

import '../ai_core_paths.dart';
import 'educore_db_bootstrap.dart';

class InstituteLogoService {
  InstituteLogoService._();

  static const _baseName = 'institute_logo';
  static const _extensions = ['png', 'jpg', 'jpeg'];

  static File? resolve() {
    final dbDir = AiCorePaths.resolveDbDirectory()?.path;
    if (dbDir == null) return null;

    for (final ext in _extensions) {
      final file = File('$dbDir${Platform.pathSeparator}$_baseName.$ext');
      if (file.existsSync()) {
        return file.absolute;
      }
    }
    return null;
  }

  static Future<File> importLogo(String sourcePath) async {
    final db = await EduCoreDbBootstrap.ensureReady();
    await _removeExisting(db.path);

    final extension = _normalizeExtension(sourcePath);
    final target = File('${db.path}${Platform.pathSeparator}$_baseName.$extension');
    await File(sourcePath).copy(target.path);
    return target;
  }

  static Future<void> _removeExisting(String dbPath) async {
    for (final ext in _extensions) {
      final file = File('$dbPath${Platform.pathSeparator}$_baseName.$ext');
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }

  static String _normalizeExtension(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (_extensions.contains(ext)) return ext;
    return 'png';
  }
}
