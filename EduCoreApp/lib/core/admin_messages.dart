import 'package:dio/dio.dart';

class AdminMessages {
  AdminMessages._();

  static String friendlyError(Object? error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final detail = error.response?.data;
      final serverMessage = _extractServerMessage(detail);

      if (status == 404) {
        return 'Serwer täzeleň. Programmany täzeden başlatyň.';
      }
      if (status == 400 && serverMessage != null) {
        return _mapServerValidation(serverMessage);
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        return 'AI serweri işlemeýär. Programmany täzeden başlatyň.';
      }
      if (serverMessage != null) return _mapServerValidation(serverMessage);
      return 'Internet ýa-da serwer bilen baglanyşyk ýok.';
    }

    final text = error?.toString() ?? '';
    if (text.contains('SocketException') || text.contains('Connection refused')) {
      return 'AI serweri işlemeýär. Programmany täzeden başlatyň.';
    }
    if (text.contains('FileNotFoundError') || text.contains('tapylmady')) {
      return 'Faýl tapylmady. Täzeden saýlaň.';
    }

    return 'Ýalňyşlyk ýüze çykdy. Täzeden synanyşyň.';
  }

  static String? _extractServerMessage(dynamic data) {
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    if (data is String && data.isNotEmpty) return data;
    return null;
  }

  static String _mapServerValidation(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('preview') || lower.contains('möhüm habar')) {
      return 'Möhüm habar üçin preview suraty saýlaň.';
    }
    if (lower.contains('boş') || lower.contains('empty')) {
      return 'Tekst boş bolup bilmez.';
    }
    if (lower.contains('ýazylmadyk') || lower.contains('unsaved')) {
      return 'Ähli abzaslar ýazylmaly. Her birini «Ýaz» basyň.';
    }
    if (lower.contains('draft') || lower.contains('tapylmady')) {
      return 'Resminama tapylmady. Täzeden import ediň.';
    }
    if (message.length > 90) {
      return 'Maglumat nädogry. Girişleri barlaň.';
    }
    return message;
  }
}
