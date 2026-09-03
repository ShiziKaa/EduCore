import 'package:dio/dio.dart';

import 'app_constants.dart';

class RelatedSuggestion {
  const RelatedSuggestion({required this.text, required this.query});

  final String text;
  final String query;

  factory RelatedSuggestion.fromJson(Map<String, dynamic> json) {
    final text = (json['text'] as String? ?? '').trim();
    final query = (json['query'] as String? ?? text).trim();
    return RelatedSuggestion(
      text: text,
      query: query.isNotEmpty ? query : text,
    );
  }
}

class SearchResult {
  const SearchResult({
    required this.answer,
    required this.images,
    required this.videos,
    required this.audios,
    required this.related,
    required this.found,
  });

  final String answer;
  final List<String> images;
  final List<String> videos;
  final List<String> audios;
  final List<RelatedSuggestion> related;
  final bool found;

  static const notFoundMessage =
      'Soragyňyz boýunça maglumat bazasynda maglumat ýok.';
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
    final status = data['status']?.toString() ?? '';
    final foundFlag = data['found'];
    final found = foundFlag is bool
        ? foundFlag
        : status == 'success';

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

    final related = (data['related'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map(
          (item) => RelatedSuggestion.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((item) => item.text.isNotEmpty)
        .take(AppConstants.maxRelatedSuggestions)
        .toList();

    final answer = (data['answer']?.toString() ?? '').trim();

    if (!found) {
      return SearchResult(
        answer: answer.isNotEmpty ? answer : SearchResult.notFoundMessage,
        images: const [],
        videos: const [],
        audios: const [],
        related: const [],
        found: false,
      );
    }

    return SearchResult(
      answer: answer.isNotEmpty ? answer : SearchResult.notFoundMessage,
      images: images,
      videos: videos,
      audios: audios,
      related: related,
      found: answer.isNotEmpty && answer != SearchResult.notFoundMessage,
    );
  }
}
