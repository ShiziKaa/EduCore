import 'dart:io';

import 'package:dio/dio.dart';

import 'app_constants.dart';
import 'models/admin_draft.dart';
import 'models/admin_paragraph.dart';
import 'models/kb_stats.dart';

class KbParagraphsResult {
  const KbParagraphsResult({
    required this.paragraphs,
    required this.stats,
  });

  final List<AdminParagraph> paragraphs;
  final KbStats stats;
}

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

  Future<Map<String, dynamic>> rebuildDatabase({bool autoBackup = true}) async {
    final response = await _dio.post(
      '${AppConstants.apiBaseUrl}/build',
      queryParameters: {'auto_backup': autoBackup},
    );
    return response.data as Map<String, dynamic>? ?? {};
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

  Future<KbParagraphsResult> listKbParagraphs({
    String query = '',
    bool newsOnly = false,
  }) async {
    final response = await _dio.get(
      '${AppConstants.apiBaseUrl}/admin/kb/paragraphs',
      queryParameters: {
        'q': query,
        'news_only': newsOnly,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final paragraphs = (data['paragraphs'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => AdminParagraph.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final stats = KbStats.fromJson(
      Map<String, dynamic>.from(data['stats'] as Map? ?? {}),
    );
    return KbParagraphsResult(paragraphs: paragraphs, stats: stats);
  }

  Future<KbStats> fetchKbStats() async {
    final response = await _dio.get('${AppConstants.apiBaseUrl}/admin/kb/stats');
    return KbStats.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AdminParagraph> updateKbParagraph(AdminParagraph paragraph) async {
    final response = await _dio.put(
      '${AppConstants.apiBaseUrl}/admin/kb/paragraphs',
      data: paragraph.toKbPayload(),
    );
    final data = response.data as Map<String, dynamic>;
    return AdminParagraph.fromJson(
      Map<String, dynamic>.from(data['paragraph'] as Map),
    );
  }

  Future<List<AdminParagraph>> saveKbFile({
    required String source,
    required List<AdminParagraph> paragraphs,
  }) async {
    final response = await _dio.post(
      '${AppConstants.apiBaseUrl}/admin/kb/save',
      data: {
        'source': source,
        'paragraphs': paragraphs.map((item) => item.toPayload()).toList(),
      },
    );
    final data = response.data as Map<String, dynamic>;
    return (data['paragraphs'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => AdminParagraph.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<AdminParagraph>> addKbParagraph({
    required String source,
    required int afterIndex,
    String text = 'Täze abzas',
  }) async {
    final response = await _dio.post(
      '${AppConstants.apiBaseUrl}/admin/kb/paragraphs/add',
      data: {
        'source': source,
        'index': afterIndex,
        'text': text,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return (data['paragraphs'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => AdminParagraph.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<AdminParagraph>> deleteKbParagraph({
    required String source,
    required int index,
  }) async {
    final response = await _dio.post(
      '${AppConstants.apiBaseUrl}/admin/kb/paragraphs/delete',
      data: {
        'source': source,
        'index': index,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return (data['paragraphs'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => AdminParagraph.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<AdminParagraph>> duplicateKbParagraph({
    required String source,
    required int index,
  }) async {
    final response = await _dio.post(
      '${AppConstants.apiBaseUrl}/admin/kb/paragraphs/duplicate',
      data: {
        'source': source,
        'index': index,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return (data['paragraphs'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => AdminParagraph.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<String> exportKbParagraphsText(List<AdminParagraph> paragraphs) async {
    final response = await _dio.post(
      '${AppConstants.apiBaseUrl}/admin/kb/export-text',
      data: {
        'paragraphs': paragraphs.map((item) => item.toPayload()).toList(),
      },
    );
    final data = response.data as Map<String, dynamic>;
    return data['text'] as String? ?? '';
  }
}
