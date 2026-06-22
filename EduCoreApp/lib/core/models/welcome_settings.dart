class WelcomeSettings {
  const WelcomeSettings({
    required this.title,
    required this.subtitle,
    required this.quickTags,
  });

  final String title;
  final String subtitle;
  final List<String> quickTags;

  static const defaults = WelcomeSettings(
    title: 'Hormatly talyplar we myhmanlar!',
    subtitle:
        'Institutymyz baradaky islendik soragyňyzy aşakda ýazyp bilersiňiz.',
    quickTags: [
      'TDBSI',
      'Fakultetler',
      'Kafedralar',
      'Kurslar',
      'Dersler',
      'Okuw tölegi',
      'Geçen aýyň habarlary',
      'Nyzam tertibi',
      'Sport habarlary',
      'Sosial media',
    ],
  );

  factory WelcomeSettings.fromJson(Map<String, dynamic> json) {
    final rawTags = json['quick_tags'] as List<dynamic>? ?? [];
    return WelcomeSettings(
      title: json['title'] as String? ?? defaults.title,
      subtitle: json['subtitle'] as String? ?? defaults.subtitle,
      quickTags: rawTags
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'quick_tags': quickTags,
    };
  }

  WelcomeSettings copyWith({
    String? title,
    String? subtitle,
    List<String>? quickTags,
  }) {
    return WelcomeSettings(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      quickTags: quickTags ?? List<String>.from(this.quickTags),
    );
  }
}
