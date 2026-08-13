import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'jellyfin.locale';

/// Idiomas soportados por la app.
const supportedLocales = [Locale('es'), Locale('en')];

/// Locale actual de la app (persistido).
class LocaleNotifier extends AsyncNotifier<Locale> {
  @override
  Future<Locale> build() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kLocaleKey);
    return _localeFromName(name);
  }

  Locale _localeFromName(String? name) {
    switch (name) {
      case 'en':
        return const Locale('en');
      case 'es':
        return const Locale('es');
      default:
        return const Locale('es');
    }
  }

  /// Cambia el idioma y lo persiste.
  Future<void> setLocale(Locale locale) async {
    state = AsyncData(locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, locale.languageCode);
  }
}

final localeProvider =
    AsyncNotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
