import 'app_localizations.dart';
import '../core/skin/home_scroll.dart';

/// Traduce un género tal como lo entrega Jellyfin al idioma activo.
///
/// Los servidores Jellyfin suelen exponer los géneros en inglés
/// (`Action`, `Science Fiction`, `Sci-Fi & Fantasy`...). Normalizamos el valor
/// (minúsculas, sin acentos, espacios colapsados) y lo resolvemos contra las
/// variantes conocidas (inglés y español). Si no lo reconocemos devolvemos el
/// valor original para no perder información.
String localizeGenre(String? raw, AppLocalizations l10n) {
  final original = raw?.trim() ?? '';
  if (original.isEmpty) return '';
  final resolver = _resolvers[_normalize(original)];
  return resolver?.call(l10n) ?? original;
}

/// Aplica [localizeGenre] a una lista de géneros.
List<String> localizeGenres(Iterable<String> genres, AppLocalizations l10n) =>
    genres.map((g) => localizeGenre(g, l10n)).toList();

String _normalize(String value) {
  final lower = value.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_diacritics[ch] ?? ch);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
}

const Map<String, String> _diacritics = {
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'ã': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'õ': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ñ': 'n',
  'ç': 'c',
};

final Map<String, String Function(AppLocalizations)> _resolvers = {
  'action': (l) => l.genreAction,
  'accion': (l) => l.genreAction,
  'adventure': (l) => l.genreAdventure,
  'aventura': (l) => l.genreAdventure,
  'action & adventure': (l) => l.genreActionAdventure,
  'action and adventure': (l) => l.genreActionAdventure,
  'accion y aventura': (l) => l.genreActionAdventure,
  'accion y aventuras': (l) => l.genreActionAdventure,
  'animation': (l) => l.genreAnimation,
  'animacion': (l) => l.genreAnimation,
  'anime': (l) => l.genreAnime,
  'biography': (l) => l.genreBiography,
  'biografia': (l) => l.genreBiography,
  'comedy': (l) => l.genreComedy,
  'comedia': (l) => l.genreComedy,
  'crime': (l) => l.genreCrime,
  'crimen': (l) => l.genreCrime,
  'documentary': (l) => l.genreDocumentary,
  'documental': (l) => l.genreDocumentary,
  'drama': (l) => l.genreDrama,
  'family': (l) => l.genreFamily,
  'familia': (l) => l.genreFamily,
  'fantasy': (l) => l.genreFantasy,
  'fantasia': (l) => l.genreFantasy,
  'history': (l) => l.genreHistory,
  'historia': (l) => l.genreHistory,
  'horror': (l) => l.genreHorror,
  'terror': (l) => l.genreHorror,
  'kids': (l) => l.genreKids,
  'infantil': (l) => l.genreKids,
  'music': (l) => l.genreMusic,
  'musica': (l) => l.genreMusic,
  'musical': (l) => l.genreMusical,
  'mystery': (l) => l.genreMystery,
  'misterio': (l) => l.genreMystery,
  'news': (l) => l.genreNews,
  'noticias': (l) => l.genreNews,
  'reality': (l) => l.genreReality,
  'telerrealidad': (l) => l.genreReality,
  'romance': (l) => l.genreRomance,
  'science fiction': (l) => l.genreScienceFiction,
  'ciencia ficcion': (l) => l.genreScienceFiction,
  'sci-fi': (l) => l.genreScienceFiction,
  'sci fi': (l) => l.genreScienceFiction,
  'scifi': (l) => l.genreScienceFiction,
  'sci-fi & fantasy': (l) => l.genreSciFiFantasy,
  'sci fi & fantasy': (l) => l.genreSciFiFantasy,
  'ciencia ficcion y fantasia': (l) => l.genreSciFiFantasy,
  'soap': (l) => l.genreSoap,
  'telenovela': (l) => l.genreSoap,
  'short': (l) => l.genreShort,
  'cortometraje': (l) => l.genreShort,
  'sport': (l) => l.genreSport,
  'deportes': (l) => l.genreSport,
  'deporte': (l) => l.genreSport,
  'superhero': (l) => l.genreSuperhero,
  'superheroe': (l) => l.genreSuperhero,
  'superheroes': (l) => l.genreSuperhero,
  'superheroinas': (l) => l.genreSuperhero,
  'talk show': (l) => l.genreTalkShow,
  'programa de entrevistas': (l) => l.genreTalkShow,
  'thriller': (l) => l.genreThriller,
  'suspense': (l) => l.genreThriller,
  'tv movie': (l) => l.genreTvMovie,
  'pelicula de tv': (l) => l.genreTvMovie,
  'war': (l) => l.genreWar,
  'guerra': (l) => l.genreWar,
  'war & politics': (l) => l.genreWarPolitics,
  'guerra y politica': (l) => l.genreWarPolitics,
  'western': (l) => l.genreWestern,
  'adult': (l) => l.genreAdult,
  'adultos': (l) => l.genreAdult,
};

/// Traduce un [JellyGenre] (valor exacto de la API de Jellyfin) al idioma
/// activo usando las cadenas ARB (`genre*`). Cubre los 22 valores sin pasar
/// por cadenas intermedias; si el enum crece, el `switch` obliga a añadir la
/// traducción correspondiente.
String localizeJellyGenre(JellyGenre genre, AppLocalizations l10n) {
  switch (genre) {
    case JellyGenre.action:
      return l10n.genreAction;
    case JellyGenre.adventure:
      return l10n.genreAdventure;
    case JellyGenre.animation:
      return l10n.genreAnimation;
    case JellyGenre.anime:
      return l10n.genreAnime;
    case JellyGenre.biography:
      return l10n.genreBiography;
    case JellyGenre.comedy:
      return l10n.genreComedy;
    case JellyGenre.crime:
      return l10n.genreCrime;
    case JellyGenre.documentary:
      return l10n.genreDocumentary;
    case JellyGenre.drama:
      return l10n.genreDrama;
    case JellyGenre.family:
      return l10n.genreFamily;
    case JellyGenre.fantasy:
      return l10n.genreFantasy;
    case JellyGenre.history:
      return l10n.genreHistory;
    case JellyGenre.horror:
      return l10n.genreHorror;
    case JellyGenre.kids:
      return l10n.genreKids;
    case JellyGenre.music:
      return l10n.genreMusic;
    case JellyGenre.musical:
      return l10n.genreMusical;
    case JellyGenre.mystery:
      return l10n.genreMystery;
    case JellyGenre.reality:
      return l10n.genreReality;
    case JellyGenre.romance:
      return l10n.genreRomance;
    case JellyGenre.sciFi:
      return l10n.genreScienceFiction;
    case JellyGenre.short:
      return l10n.genreShort;
    case JellyGenre.sport:
      return l10n.genreSport;
    case JellyGenre.superhero:
      return l10n.genreSuperhero;
    case JellyGenre.suspense:
      return l10n.genreThriller;
    case JellyGenre.thriller:
      return l10n.genreThriller;
    case JellyGenre.war:
      return l10n.genreWar;
    case JellyGenre.western:
      return l10n.genreWestern;
  }
}
