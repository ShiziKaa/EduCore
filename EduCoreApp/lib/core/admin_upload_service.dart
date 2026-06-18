import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import 'app_constants.dart';

class AdminUploadService {
  AdminUploadService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<void> uploadFiles(List<PlatformFile> files) async {
    for (final file in files) {
      if (file.path == null) continue;

      final lowerName = file.name.toLowerCase();
      final endpoint =
          lowerName.endsWith('.docx') || lowerName.endsWith('.xlsx')
          ? '${AppConstants.apiBaseUrl}/upload/document'
          : '${AppConstants.apiBaseUrl}/upload/media';

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path!, filename: file.name),
      });

      await _dio.post(endpoint, data: formData);
    }
  }

  Future<void> rebuildDatabase() async {
    await _dio.post('${AppConstants.apiBaseUrl}/build');
  }
}
