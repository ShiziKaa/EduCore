import 'package:dio/dio.dart';

import 'app_constants.dart';

class SearchResult {
  const SearchResult({
    required this.answer,
    required this.images,
    required this.videos,
    required this.audios,
  });

  final String answer;
  final List<String> images;
  final List<String> videos;
  final List<String> audios;
}

class SearchService {
  SearchService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<SearchResult> search(String question) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${AppConstants.apiBaseUrl}/search',
      queryParameters: {'query': question},
    );

    final data = response.data ?? {};
    final images =
        (data['images'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList() ??
        <String>[];
    final videos =
        (data['videos'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList() ??
        <String>[];
    final audios =
        (data['audios'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList() ??
        <String>[];

    return SearchResult(
      answer: data['answer']?.toString() ?? 'Bagyşlaň, maglumat tapylmady.',
      images: images,
      videos: videos,
      audios: audios,
    );
  }
}
