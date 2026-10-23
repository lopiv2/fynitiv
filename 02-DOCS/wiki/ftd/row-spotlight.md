# FTD: row-spotlight — expansión estilo Netflix por scroll

## Intent
Efecto de la foto para los scrolls: la tarjeta con hover/foco crece (~1.35x, con su borde blanco) y despliega debajo meta (`género • año • temporadas • edad • CC`) + sinopsis. Parámetro por scroll (`HomeScroll.spotlight`), apagado por defecto, para activarlo a demanda.

## Scope
- `core/skin/home_scroll.dart`: `spotlight` (defecto `false`) + copyWith/JSON/`==`/hash.
- `widgets/content_row.dart`: params `spotlight`/`spotlightScale` (1.35). Escala a nivel de fila (`AnimatedScale`), `hoverScale: 1.0` a las tarjetas para no componer escalas, tira info con `AnimatedPositioned` + alto de fila animado. Foco TV vía `AppHover.onFocusChange` (índice separado, sin tocar overlays).
- Cablear `spotlight: cfg?.spotlight` en secciones con scroll de home, VOD, upcoming y seasonal. Legacy/sin scroll: intacto.
- Preset Netflix: `spotlight: true` en los custom de género (acción, comedias) de home/VOD/pelis/series.
- Sin cadenas nuevas (reutiliza `seriesSeasons` y géneros). Sin tocar PrimeCardBadge.

## Checklist
- [x] FTD creado antes del cambio
- [x] campo en HomeScroll + JSON
- [x] ContentRow: escala + info + foco TV
- [x] cableado en secciones con scroll
- [x] preset Netflix customs con spotlight
- [x] `flutter analyze` limpio

## Evidence
- `flutter analyze` (7 ficheros): `No issues found!`.
- 8 `spotlight: true` en preset Netflix (acción/comedias en home+VOD+pelis, dramas/anime en series), resto de presets intactos.

## Next
- Captura del género con foco (ratón y TV) y ajustar 1.35/alturas si conviene.
