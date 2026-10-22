# VOD dividido en Películas y Series (Disney/Prime, como Netflix)

## Intent
Dividir VOD en dos pantallas dashboard (Películas y Series) en los skins Disney y Prime, como las de Netflix: cada una con sus sliders y scrolls (solo pelis / solo series) y rutas propias (`/vod/movies`, `/vod/series`).

## Scope
- In:
  - `VodSplit { movies, series }` (capa skin) + `HomeScroll.copyWith`.
  - `Skin`: `splitVod` (defecto `false`), `moviesLayout`/`seriesLayout` (defecto `[]`) con `copyWith`/JSON.
  - `VodScreen(split)`: filtra vistas (movies/tvshows), resume (movie/episode), nextUp (vacío en pelis), latest/banner por tipo; layout = movies/series o fallback a `vodLayout`; customs con tipos fuera del split se estrechan o se omiten.
  - Router (rama VOD): `/vod/movies`, `/vod/series`.
  - Nav cuando `splitVod`: items Películas/Series tras VOD en sidebar vertical y topbar classic/prime (texto solo en prime); Netflix apunta Shows/Movies a las nuevas pantallas.
  - Presets Disney/Prime/Netflix con `splitVod: true` y layouts propios.
  - Reutiliza ARB `movies`/`shows`; sin claves nuevas.
- Out:
  - No tocar el editor custom (los layouts de pelis/series del skin Custom quedan para después); no cambiar rama VOD raíz; sin tests (no pedidos) y sin `flutter build` (solo `flutter analyze`).

## Checklist
- [ ] `VodSplit` + `HomeScroll.copyWith`; comprobar `flutter analyze`.
- [ ] Campos en `Skin` con JSON/`copyWith`; comprobar `flutter analyze`.
- [ ] `VodScreen(split)` con filtrado y layouts; comprobar `flutter analyze`.
- [ ] Rutas + nav (sidebar/topbars/Netflix); comprobar `flutter analyze`.
- [ ] Presets Disney/Prime/Netflix; comprobar render y `flutter analyze`.
- [ ] `flutter analyze` sin problemas; demostrar salida.

## Evidence
- `layout_section.dart`: `VodSplit { movies, series }`.
- `skin.dart`: `splitVod` (defecto `false`), `moviesLayout`/`seriesLayout` (defecto `[]`) con `copyWith`/JSON tolerante.
- `vod_screen.dart`: `VodScreen(split)` — filtra vistas (movies/tvshows), resume (movie/episode), nextUp (vacío en pelis), latest/banner por tipo; layout propio con fallback a `vodLayout`; customs fuera del split se estrechan (`copyWith`) u omiten.
- `app_router.dart` (rama VOD): `/vod/movies`, `/vod/series` (quedan en la rama 2).
- `sidebar.dart`: items Películas (`l10n.movies`) y Series (`l10n.shows`) tras VOD en vertical y topbar classic/prime (texto solo + énfasis en prime) cuando `splitVod`; VOD deja de marcarse activo en las split.
- `netflix_top_bar.dart`: Shows/Movies apuntan a `/vod/series` y `/vod/movies` (imports sin uso eliminados).
- Presets Disney/Prime/Netflix con `splitVod: true` y layouts propios (pelis: continuar+novedades+biblioteca pelis+ customs; series: +nextUp+biblioteca series+ customs).
- Sin ARB nuevas (`movies`/`shows` reutilizadas). Nota: el commit paralelo `8192ac5` ya traía `HomeScroll.copyWith` (se eliminó el duplicado) y 6 accesos `skin.` sin `?` en VOD (corregidos a `skin?.` para dejar analyze limpio).
- `flutter analyze` → `No issues found! (ran en 9.8s)`.

## Next
- Probar en app: pelis/series en cada skin, resume/nextUp filtrados, customs estrechados, mando en TV.
- Seguimiento: fila de biblioteca en pelis/series con `sort: random` para no repetir Novedades (preset Disney/Prime/Netflix actualizado; `libraryRowItemsProvider` ya soporta random sin caché).
