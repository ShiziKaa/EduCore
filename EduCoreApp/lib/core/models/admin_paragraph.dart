class AdminParagraph {
  AdminParagraph({
    required this.index,
    required this.text,
    this.images = const [],
    this.videos = const [],
    this.audios = const [],
    this.isNews = false,
    this.newsPreview,
    this.isSaved = false,
  });

  final int index;
  String text;
  List<String> images;
  List<String> videos;
  List<String> audios;
  bool isNews;
  String? newsPreview;
  bool isSaved;

  factory AdminParagraph.fromJson(Map<String, dynamic> json) {
    return AdminParagraph(
      index: json['index'] as int? ?? 0,
      text: json['text'] as String? ?? '',
      images: (json['images'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      videos: (json['videos'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      audios: (json['audios'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      isNews: json['is_news'] as bool? ?? false,
      newsPreview: json['news_preview'] as String?,
      isSaved: json['is_saved'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'text': text,
      'images': images,
      'videos': videos,
      'audios': audios,
      'is_news': isNews,
      'news_preview': newsPreview,
    };
  }

  AdminParagraph copyWith({
    String? text,
    List<String>? images,
    List<String>? videos,
    List<String>? audios,
    bool? isNews,
    String? newsPreview,
    bool? isSaved,
    bool clearNewsPreview = false,
  }) {
    return AdminParagraph(
      index: index,
      text: text ?? this.text,
      images: images ?? List<String>.from(this.images),
      videos: videos ?? List<String>.from(this.videos),
      audios: audios ?? List<String>.from(this.audios),
      isNews: isNews ?? this.isNews,
      newsPreview: clearNewsPreview ? null : (newsPreview ?? this.newsPreview),
      isSaved: isSaved ?? this.isSaved,
    );
  }
}
