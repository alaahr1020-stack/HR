import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_guide/main.dart';
import 'package:hr_guide/models/library.dart';
import 'package:hr_guide/services/app_state.dart';
import 'package:hr_guide/services/monetization.dart';
import 'package:hr_guide/services/search.dart';
import 'package:shared_preferences/shared_preferences.dart';

Library loadLibrary() =>
    parseLibrary(File('assets/content/library.json').readAsStringSync());

void main() {
  test('content file is valid and every document has a known category', () {
    final lib = loadLibrary();
    expect(lib.documents, isNotEmpty);
    for (final d in lib.documents) {
      expect(lib.category(d.categoryId), isNotNull, reason: d.title);
      if (d.file != null) {
        expect(File('assets/${d.file}').existsSync(), isTrue, reason: d.file);
      }
    }
  });

  test('Arabic normalization ignores hamza, ta marbuta and diacritics', () {
    expect(normalizeArabic('إجَازَة'), normalizeArabic('اجازه'));
    expect(normalizeArabic('مادة ١٥'), 'ماده 15');
  });

  test('search finds sections regardless of letter variants', () {
    final lib = loadLibrary();
    final hits = search(lib, 'انذار');
    expect(hits.map((h) => h.document.title), contains('خطاب الإنذار'));
    final law = lib.documents.firstWhere((d) => d.title.contains('14 لسنة 2025'));
    expect(searchInDocument(law, 'مادة (79)'), isNotEmpty);
    expect(search(lib, '   '), isEmpty);
  });

  testWidgets('home shows categories and opens a document', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(
      library: loadLibrary(),
      monetization: Monetization(),
      favorites: Favorites(prefs),
      settings: Settings(prefs),
    );
    await tester.pumpWidget(HrGuideApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('التشريعات والقرارات'), findsOneWidget);
    expect(find.textContaining('فترة تجريبية'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('نماذج الموارد البشرية'), 100);
    await tester.tap(find.text('نماذج الموارد البشرية'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('الإجازات وتذاكر السفر'), 200);
    await tester.tap(find.text('الإجازات وتذاكر السفر'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('طلب الإجازة – بدون مرتب'));
    await tester.pumpAndSettle();
    expect(find.text('حفظ / مشاركة النموذج (Word)'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pump();
    expect(state.favorites.ids, hasLength(1));
  });
}
