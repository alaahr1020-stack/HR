import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/library.dart';
import 'monetization.dart';
import 'search.dart';

/// Decodes the content and pre-normalizes it for search. Runs in a
/// background isolate so start-up and the first search stay smooth.
Library parseLibrary(String raw) {
  final lib = Library.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  for (final d in lib.documents) {
    d.normalizedTitle = normalizeArabic(d.title);
    for (final s in d.sections) {
      s.normalized = normalizeArabic('${s.title}\n${s.body}');
    }
  }
  return lib;
}

class Favorites extends ChangeNotifier {
  static const _key = 'favorites';
  final SharedPreferences _prefs;
  late final Set<String> _ids = (_prefs.getStringList(_key) ?? []).toSet();

  Favorites(this._prefs);

  bool contains(String id) => _ids.contains(id);
  List<String> get ids => _ids.toList();

  Future<void> toggle(String id) async {
    _ids.contains(id) ? _ids.remove(id) : _ids.add(id);
    await _prefs.setStringList(_key, _ids.toList());
    notifyListeners();
  }
}

class Settings extends ChangeNotifier {
  static const _kFont = 'font_scale';
  final SharedPreferences _prefs;
  late double _fontScale = _prefs.getDouble(_kFont) ?? 1.0;

  Settings(this._prefs);

  double get fontScale => _fontScale;

  Future<void> setFontScale(double v) async {
    _fontScale = v.clamp(0.8, 1.8);
    await _prefs.setDouble(_kFont, _fontScale);
    notifyListeners();
  }
}

class AppState {
  final Library library;
  final Monetization monetization;
  final Favorites favorites;
  final Settings settings;

  AppState({
    required this.library,
    required this.monetization,
    required this.favorites,
    required this.settings,
  });

  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = await rootBundle.loadString('assets/content/library.json');
    final library = await compute(parseLibrary, raw);
    final monetization = Monetization();
    await monetization.init();
    return AppState(
      library: library,
      monetization: monetization,
      favorites: Favorites(prefs),
      settings: Settings(prefs),
    );
  }
}

class AppScope extends InheritedWidget {
  final AppState state;

  const AppScope({super.key, required this.state, required super.child});

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.state;

  @override
  bool updateShouldNotify(AppScope oldWidget) => state != oldWidget.state;
}
