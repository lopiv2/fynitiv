# Franquicias curadas (JSON + Seerr)

## Intent

Mostrar sagas/franquicias con un **orden TMDB curado** (que los BoxSets de Jellyfin no
garantizan), cruzando los `tmdbId` del catálogo con la biblioteca por `ProviderIds.Tmdb`.
Hub de franquicias + pantalla de detalle; lo que falta se puede pedir a Seerr.

## Scope

- `assets/data/franchises.json` + `pubspec.yaml`: catálogo curado y campo `logo`
  (asset local) por franquicia.
- `assets/images/franchises/`: logos locales. `Harry-Potter.jpg` (fondo blanco)
  se convirtió a `Harry-Potter.png` con transparencia para poder apilarlo.
- `lib/features/franchises/domain/curated_franchise.dart`: modelos + parser
  (`logo`).
- `lib/features/franchises/application/franchise_providers.dart`: catálogo,
  índice TMDB de la biblioteca, entradas por franquicia (orden curado) y hub.
  - Imagen del hub: carátula de la primera película que tengas; si no tienes
    ninguna, la de la primera de Seerr; si no, la del JSON.
  - `logo`: asset de la franquicia.
- `lib/features/library/presentation/widgets/content_row.dart`,
  `poster_card.dart` y `backdrop_card.dart`: `stackLogoFor`/`stackLogo` para
  superponer un logo custom (asset/URL/SVG) sobre la imagen de la tarjeta.
- `home_screen.dart`: la fila de franquicias pasa `stackLogoFor` y usa
  `logoPosition`/`logoSize` del scroll (centro, 72 por defecto).
- `skin_presets.dart`: `_franchisesScroll` con `showLogo: true`,
  `logoPosition: center`, `logoSize: 72`.
- `lib/features/franchises/presentation/franchise_screen.dart`: detalle con grid.
- `lib/core/skin/skin_enums.dart` + `layout_section.dart`: `LayoutSectionType.franchises`.
- `lib/router/app_router.dart`: `/franchises/:id`.
- ARB: `franchises`, `franchiseProgress`, `notInLibrary`.

## Checklist

- [x] Catálogo JSON + asset (MCU Infinity Saga 23, Star Wars 9, Harry Potter 8, Fast & Furious 10, LOTR 3)
- [x] Modelo/parser
- [x] Providers (índice TMDB cacheado, entries con orden curado y faltantes, hub)
- [x] Imagen de una película + logo de la franquicia apilado
- [x] Logos locales en `assets/images/franchises/` y Harry Potter con transparencia
- [x] Sección `franchises` + fila hub en Inicio/VOD
- [x] Pantalla de franquicia (`/franchises/:id`) con grid y faltantes pedibles
- [x] Presets: `boxSets` sustituido por `franchises` (9 entradas)
- [x] ARB (`franchises`, `franchiseProgress`, `notInLibrary`) + gen-l10n
- [x] `flutter analyze --no-pub` limpio

## Evidence

- `flutter analyze --no-pub` → `No issues found! (ran in 10.1s)`
- `assets/data/franchises.json` validado: 5 franquicias con `logo` existente.
- Tarjeta de franquicia: carátula de una película + logo centrado encima.

## Next

Probar en la app con las 5 sagas: la tarjeta debe mostrar la carátula de una
película y el logo de la franquicia encima; el detalle respeta el orden del JSON
y los faltantes abren la ficha de Seerr. Si algún logo no se lee bien sobre la
carátula, ajustar `logoSize`/`logoPosition` en `_franchisesScroll`.

