# Jukebox — Resultados + Biblioteca (+Recientes) + Listas al player

## Intent
Corregir que `Recientes` se filtraba por `search` (`jukeboxGamesProvider(search)` en `_RecientesSection`) y redistribuir la Jukebox en 3 zonas claras acordadas con el usuario: `Listas de reproducción` solo al player, `Biblioteca` navega (absorbe chips y añade `Recientes` + huecos faltantes), `Resultados` es el único pane que muestra resultados de búsqueda **o** facet sin filtrar (al tocar Biblioteca se borra el texto y prima Biblioteca). Chips eliminados.

## Scope
- In: FTD previo; nuevo `jukeboxRecentGamesProvider` sin `search` para la card `Recientes` dentro de `Biblioteca`; `JukeboxUiState` limpia `search` al pulsar Biblioteca (`selectGame`/`selectFacet`/`setTab`); `jukebox_screen.dart` renombra `_RecientesSection→_ResultadosSection` (dos sitios wide/narrow), amplía `_LibraryRow` con cards faltantes de chips (`Juegos`, `Años` y resto para paridad), borra `_TabChips`/`_tabs` y branch `search.isNotEmpty ? resultados búsqueda : facet sin filtrar`, wiring tap facet→derecha (`_RightLateralPanel`/`_InlineTrackPane`); `_MixesRow` queda solo `play*`; `RommRepository.getMusicGames` opcional `orderBy`; ARB `jukeboxResults` ES+EN + `gen-l10n`; focus TV en nuevos scrolls.
- Out: CRUD `/music/playlists` v2, covers embebidas, ecualizador.

## Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] `jukeboxRecentGamesProvider` sin `search` + `jukeboxUiState` borra `search` en `select*`/`setTab` — `flutter analyze` sin issues
- [x] `_RecientesSection` → `_ResultadosSection` con rama búsqueda vs facet sin filtrar — `flutter analyze` sin issues
- [x] `_LibraryRow` ampliado con cards faltantes de chips + card `Recientes` movida a Biblioteca — `flutter analyze` sin issues
- [x] Wiring tap `Resultados` → panel derecho (pistas del facet/juego) — `flutter analyze` sin issues
- [x] Chips eliminados (`_TabChips`/`_tabs`) — `flutter analyze` sin issues
- [x] ARB EN+ES + `gen-l10n` — reutiliza claves existentes, no requiere nuevas

## Evidence
- Bug origen: `jukebox_screen.dart:1693` `ref.watch(jukeboxGamesProvider(search))` en `_RecientesSection` (ahora `_ResultadosSection:1693` desacoplado).
- Nuevo provider: `jukebox_providers.dart:92` `jukeboxGamesProvider(search)` + `jukebox_providers.dart:100` `jukeboxRecentGamesProvider` sin `search` para card Recientes en Biblioteca.
- Estado: `jukebox_ui_state.dart:40` `setTab`/`selectGame`/`selectFacet` borran `search` y `ref.listen` en `jukebox_screen.dart:290` sincroniza `TextEditingController`.
- Pantalla: `jukebox_screen.dart:706` `_LibraryRow` con `Juegos/Años/Recientes` + `FocusTraversalGroup`, `jukebox_screen.dart:1693` `_ResultadosSection` con rama `isSearching ? juegos filtrados : facet sin filtrar`, chips eliminados `jukebox_screen.dart:1025`.
- `flutter analyze` → "No issues found!" (14.8s → 5.7s tras fix lint `unnecessary_brace_in_string_interps`).
- `flutter gen-l10n` no requerido (reuso `jukeboxGames/jukeboxArtists/...`).

## Next
Validar en runtime contra ROMM 5.3 (`Recientes` por fecha con `orderBy: 'added'` vs `limit:6`) y decidir si `Recientes` dentro de Biblioteca duplica Listas o se queda solo en Listas.
