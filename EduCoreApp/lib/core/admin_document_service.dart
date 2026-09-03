import 'dart:io';

import 'package:dio/dio.dart';

import 'app_constants.dart';
import 'models/admin_draft.dart';
import 'models/admin_paragraph.dart';

class AdminDocumentService {
  AdminDocumentService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<AdminDraft> parseDocument(String filePath, String filename) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: filename),
    });

    final response = await _dio.post(
      '${AppConstants.apiBaseUrl}/admin/parse-document',
      data: formData,
    );

    return AdminDraft.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AdminDraft> saveParagraph({
    required String draftId,
    required int index,
    required AdminParagraph paragraph,
  }) async {
    final response = await _dio.put(
      '${AppConstants.apiBaseUrl}/admin/draft/$draftId/paragraphs/$index',
      data: paragraph.toPayload(),
    );

    return AdminDraft.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> finalizeDraft(String draftId) async {
    final response = await _dio.post(
      '${AppConstants.apiBaseUrl}/admin/draft/$draftId/finalize',
    );
    return response.data as Map<String, dynamic>;
  }

  Future<String> uploadMedia(String filePath, String filename) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: filename),
    });

    final response = await _dio.post(
      '${AppConstants.apiBaseUrl}/upload/media',
      data: formData,
    );

    final data = response.data as Map<String, dynamic>;
    return data['filename'] as String? ?? filename;
  }

  Future<void> rebuildDatabase() async {
    await _dio.post('${AppConstants.apiBaseUrl}/build');
  }

  Future<void> exportDatabase(String savePath) async {
    final response = await _dio.get<List<int>>(
      '${AppConstants.apiBaseUrl}/admin/db/export',
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(minutes: 10),
        sendTimeout: const Duration(minutes: 2),
      ),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Eksport boş jogap gaýtardy.');
    }
    final normalized = savePath.toLowerCase().endsWith('.zip')
        ? savePath
        : '$savePath.zip';
    final file = File(normalized);
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<void> importDatabase(String zipFilePath, String filename) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(zipFilePath, filename: filename),
    });
    await _dio.post(
      '${AppConstants.apiBaseUrl}/admin/db/import',
      data: formData,
      options: Options(
        receiveTimeout: const Duration(minutes: 10),
        sendTimeout: const Duration(minutes: 10),
      ),
    );
  }
}
