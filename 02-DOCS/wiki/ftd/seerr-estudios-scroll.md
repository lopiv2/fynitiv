# Fila "Estudios" de Seerr (solo si Seerr está configurado)

## Intent

Añadir un scroll de estudios que trae sus catálogos de Seerr: una fila de
estudios (logo/nombre) y, al pulsar, las películas del estudio para pedirlas.
Si Seerr no está configurado, la fila no aparece.

## Scope

- `assets/data/studios.json` + `pubspec.yaml`: 11 estudios curados con su
  `companyId` de TMDB y la ruta de su logo local:
  Disney (2), Pixar (3), Marvel (420), Lucasfilm (1), Warner (174),
  Universal (33), Paramount (4), Columbia (5), Sony (34), DreamWorks (27) y
  20th Century Studios (127928). El provider pide a Seerr
  `/discover/movies/studio/{companyId}` con cada uno.
- `assets/images/studios/`: logos locales (PNG/WebP/SVG). Se resuelven por
  nombre normalizado (sin mayúsculas/espacios/extensión) y con la ruta `logo`
  del JSON como prioridad; si falta, cae al logo de Seerr/TMDB.
- `lib/features/seerr/presentation/widgets/seerr_studio_tile.dart`: tarjeta del
  estudio. Si `fillCard` (Disney, Lucasfilm) el logo ocupa toda la tarjeta; si
  no, fondo con degradado propio del estudio + panel glassmorphism (blanco
  translúcido con blur) para que los logos oscuros se vean. El logo del panel
  ocupa ~55 % del alto de la tarjeta (mín. 48 px, máx. 110) y el panel el 84 %
  del ancho, para que se vean más grandes.
- `lib/features/library/presentation/widgets/content_row.dart` y
  `poster_card.dart`/`backdrop_card.dart`: nuevo `imageBuilder` por item, para
  usar una imagen custom (la tarjeta del estudio) manteniendo el scroll, hover y
  foco estándar del skin.
- `lib/core/widgets/logo_image.dart`: soporta asset/archivo/URL y SVG
  (`SvgPicture`).
- `lib/features/seerr/domain/seerr_models.dart`: `SeerrCompany` y
  `SeerrStudioCatalog`.
- `lib/features/seerr/data/seerr_api.dart`: `searchCompanies` y
  `studioCatalog` (metadatos del estudio + películas).
- `lib/features/seerr/application/seerr_studios_providers.dart`:
  - `seerrStudioCatalogProvider`: catálogo + metadatos (cache 20 min).
  - `seerrStudiosProvider`: vacío si no hay Seerr; carga los estudios curados,
    logos locales y `colors`/`fillCard`. No precarga catálogos: el de cada
    estudio se pide al abrirlo (así la fila aparece al instante).
- `lib/features/seerr/presentation/seerr_studio_screen.dart`: grid del catálogo
  del estudio. Si la película está en Jellyfin con media real, el hover dice
  "Ver ahora" y al pulsar reproduce (película) o abre la serie; si no, abre la
  ficha de Seerr para pedirla.
- `lib/features/seerr/presentation/seerr_detail_screen.dart`: si el título está
  en Jellyfin con media real, la ficha usa el item real (así aparece el botón de
  reproducir); si no, el item virtual de Seerr.
- `lib/features/library/presentation/item_detail_screen.dart`: el estado
  "Procesando" de Seerr se muestra como "Próximamente en tu biblioteca" (chip con
  reloj) en vez de "Procesando".
- `lib/features/library/application/library_tmdb_index.dart`: índice global
  `(tipo, tmdbId) → item` (películas + series, incluye placeholders), compartido
  por franquicias y Seerr.
- `lib/features/seerr/application/seerr_providers.dart`: el estado
  "En tu biblioteca / Procesando / Solicitar" usa el índice por TMDB (no la
  búsqueda por título), así los stubs de Radarr/Sonarr se detectan siempre.
- `LayoutSectionType.seerrStudios` + `LayoutSection.seerrStudios([scroll])` +
  JSON.
- `home_screen`: fila "Estudios" con `ContentRow` estándar (mismo scroll/foco/
  hover que el resto) y `imageBuilder` con la tarjeta del estudio.
- `vod_screen`: la sección se omite (solo aplica en Inicio/Seerr).
- `app_router.dart`: ruta `/studios/:id`.
- `skin_presets.dart`: `_seerrStudiosScroll` y la sección en el `homeLayout` de
  Disney+, justo debajo de Franquicias.
- ARB: `studios` (ES/EN).

## Checklist

- [x] Catálogo de 11 estudios con sus logos locales
- [x] Logos locales por nombre normalizado / ruta explícita, con SVG
- [x] Peticiones a Seerr con el `companyId` de cada estudio al abrir el estudio
- [x] Tarjetas con degradado + glassmorphism y logo a sangre (Disney/Lucasfilm)
- [x] Fila con el scroll estándar (`ContentRow`), uniforme con el skin
- [x] Sección, fila en Inicio y pantalla de estudio
- [x] Ruta `/studios/:id`
- [x] En Disney+ bajo Franquicias
- [x] Estado de biblioteca por índice TMDB (placeholders de Radarr/Sonarr)
- [x] En biblioteca: "Ver ahora" y reproducción desde el estudio
- [x] Procesando/placeholder: "Próximamente en tu biblioteca"
- [x] ARB + gen-l10n
- [x] `flutter analyze --no-pub` limpio

## Evidence

- `flutter analyze --no-pub` → `No issues found! (ran in 8.9s)`
- 11 logos presentes y 11 estudios con `companyId`/`colors` en el JSON.
- Logos del panel ampliados al 55 % del alto de la tarjeta (salvo los
  `fillCard` de Disney y Lucasfilm).

## Next

Abrir Inicio en Disney+: la fila "Estudios" debe comportarse como el resto de
scrolls y mostrar las tarjetas con degradado/glass o logo a sangre. Al pulsar
un estudio se pide su catálogo a Seerr. Si algún `companyId` no devuelve
resultados, ajustarlo en `assets/data/studios.json`.
