import 'dart:io';

import 'package:dio/dio.dart';

import 'app_constants.dart';
import 'ai_core_paths.dart';
import 'services/educore_db_bootstrap.dart';

class AiServerService {
  AiServerService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  Process? _serverProcess;

  Map<String, String> _environment(String dbRoot) {
    final modelsPath = '$dbRoot${Platform.pathSeparator}models';
    final env = <String, String>{
      ...Platform.environment,
      'PYTHONUTF8': '1',
      'PYTHONIOENCODING': 'utf-8',
      'HF_HUB_DISABLE_PROGRESS_BARS': '1',
      'TRANSFORMERS_VERBOSITY': 'error',
      'TQDM_DISABLE': '1',
      'EDUCORE_DB_DIR': dbRoot,
      'SENTENCE_TRANSFORMERS_HOME': modelsPath,
      'HF_HOME': modelsPath,
    };

    if (_hasLocalModel(modelsPath)) {
      env['HF_HUB_OFFLINE'] = '1';
      env['TRANSFORMERS_OFFLINE'] = '1';
    }

    return env;
  }

  bool _hasLocalModel(String modelsPath) {
    final modelsDir = Directory(modelsPath);
    if (!modelsDir.existsSync()) return false;

    for (final entity in modelsDir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final lower = entity.path.toLowerCase();
      if (lower.endsWith('.bin') ||
          lower.endsWith('.safetensors') ||
          lower.endsWith('.onnx') ||
          lower.endsWith('.pt')) {
        return true;
      }
    }

    final hubDir = Directory(
      '$modelsPath${Platform.pathSeparator}models--intfloat--multilingual-e5-base${Platform.pathSeparator}blobs',
    );
    if (!hubDir.existsSync()) return false;

    var totalBytes = 0;
    for (final entity in hubDir.listSync(recursive: true)) {
      if (entity is File) totalBytes += entity.lengthSync();
    }
    return totalBytes > 500 * 1024 * 1024;
  }

  Future<void> ensureRunning() async {
    if (await _isHealthy()) return;

    final dbRoot = await EduCoreDbBootstrap.ensureReady();
    final launch = AiCorePaths.resolveSearchEngineLaunch();

    _serverProcess = await Process.start(
      launch.executable,
      launch.args,
      workingDirectory: dbRoot.path,
      environment: _environment(dbRoot.path),
      mode: ProcessStartMode.detached,
    );

    // Model load from disk can take 1-3 minutes on first start.
    for (var attempt = 0; attempt < 240; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (await _isHealthy()) return;
    }

    throw StateError('AI serweri başladylyp bilmedi.');
  }

  Future<bool> _isHealthy() async {
    try {
      final response = await _dio.get(
        '${AppConstants.apiBaseUrl}/health',
        options: Options(
          receiveTimeout: const Duration(seconds: 3),
          sendTimeout: const Duration(seconds: 3),
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> dispose() async {
    _serverProcess?.kill();
    _serverProcess = null;
  }
}
