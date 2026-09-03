import 'package:edu_core/core/app_constants.dart';
import 'package:edu_core/core/models/admin_paragraph.dart';
import 'package:edu_core/features/admin/admin_confirm_dialog.dart';
import 'package:edu_core/features/shared/developer_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('E2E-ish widget flows', () {
    testWidgets('developer footer shows developer identity without 3D avatar',
        (tester) async {
      var opened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                DeveloperFooter(onLongPress: () => opened = true),
              ],
            ),
          ),
        ),
      );

      expect(find.text(AppConstants.developerName), findsOneWidget);
      expect(find.text(AppConstants.developerEmail), findsOneWidget);
      expect(find.byIcon(Icons.school_rounded), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(opened, isFalse);
    });

    testWidgets('admin confirm dialog returns true on confirm', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await showAdminConfirmDialog(
                      context,
                      title: 'Synag',
                      message: 'Dowam edeliňmi?',
                      confirmLabel: 'Hawa',
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Synag'), findsOneWidget);
      expect(find.text('Dowam edeliňmi?'), findsOneWidget);

      await tester.tap(find.text('Hawa'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('admin confirm dialog returns false on cancel', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await showAdminConfirmDialog(
                      context,
                      title: 'Synag',
                      message: 'Ýapylsynmy?',
                      confirmLabel: 'Hawa',
                      cancelLabel: 'Ýok',
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ýok'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    test('paragraph news requires preview conceptually before save payload', () {
      final paragraph = AdminParagraph(
        index: 0,
        text: 'Habar',
        isNews: true,
      );
      expect(paragraph.isNews, isTrue);
      expect((paragraph.newsPreview ?? '').isEmpty, isTrue);
      expect(paragraph.toPayload()['news_preview'], isNull);
    });
  });
}
