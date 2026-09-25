import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_guide/main.dart';
import 'package:hr_guide/models/library.dart';
import 'package:hr_guide/services/app_state.dart';
import 'package:hr_guide/services/monetization.dart';
import 'package:hr_guide/services/search.dart';
import 'package:shared_preferences/shared_preferences.dart';

Library loadLibrary() => Library.fromJson(jsonDecode(
        File('assets/content/library.json').readAsStringSync())
    as Map<String, dynamic>);

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
    expect(hits.map((h) => h.document.title), contains('نموذج إنذار كتابي'));
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

    expect(find.text('لائحة الجزاءات'), findsOneWidget);
    expect(find.textContaining('فترة تجريبية'), findsOneWidget);

    await tester.tap(find.text('نماذج الموارد البشرية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('نموذج طلب إجازة'));
    await tester.pumpAndSettle();
    expect(find.text('حفظ / مشاركة النموذج (Word)'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pump();
    expect(state.favorites.ids, hasLength(1));
  });
}
