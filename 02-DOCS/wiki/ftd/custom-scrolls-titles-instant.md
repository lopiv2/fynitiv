# Custom scrolls: títulos traducidos por chip + aparición instantánea

## Intent
Corregir dos fallos de los scrolls custom del tema Custom: (1) los chips de género del editor muestran nombres en inglés y las filas pueden quedar con el texto fijo de "Películas de acción" aunque se elijan otros géneros; cada chip/título debe mostrarse traducido según ARB. (2) Los scrolls añadidos/eliminados solo aparecen tras reiniciar o recargar; deben reflejarse al instante en Inicio/VOD.

## Scope
- In:
  - Nuevas claves ARB EN+ES para los géneros Jellyfin sin traducción (`genreBiography`, `genreMusical`, `genreShort`, `genreSport`, `genreSuperhero`) + `flutter gen-l10n`; actualizar `genreNamesHint` (los chips ya no se muestran en inglés).
  - `genre_localizer.dart`: resolvers nuevos + `localizeJellyGenre(JellyGenre, l10n)` directo por enum (sin round-trip por cadena).
  - `custom_skin_section.dart`: chips de género y subtítulo del editor con `localizeJellyGenre`; al cambiar el título del desplegable se autofiltran los géneros por defecto de ese título (solo si el título trae valores, para no borrar selecciones manuales).
  - `home_scroll.dart`: `hashCode` coherente con `==` (listas por contenido) para que scrolls iguales compartan provider.
  - `home_screen.dart` / `vod_screen.dart`: las secciones `custom` en carga muestran al instante la fila con su título traducido + `AppLoader`; al terminar con resultados se pinta el `ContentRow`, si viene vacía se oculta como antes. Sin nuevos focos (mismo `FocusTraversalGroup`, sin elementos enfocables en el placeholder).
  - Solo `flutter analyze` como verificación (sin build, sin tests no pedidos).
- Out:
  - No tocar `PrimeCardBadge` ni presets existentes.
  - No cambiar el formato de documentos ni el orden de layouts.
  - Sin `ScaffoldMessenger` en código nuevo (toasts ya usan `flutter_easyloading`).

## Checklist
- [x] ARB EN+ES con las 5 claves nuevas + hint actualizado; `flutter gen-l10n` regenera getters.
- [x] `localizeJellyGenre` cubre los 22 `JellyGenre`; chips y subtítulo del editor traducidos.
- [x] Cambiar título en el diálogo autofiltra géneros por defecto del título.
- [x] Tocar chips de género re-titula cuando la combinación coincide con un título conocido.
- [x] Diálogo nuevo sin nada premarcado (título libre + géneros vacíos); el nombre libre vacío se titula con sus géneros traducidos.
- [x] Migración al arrancar: filas legacy tituladas "Acción" con géneros de otro título se retitulan y persisten.
- [x] `hashCode` de `HomeScroll` por contenido, coherente con `==`; nuevo `copyWith`.
- [x] Filas custom en Inicio/VOD visibles al instante (título + loader) al añadir; desaparecen al instante al quitar.
- [x] `flutter analyze` sin problemas.

## Evidence
- `lib/l10n/app_en.arb` / `app_es.arb`: `genreBiography`, `genreMusical`, `genreShort`, `genreSport`, `genreSuperhero` + `genreNamesHint` actualizado ("se muestran traducidos; el filtrado usa los nombres exactos"); `flutter gen-l10n` regeneró los getters (verificados en `app_localizations_en/es.dart`).
- `lib/l10n/genre_localizer.dart`: nuevos resolvers + `localizeJellyGenre(JellyGenre, l10n)` con `switch` exhaustivo de los 22 valores.
- `lib/core/skin/home_scroll.dart`: mapa canónico `defaultGenresForTitle` + `titleForGenres()`; `copyWith`; `hashCode` con `Object.hashAll` por contenido, coherente con `==`.
- `lib/features/settings/presentation/widgets/custom_skin_section.dart`: chips con `localizeJellyGenre`, subtítulo del editor traducido, título→géneros al cambiar el desplegable y al crear filas, y género→título al tocar chips (solo ante coincidencia exacta; el nombre libre escrito se respeta, y si se deja vacío se titula con sus géneros traducidos). Fila nueva: título libre y ningún chip marcado.
- `lib/core/skin/skin_controller.dart`: `_migrateLegacyCustomTitles` retitula una sola vez las filas custom guardadas como `actionMovies` cuyos géneros coinciden con otro título, y lo persiste.
- `lib/features/library/presentation/home_screen.dart` y `lib/features/vod/presentation/vod_screen.dart`: pre-cálculo cuenta scrolls custom en carga como presentes; el `Builder` custom muestra título traducido (`ScrollTitle`) + `AppLoader` mientras carga y `ContentRow` al llegar la API; sin resultados se oculta como antes; sin focos nuevos (paridad TV).
- `flutter analyze` → `No issues found!`.

## Next
- Probar en la app con tema Custom: crear scrolls de Comedia/Terror/etc., comprobar título traducido y contenido acorde; añadir/quitar y ver Inicio/VOD al instante sin reiniciar; `flutter analyze` limpio.
