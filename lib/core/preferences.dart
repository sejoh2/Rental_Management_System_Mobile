import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small choices kept on this phone: whether the intro was seen, light or
/// dark, and the property last worked on. Nothing private is kept here; the
/// sign-in session is in protected storage (SessionStore).
class AppPreferences extends ChangeNotifier {
  static const _introSeenKey = 'intro_seen';
  static const _themeKey = 'theme_mode';
  static const _propertyKey = 'selected_property_id';

  SharedPreferences? _store;

  bool introSeen = false;
  ThemeMode themeMode = ThemeMode.system;
  String? selectedPropertyId;

  Future<void> load() async {
    try {
      final store = await SharedPreferences.getInstance();

      _store = store;
      introSeen = store.getBool(_introSeenKey) ?? false;
      themeMode = switch (store.getString(_themeKey)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      selectedPropertyId = store.getString(_propertyKey);
    } catch (_) {
      // Storage that cannot be read means the defaults; the app still works.
    }
  }

  Future<void> markIntroSeen() async {
    introSeen = true;
    notifyListeners();
    await _store?.setBool(_introSeenKey, true);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    await _store?.setString(_themeKey, mode.name);
  }

  Future<void> setSelectedProperty(String? id) async {
    selectedPropertyId = id;

    if (id == null) {
      await _store?.remove(_propertyKey);
    } else {
      await _store?.setString(_propertyKey, id);
    }
  }
}
