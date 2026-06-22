import 'admin_paragraph.dart';

class AdminDraft {
  AdminDraft({
    required this.id,
    required this.sourceFilename,
    required this.outputFilename,
    required this.paragraphs,
  });

  final String id;
  final String sourceFilename;
  final String outputFilename;
  final List<AdminParagraph> paragraphs;

  factory AdminDraft.fromJson(Map<String, dynamic> json) {
    return AdminDraft(
      id: json['id'] as String? ?? '',
      sourceFilename: json['source_filename'] as String? ?? '',
      outputFilename: json['output_filename'] as String? ?? '',
      paragraphs: (json['paragraphs'] as List<dynamic>? ?? [])
          .map((item) => AdminParagraph.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
