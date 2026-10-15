import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/locale_provider.dart';
import '../../../core/settings/tmdb_key_controller.dart';
import '../../../core/skin/layout_section.dart';
import '../data/tmdb_api.dart';
import '../domain/tmdb_models.dart';

/// Idioma (formato TMDB `xx-XX`) y país para disponibilidad, derivados del
/// locale de la app. Fallback: España.
const _localeMap = <String, ({String language, String region})>{
  'es': (language: 'es-ES', region: 'ES'),
  'en': (language: 'en-US', region: 'US'),
  'de': (language: 'de-DE', region: 'DE'),
  'fr': (language: 'fr-FR', region: 'FR'),
  'it': (language: 'it-IT', region: 'IT'),
  'pt': (language: 'pt-PT', region: 'PT'),
  'nl': (language: 'nl-NL', region: 'NL'),
  'pl': (language: 'pl-PL', region: 'PL'),
  'ru': (language: 'ru-RU', region: 'RU'),
  'ja': (language: 'ja-JP', region: 'JP'),
  'ko': (language: 'ko-KR', region: 'KR'),
  'zh': (language: 'zh-CN', region: 'CN'),
  'sv': (language: 'sv-SE', region: 'SE'),
  'da': (language: 'da-DK', region: 'DK'),
  'nb': (language: 'nb-NO', region: 'NO'),
  'fi': (language: 'fi-FI', region: 'FI'),
  'tr': (language: 'tr-TR', region: 'TR'),
};

({String language, String region}) tmdbLocaleFor(Locale locale) {
  return _localeMap[locale.languageCode.toLowerCase()] ?? _localeMap['es']!;
}

String? _readKey(Ref ref) {
  final key = ref.watch(tmdbKeyProvider).value;
  return (key == null || key.isEmpty) ? null : key;
}

/// Fila de Novedades (trending mixto o estrenos próximos).
final tmdbNovedadesProvider =
    FutureProvider.family<List<TmdbTitle>, TmdbNoveltySource>((ref, source) async {
      final key = _readKey(ref);
      if (key == null) return const [];
      final locale = ref.watch(localeProvider).value ?? const Locale('es');
      final loc = tmdbLocaleFor(locale);
      final api = TmdbApi(key);
      switch (source) {
        case TmdbNoveltySource.trending:
          return api.trending(language: loc.language);
        case TmdbNoveltySource.upcoming:
          return api.upcoming(language: loc.language, region: loc.region);
      }
    });

/// Referencia a un título TMDB (familia).
typedef TmdbRef = ({TmdbMediaType mediaType, int id});

/// Ficha completa de un título TMDB.
final tmdbDetailProvider = FutureProvider.family<TmdbDetail, TmdbRef>((
  ref,
  refKey,
) async {
  final key = _readKey(ref);
  if (key == null) throw StateError('tmdb-no-key');
  final locale = ref.watch(localeProvider).value ?? const Locale('es');
  final loc = tmdbLocaleFor(locale);
  return TmdbApi(key).detail(
    mediaType: refKey.mediaType,
    id: refKey.id,
    language: loc.language,
  );
});

/// Proveedores de streaming/alquiler/compra para un título y región.
final tmdbWatchProvidersProvider =
    FutureProvider.family<TmdbWatchAvailability, TmdbRef>((ref, refKey) async {
      final key = _readKey(ref);
      if (key == null) return const TmdbWatchAvailability();
      final locale = ref.watch(localeProvider).value ?? const Locale('es');
      final loc = tmdbLocaleFor(locale);
      return TmdbApi(key).watchProviders(
        mediaType: refKey.mediaType,
        id: refKey.id,
        region: loc.region,
      );
    });
