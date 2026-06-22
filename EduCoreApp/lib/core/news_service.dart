import 'package:dio/dio.dart';

import 'app_constants.dart';
import 'models/news_item.dart';

class NewsService {
  NewsService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<List<NewsItem>> fetchNews() async {
    try {
      final response = await _dio.get('${AppConstants.apiBaseUrl}/news');
      final data = response.data as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? [];
      return items
          .map((item) => NewsItem.fromJson(item as Map<String, dynamic>))
          .where((item) => item.text.isNotEmpty && item.preview.isNotEmpty)
          .take(AppConstants.maxNewsItems)
          .toList();
    } on DioException {
      return [];
    }
  }
}
