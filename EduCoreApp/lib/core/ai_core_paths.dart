import 'dart:io';

import 'app_constants.dart';
import 'services/educore_db_bootstrap.dart';

class AiCorePaths {
  AiCorePaths._();

  static Directory? resolveDbDirectory() {
    final runtime = EduCoreDbBootstrap.runtimeDirectory;
    if (runtime != null && _isValidDbRoot(runtime)) {
      return runtime;
    }

    final exeDir = File(Platform.resolvedExecutable).parent;
    final fallback = Directory(
      '${exeDir.path}${Platform.pathSeparator}${AppConstants.dbFolderName}',
    );
    if (_isValidDbRoot(fallback)) {
      return fallback.absolute;
    }

    return null;
  }

  static bool _isValidDbRoot(Directory dir) {
    if (!dir.existsSync()) return false;

    final searchExe = File(
      '${dir.path}${Platform.pathSeparator}${AppConstants.searchEngineExeName}',
    );
    return searchExe.existsSync();
  }

  static ({String executable, List<String> args}) resolveSearchEngineLaunch() {
    final dbRoot = resolveDbDirectory();
    if (dbRoot == null) {
      throw StateError('${AppConstants.dbFolderName} taýýar däl.');
    }

    final exe = File(
      '${dbRoot.path}${Platform.pathSeparator}${AppConstants.searchEngineExeName}',
    );
    return (executable: exe.path, args: const []);
  }

  static File? resolveImageFile(String imageName, {String? coreDirectory}) {
    final dbDir = coreDirectory ?? resolveDbDirectory()?.path;
    if (dbDir == null) return null;

    final imageFile = File(
      '$dbDir${Platform.pathSeparator}images${Platform.pathSeparator}$imageName',
    );
    return imageFile.existsSync() ? imageFile.absolute : null;
  }

  static File? resolveVideoFile(String videoName, {String? coreDirectory}) {
    final dbDir = coreDirectory ?? resolveDbDirectory()?.path;
    if (dbDir == null) return null;

    final videoFile = File(
      '$dbDir${Platform.pathSeparator}videos${Platform.pathSeparator}$videoName',
    );
    return videoFile.existsSync() ? videoFile.absolute : null;
  }
}
