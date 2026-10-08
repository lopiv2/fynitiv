# Sugerencias por estado de ánimo (Home)

## Intent
Añadir bajo el featured slider del Home una sección de botones en grid (sin
scroll lateral) con estados de ánimo. Cada botón va coloreado según el mood y,
al pulsarlo, abre el detalle de una **película o serie aleatoria** acorde al
género de ese mood.

## Scope
- In:
  - `lib/features/library/domain/mood_suggestion.dart`: modelo `MoodSuggestion`
    (labelKey, icono, color, géneros `JellyGenre`) + `kMoodSuggestions` (8).
  - `lib/features/library/application/mood_providers.dart`:
    `fetchRandomMoodItem` (getItems random por géneros, movie|series).
  - `lib/features/library/presentation/widgets/mood_suggestions_grid.dart`:
    widget reutilizable (Wrap responsive, `AppHoverButton`, loader/toast).
  - `home_screen.dart`: insertar el widget tras el featured slider (custom y
    legacy).
  - ARB EN+ES + `flutter gen-l10n`.
- Out: VOD, otros skins/plataformas, configuración por skin (siempre visible).

## Checklist
- [x] FTD antes del primer cambio
- [x] Modelo de moods + lista
- [x] Query aleatoria reutilizable
- [x] Widget grid (hover universal, loader, toast)
- [x] Integrado bajo el featured slider en Home
- [x] ARB EN+ES + `flutter gen-l10n`
- [x] `flutter analyze` limpio

## Evidence
- `lib/features/library/domain/mood_suggestion.dart`: `MoodKey`, `moodLabel`,
  `MoodSuggestion` y `kMoodSuggestions` (8 moods con icono, color y géneros
  `JellyGenre`).
- `lib/features/library/application/mood_providers.dart`: `fetchRandomMoodItem`
  (`getItems` con `includeItemTypes: [movie, series]`, `genres` con OR `|`,
  `sortBy: [random]`, `limit: 1`).
- `lib/features/library/presentation/widgets/mood_suggestions_grid.dart`:
  `MoodSuggestionsGrid` → `ScrollTitle` + `LayoutBuilder` + `Wrap` (2–4 columnas,
  sin scroll lateral) + `FocusTraversalGroup`; cada botón es `AppHover`
  (hover universal) coloreado por mood; al pulsar `EasyLoading.show` → consulta →
  `context.push('/home/details/:id')` o `EasyLoading.showInfo`.
- `home_screen.dart`: el widget se añade tras el featured slider en el layout
  custom (`case featuredSlider`) y en el legacy.
- ARB: `moodSectionTitle`, `moodAction/Comedy/Drama/Horror/SciFi/Thriller/Relax/
  Adventure`, `moodLoading`, `moodNoResults` (EN+ES) + `flutter gen-l10n`.
- `flutter analyze` → `No issues found!`.

## Next
- Probar en app: los 8 botones, que abran un título aleatorio del género, el
  loader y el toast de "sin resultados". Ajustables: moods/colores/géneros en
  `kMoodSuggestions` y columnas/altura en `MoodSuggestionsGrid`.

## Rediseño (botones glass)
- Botones más altos (68 → 132px) y texto más grande (etiqueta 21, icono 30).
- Fondo con **degradado por mood** (claro → color → oscuro) + **glassmorphism**
  (`BackdropFilter` blur 14 + velo blanco 6% + borde blanco translúcido),
  inspirado en las tarjetas de Biblioteca (`library_grid_card.dart`) pero con
  color en vez de imagen. Hover universal `AppHover` conservado.
- `flutter analyze` → `No issues found!`.


