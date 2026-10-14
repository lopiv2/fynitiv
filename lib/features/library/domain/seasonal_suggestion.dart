import '../../../core/seasonal/seasonal_event.dart';
import '../../../l10n/app_localizations.dart';

// El evento y su detección viven en `core/seasonal` porque también los usa el
// teñido estacional del skin. Se reexportan para los consumidores de la fila.
export '../../../core/seasonal/seasonal_event.dart'
    show SeasonalEvent, seasonalEventForDate;

/// Términos de búsqueda (nombre/descripción) que identifican la temática.
/// Cubren español e inglés; pueden no encontrar nada aunque haya contenido
/// acorde, por eso se combinan con [seasonalEventGenres].
List<String> seasonalEventSearchTerms(SeasonalEvent event) => switch (event) {
  SeasonalEvent.halloween => const ['Halloween', 'Noche de brujas'],
  SeasonalEvent.christmas => const ['Christmas', 'Navidad'],
  SeasonalEvent.valentinesDay => const ["Valentine's Day", 'San Valentín'],
  SeasonalEvent.easter => const ['Easter', 'Pascua'],
};

/// Géneros (nombres exactos de la API) asociados a la temática. Es el filtro
/// que garantiza resultados cuando la biblioteca no tiene títulos con el
/// nombre explícito de la fecha. Se usan cadenas para poder cubrir variantes
/// de bibliotecas en inglés y español (p. ej. "Horror" y "Terror").
List<String> seasonalEventGenres(SeasonalEvent event) => switch (event) {
  // Halloween: terror/suspense, sin acción.
  SeasonalEvent.halloween => const ['Horror', 'Terror', 'Suspense'],
  SeasonalEvent.christmas => const ['Family', 'Kids', 'Animation'],
  SeasonalEvent.valentinesDay => const ['Romance', 'Drama', 'Comedy'],
  SeasonalEvent.easter => const ['Family', 'Adventure', 'Animation'],
};

/// Título localizado de la temática activa.
String seasonalEventTitle(AppLocalizations l10n, SeasonalEvent event) =>
    switch (event) {
      SeasonalEvent.halloween => l10n.seasonalHalloween,
      SeasonalEvent.christmas => l10n.seasonalChristmas,
      SeasonalEvent.valentinesDay => l10n.seasonalValentinesDay,
      SeasonalEvent.easter => l10n.seasonalEaster,
    };
