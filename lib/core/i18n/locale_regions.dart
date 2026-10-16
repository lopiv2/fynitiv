import 'package:flutter/widgets.dart';

/// País (ISO 3166-1 alpha-2) asociado al idioma de la app, para pedir datos
/// regionales (p. ej. plataformas donde se emite un título en Seerr). Fallback:
/// España.
const _regionMap = <String, String>{
  'es': 'ES',
  'en': 'US',
  'de': 'DE',
  'fr': 'FR',
  'it': 'IT',
  'pt': 'PT',
  'nl': 'NL',
  'pl': 'PL',
  'ru': 'RU',
  'ja': 'JP',
  'ko': 'KR',
  'zh': 'CN',
  'sv': 'SE',
  'da': 'DK',
  'nb': 'NO',
  'fi': 'FI',
  'tr': 'TR',
};

String regionForLocale(Locale locale) =>
    _regionMap[locale.languageCode.toLowerCase()] ?? 'ES';
