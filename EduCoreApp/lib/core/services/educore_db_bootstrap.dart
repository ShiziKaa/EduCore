import 'dart:io';

import '../app_constants.dart';

/// Locates and prepares a complete writable [EduCore_DB] next to the executable.
/// The AI bundle is installed by CMake from `assets/EduCore_DB` (includes `_internal`).
class EduCoreDbBootstrap {
  EduCoreDbBootstrap._();

  static Directory? _runtimeDirectory;

  static Directory? get runtimeDirectory => _runtimeDirectory;

  static Future<Directory> ensureReady() async {
    if (_runtimeDirectory != null && _isCompleteDbRoot(_runtimeDirectory!)) {
      return _runtimeDirectory!;
    }

    final exeDir = File(Platform.resolvedExecutable).parent;
    final writable = Directory(
      '${exeDir.path}${Platform.pathSeparator}${AppConstants.dbFolderName}',
    );

    if (_isCompleteDbRoot(writable)) {
      _ensureWorkspaceFolders(writable);
      _runtimeDirectory = writable.absolute;
      return _runtimeDirectory!;
    }

    final source = _findSourceDirectory(exeDir);
    if (source == null) {
      throw StateError(
        '${AppConstants.dbFolderName} tapylmady. '
        'scripts/setup_educore_db.ps1 işlediň we flutter build windows gaýtadan işlediň.',
      );
    }

    await _mirrorDirectory(source, writable);
    _ensureWorkspaceFolders(writable);
    _runtimeDirectory = writable.absolute;
    return _runtimeDirectory!;
  }

  static Directory? _findSourceDirectory(Directory exeDir) {
    final candidates = <Directory>[
      // CMake install (complete bundle next to educore.exe)
      Directory(
        '${exeDir.path}${Platform.pathSeparator}${AppConstants.dbFolderName}',
      ),
      // Dev: project assets when running from build/windows/x64/runner/Debug
      Directory(
        '${exeDir.path}${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}assets${Platform.pathSeparator}${AppConstants.dbFolderName}',
      ),
    ];

    for (final dir in candidates) {
      if (_isCompleteDbRoot(dir.absolute)) {
        return dir.absolute;
      }
    }
    return null;
  }

  static bool _isCompleteDbRoot(Directory dir) {
    if (!dir.existsSync()) return false;

    final searchExe = File(
      '${dir.path}${Platform.pathSeparator}${AppConstants.searchEngineExeName}',
    );
    final internal = Directory(
      '${dir.path}${Platform.pathSeparator}_internal',
    );
    final chromadbBindings = File(
      '${internal.path}${Platform.pathSeparator}chromadb_rust_bindings${Platform.pathSeparator}chromadb_rust_bindings.pyd',
    );

    return searchExe.existsSync() &&
        internal.existsSync() &&
        chromadbBindings.existsSync();
  }

  static void _ensureWorkspaceFolders(Directory root) {
    for (final name in ['data', 'images', 'videos', 'audios', 'chroma_db', 'models']) {
      Directory('${root.path}${Platform.pathSeparator}$name').createSync(
        recursive: true,
      );
    }
  }

  static Future<void> _mirrorDirectory(
    Directory source,
    Directory destination,
  ) async {
    if (destination.existsSync()) {
      destination.deleteSync(recursive: true);
    }
    destination.createSync(recursive: true);

    await for (final entity in source.list(recursive: false)) {
      final name = entity.path.split(Platform.pathSeparator).last;
      final targetPath = '${destination.path}${Platform.pathSeparator}$name';

      if (entity is Directory) {
        await _mirrorDirectory(entity, Directory(targetPath));
      } else if (entity is File) {
        final targetFile = File(targetPath);
        targetFile.parent.createSync(recursive: true);
        await entity.copy(targetFile.path);
      }
    }
  }
}
