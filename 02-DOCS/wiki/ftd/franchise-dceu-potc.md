# FTD: franchise-dceu-potc — nuevas franquicias DCEU y Piratas del Caribe

## Intent
Añadir al hub dos sagas curadas con sus imágenes locales (`assets/images/franchises/dceu.png`, `potc.webp`), sin logos superpuestos, siguiendo el mismo esquema que las 5 existentes.

## Scope
- `assets/data/franchises.json`: nuevos bloques `dceu` (16 pelis) y `potc` (5 pelis) con `posterAsset` y sin `logo`.
- No se toca: código, `PrimeCardBadge`, foco TV, ARB.

## Checklist
- [x] FTD creado antes del cambio
- [x] Bloques `dceu` y `potc` en el JSON
- [x] JSON válido + `flutter analyze` limpio

## Evidence
- IDs TMDB verificados vía Wikidata SPARQL (P345 IMDb → P4947 TMDB), no a ojo:
- DCEU: 49521, 209112, 297761, 297762, 141052, 297802, 287947, 495764, 464052, 791373, 436969, 436270, 594767, 298618, 565770, 572802.
- POTC: 22, 58, 285, 1865, 166426 (colección TMDB 295).
- Correcciones del proceso: Suicide Squad es 297761 (no 297762, ese es Wonder Woman); Blue Beetle es tt9362930/tmdb 565770; The Flash 2023 es tt0439572/tmdb 298618.

## Next
- Verificación visual por el desarrollador (sin `flutter build` por norma).
