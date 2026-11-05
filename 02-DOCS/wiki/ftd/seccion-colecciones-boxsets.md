# Sección "Colecciones" (BoxSets)

## Intent

Añadir un `LayoutSection` de colecciones que muestre los **BoxSets** de Jellyfin
(las "sagas"/franquicias) como una fila con `HomeScroll`, y dejarlo configurado
en los presets de skin (Inicio y pestaña de películas del VOD).

## Scope

- `lib/core/skin/skin_enums.dart`: valor `LayoutSectionType.boxSets`.
- `lib/core/skin/layout_section.dart`: constructor `LayoutSection.boxSets([HomeScroll?])`
  + serialización/`fromJson`.
- `lib/features/library/application/library_providers.dart`: `boxSetItemsProvider`
  (BoxSets del servidor, orden por `HomeScrollSort`, sin colecciones vacías).
- `lib/features/library/presentation/home_screen.dart`: pre-pass de backdrops + fila
  con loader, título "Colecciones", tap → `/library/{boxSetId}`.
- `lib/features/vod/presentation/vod_screen.dart`: mismo bloque para el VOD.
- `lib/core/skin/skin_presets.dart`: `_boxSetsScroll` y entrada en `homeLayout` y
  `moviesLayout`/`vodLayout` de Disney+, Prime, Netflix y Custom.
- `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`: cadena `collections`
  (autogenerada con `flutter gen-l10n`).

## Checklist

- [x] Enum + constructor + JSON (`boxSets` / `LayoutSection.boxSets`)
- [x] Provider `boxSetItemsProvider` (ordena por `HomeScrollSort`, descarta colecciones vacías)
- [x] Fila en Inicio y VOD (loader, título "Colecciones", "Ver más" a la vista BoxSets)
- [x] Tap de una colección → `/library/{boxSetId}` (grid con sus películas)
- [x] Presets: Disney+, Prime, Netflix y Custom (Inicio y layouts de películas)
- [x] Cadenas ARB `collections` (ES/EN) generadas
- [x] `flutter analyze --no-pub` limpio

## Evidence

- `flutter analyze --no-pub` → `No issues found! (ran in 5.8s)`
- `flutter gen-l10n` OK con las nuevas cadenas.
- 9 entradas `LayoutSection.boxSets(_boxSetsScroll)` repartidas entre home/vod/movies
  de los presets (Disney 2, Prime 3, Custom 2, Netflix 2).

## Next

Probar en la app: con un servidor con colecciones, la fila "Colecciones" debe aparecer
en Inicio y en la pestaña de películas; al pulsar una colección se abre el grid con sus
películas. Si un preset quiere otro aspecto, ajustar `_boxSetsScroll` (póster/backdrop,
orden, viñeta, logo…).

