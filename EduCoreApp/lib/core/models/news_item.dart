class NewsItem {
  const NewsItem({required this.text, required this.preview});

  final String text;
  final String preview;

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      text: json['text'] as String? ?? '',
      preview: json['preview'] as String? ?? '',
    );
  }
}
