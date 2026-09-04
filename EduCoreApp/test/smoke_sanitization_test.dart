import 'package:edu_core/core/admin_messages.dart';
import 'package:edu_core/core/app_constants.dart';
import 'package:edu_core/core/models/admin_paragraph.dart';
import 'package:edu_core/core/models/news_item.dart';
import 'package:edu_core/core/models/welcome_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Smoke — core constants and models', () {
    test('app constants expose required media extensions', () {
      expect(AppConstants.appDisplayName, 'Bilim Çeşmesi');
      expect(AppConstants.apiBaseUrl, contains('127.0.0.1'));
      expect(AppConstants.maxNewsItems, 15);
      expect(AppConstants.allowedDocumentExtensions, containsAll(['docx', 'xlsx']));
      expect(AppConstants.allowedImageExtensions, isNotEmpty);
      expect(AppConstants.allowedVideoExtensions, isNotEmpty);
      expect(AppConstants.allowedAudioExtensions, containsAll(['mp3', 'wav']));
      expect(
        AppConstants.allowedUploadExtensions,
        containsAll(AppConstants.allowedAudioExtensions),
      );
    });

    test('AdminParagraph round-trips payload with audio', () {
      final paragraph = AdminParagraph(
        index: 0,
        text: 'Salam',
        images: const ['a.jpg'],
        videos: const ['b.mp4'],
        audios: const ['c.mp3'],
        isNews: true,
        newsPreview: 'preview.png',
        newsOrder: 2,
        isSaved: true,
      );

      final payload = paragraph.toPayload();
      expect(payload['audios'], ['c.mp3']);
      expect(payload['is_news'], isTrue);
      expect(payload['news_preview'], 'preview.png');
      expect(payload['news_order'], 2);

      final restored = AdminParagraph.fromJson({
        'index': 2,
        'text': payload['text'],
        'images': payload['images'],
        'videos': payload['videos'],
        'audios': payload['audios'],
        'is_news': payload['is_news'],
        'news_preview': payload['news_preview'],
        'news_order': payload['news_order'],
        'is_saved': true,
      });

      expect(restored.audios, ['c.mp3']);
      expect(restored.isNews, isTrue);
      expect(restored.newsOrder, 2);
      expect(restored.copyWith(clearNewsPreview: true).newsPreview, isNull);

      final fromStringOrder = AdminParagraph.fromJson({
        'index': '4',
        'text': 'x',
        'news_order': '7',
        'is_news': false,
      });
      expect(fromStringOrder.index, 4);
      expect(fromStringOrder.newsOrder, 7);
    });

    test('NewsItem parses empty-safe json', () {
      final item = NewsItem.fromJson({});
      expect(item.text, isEmpty);
      expect(item.preview, isEmpty);
    });

    test('WelcomeSettings defaults are non-empty', () {
      final defaults = WelcomeSettings.defaults;
      expect(defaults.title.trim(), isNotEmpty);
      expect(defaults.subtitle.trim(), isNotEmpty);
      expect(defaults.quickTags, isNotEmpty);
    });
  });

  group('Sanitization — admin error messages', () {
    test('connection errors become short actionable messages', () {
      final message = AdminMessages.friendlyError(
        Exception('SocketException: Connection refused'),
      );
      expect(message.length, lessThan(90));
      expect(message.toLowerCase(), contains('serwer'));
      expect(message, isNot(contains('SocketException')));
    });

    test('long server messages are shortened', () {
      final long = 'x' * 200;
      final message = AdminMessages.friendlyError(
        Exception(long),
      );
      expect(message.length, lessThan(120));
    });

    test('preview validation maps to clear turkmen text', () {
      // Simulate mapped validation via internal path using Dio-like detail text
      // through Exception that contains known keywords is not mapped unless Dio;
      // ensure mapping helper path via known short message fallback stays short.
      final message = AdminMessages.friendlyError('FileNotFoundError: tapylmady');
      expect(message, contains('Faýl'));
      expect(message.length, lessThan(80));
    });
  });
}
