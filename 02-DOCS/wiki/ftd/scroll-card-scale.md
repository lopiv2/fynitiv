# FTD: scroll-card-scale — tamaño de tarjeta por scroll

## Intent
Parámetro `cardScale` en `HomeScroll` (defecto 1.0) para agrandar/pequeñar las tarjetas de un scroll concreto sin tocar el skin global.

## Scope
- `home_scroll.dart`: `cardScale` (1.0) + copyWith/JSON/`==`/hash.
- `content_row.dart`: param `cardScale` (1.0) aplicado a ancho (`_cardWidth`) y alto de fila póster; backdrop deriva solo. Spotlight/precache heredan al usar `_cardWidth`.
- Cablear `cardScale` en secciones con scroll de home, VOD, upcoming y seasonal. Sin cambios de preset (todo 1.0 = igual).

## Checklist
- [x] FTD creado antes del cambio
- [x] campo en HomeScroll + JSON
- [x] ContentRow aplica escala
- [x] cableado en secciones con scroll
- [x] `flutter analyze` limpio

## Evidence
- `flutter analyze` (6 ficheros): `No issues found!`.

## Next
- Ninguno; el usuario lo fija por scroll (p. ej. `cardScale: 1.2`).
