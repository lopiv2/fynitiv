/// Utilidades para normalizar idiomas de subtítulos al formato que espera
/// Jellyfin (ISO 639-2/B de 3 letras, p. ej. `spa`, `eng`, `fre`) y para
/// mostrar nombres legibles en la UI.
library;

/// Lengua soportada en el selector de búsqueda de subtítulos.
class SubtitleLanguage {
  const SubtitleLanguage(this.code, this.name);

  /// Código ISO 639-2/B (3 letras).
  final String code;

  /// Nombre en inglés (coherente con el resto de la app).
  final String name;
}

/// Lista curada de idiomas habituales para el selector. Se usa como respaldo
/// cuando el contenido no aporta idiomas utilizables.
const List<SubtitleLanguage> kSubtitleLanguages = [
  SubtitleLanguage('spa', 'Spanish'),
  SubtitleLanguage('eng', 'English'),
  SubtitleLanguage('fre', 'French'),
  SubtitleLanguage('ger', 'German'),
  SubtitleLanguage('ita', 'Italian'),
  SubtitleLanguage('por', 'Portuguese'),
  SubtitleLanguage('dut', 'Dutch'),
  SubtitleLanguage('rus', 'Russian'),
  SubtitleLanguage('jpn', 'Japanese'),
  SubtitleLanguage('chi', 'Chinese'),
  SubtitleLanguage('kor', 'Korean'),
  SubtitleLanguage('ara', 'Arabic'),
  SubtitleLanguage('hin', 'Hindi'),
  SubtitleLanguage('tur', 'Turkish'),
  SubtitleLanguage('pol', 'Polish'),
  SubtitleLanguage('swe', 'Swedish'),
  SubtitleLanguage('nor', 'Norwegian'),
  SubtitleLanguage('dan', 'Danish'),
  SubtitleLanguage('fin', 'Finnish'),
  SubtitleLanguage('gre', 'Greek'),
  SubtitleLanguage('cze', 'Czech'),
  SubtitleLanguage('slo', 'Slovak'),
  SubtitleLanguage('hun', 'Hungarian'),
  SubtitleLanguage('rum', 'Romanian'),
  SubtitleLanguage('ukr', 'Ukrainian'),
  SubtitleLanguage('vie', 'Vietnamese'),
  SubtitleLanguage('tha', 'Thai'),
  SubtitleLanguage('ind', 'Indonesian'),
  SubtitleLanguage('may', 'Malay'),
  SubtitleLanguage('heb', 'Hebrew'),
  SubtitleLanguage('cat', 'Catalan'),
  SubtitleLanguage('glg', 'Galician'),
  SubtitleLanguage('baq', 'Basque'),
  SubtitleLanguage('per', 'Persian'),
];

/// Idiomas ISO 639-2/T -> 639-2/B (convención usada por Jellyfin).
const Map<String, String> _isoTtoB = {
  'deu': 'ger',
  'fra': 'fre',
  'nld': 'dut',
  'ces': 'cze',
  'ron': 'rum',
  'slk': 'slo',
  'ell': 'gre',
  'zho': 'chi',
  'fas': 'per',
  'eus': 'baq',
  'mri': 'mao',
  'mya': 'bur',
  'kat': 'geo',
  'isl': 'ice',
  'mkd': 'mac',
  'sqi': 'alb',
  'hye': 'arm',
};

/// Códigos de 2 letras (ISO 639-1) -> 639-2/B.
const Map<String, String> _iso2to3 = {
  'es': 'spa',
  'en': 'eng',
  'fr': 'fre',
  'de': 'ger',
  'it': 'ita',
  'pt': 'por',
  'nl': 'dut',
  'ru': 'rus',
  'ja': 'jpn',
  'zh': 'chi',
  'ko': 'kor',
  'ar': 'ara',
  'hi': 'hin',
  'tr': 'tur',
  'pl': 'pol',
  'sv': 'swe',
  'no': 'nor',
  'nb': 'nor',
  'nn': 'nor',
  'da': 'dan',
  'fi': 'fin',
  'el': 'gre',
  'cs': 'cze',
  'sk': 'slo',
  'hu': 'hun',
  'ro': 'rum',
  'uk': 'ukr',
  'vi': 'vie',
  'th': 'tha',
  'id': 'ind',
  'ms': 'may',
  'he': 'heb',
  'ca': 'cat',
  'gl': 'glg',
  'eu': 'baq',
  'fa': 'per',
};

/// Normaliza un idioma (código de 2/3 letras o nombre en inglés) al formato
/// ISO 639-2/B de 3 letras que espera Jellyfin. Devuelve cadena vacía si no
/// se puede reconocer.
String normalizeToIso639_2(String? value) {
  if (value == null) return '';
  final raw = value.trim().toLowerCase();
  if (raw.isEmpty) return '';

  if (raw.length == 2) return _iso2to3[raw] ?? '';

  // Códigos tipo `es-ES` / `en-US`: nos quedamos con la parte principal.
  final base = raw.split(RegExp(r'[-_]')).first;
  if (base.length == 2) return _iso2to3[base] ?? '';
  if (base.length == 3) return _isoTtoB[base] ?? base;

  for (final lang in kSubtitleLanguages) {
    if (lang.name.toLowerCase() == raw) return lang.code;
  }
  return '';
}

/// Nombre legible para un código de idioma (2 o 3 letras).
String subtitleLanguageLabel(String? code) {
  final normalized = normalizeToIso639_2(code);
  if (normalized.isEmpty) return code?.trim() ?? '';
  for (final lang in kSubtitleLanguages) {
    if (lang.code == normalized) return lang.name;
  }
  return normalized;
}
