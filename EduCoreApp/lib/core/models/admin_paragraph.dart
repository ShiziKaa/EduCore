class AdminParagraph {
  AdminParagraph({
    required this.index,
    required this.text,
    this.source,
    this.images = const [],
    this.videos = const [],
    this.audios = const [],
    this.isNews = false,
    this.newsPreview,
    this.newsOrder,
    this.missingMedia = const [],
    this.isSaved = false,
  });

  int index;
  String text;
  String? source;
  List<String> images;
  List<String> videos;
  List<String> audios;
  bool isNews;
  String? newsPreview;
  int? newsOrder;
  List<String> missingMedia;
  bool isSaved;

  factory AdminParagraph.fromJson(Map<String, dynamic> json) {
    return AdminParagraph(
      index: _asInt(json['index']) ?? 0,
      text: json['text'] as String? ?? '',
      source: json['source'] as String?,
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
      newsOrder: _asInt(json['news_order']),
      missingMedia: (json['missing_media'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      isSaved: json['is_saved'] as bool? ?? false,
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  Map<String, dynamic> toPayload() {
    return {
      'text': text,
      'images': images,
      'videos': videos,
      'audios': audios,
      'is_news': isNews,
      'news_preview': newsPreview,
      'news_order': newsOrder,
    };
  }

  Map<String, dynamic> toKbPayload() {
    return {
      'source': source ?? '',
      'index': index,
      ...toPayload(),
    };
  }

  AdminParagraph copyWith({
    int? index,
    String? text,
    String? source,
    List<String>? images,
    List<String>? videos,
    List<String>? audios,
    bool? isNews,
    String? newsPreview,
    int? newsOrder,
    List<String>? missingMedia,
    bool? isSaved,
    bool clearNewsPreview = false,
    bool clearNewsOrder = false,
  }) {
    return AdminParagraph(
      index: index ?? this.index,
      text: text ?? this.text,
      source: source ?? this.source,
      images: images ?? List<String>.from(this.images),
      videos: videos ?? List<String>.from(this.videos),
      audios: audios ?? List<String>.from(this.audios),
      isNews: isNews ?? this.isNews,
      newsPreview: clearNewsPreview ? null : (newsPreview ?? this.newsPreview),
      newsOrder: clearNewsOrder ? null : (newsOrder ?? this.newsOrder),
      missingMedia: missingMedia ?? List<String>.from(this.missingMedia),
      isSaved: isSaved ?? this.isSaved,
    );
  }
}
