class KbStats {
  const KbStats({
    required this.paragraphCount,
    required this.newsCount,
    required this.mediaRefs,
    required this.missingMedia,
    required this.fileCount,
    this.sources = const [],
  });

  final int paragraphCount;
  final int newsCount;
  final int mediaRefs;
  final int missingMedia;
  final int fileCount;
  final List<String> sources;

  factory KbStats.fromJson(Map<String, dynamic> json) {
    return KbStats(
      paragraphCount: json['paragraph_count'] as int? ?? 0,
      newsCount: json['news_count'] as int? ?? 0,
      mediaRefs: json['media_refs'] as int? ?? 0,
      missingMedia: json['missing_media'] as int? ?? 0,
      fileCount: json['file_count'] as int? ?? 0,
      sources: (json['sources'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }

  static const empty = KbStats(
    paragraphCount: 0,
    newsCount: 0,
    mediaRefs: 0,
    missingMedia: 0,
    fileCount: 0,
  );
}
