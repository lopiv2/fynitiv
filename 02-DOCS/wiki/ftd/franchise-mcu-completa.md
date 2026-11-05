# FTD: franchise-mcu-completa — Marvel hasta 2026 (Saga del Multiverso)

## Intent
La entrada Marvel solo cubría la Saga del Infinito (23 pelis hasta 2019). Ampliarla con las 16 pelis de 2021-2026 (Fase 4, 5 y 6) y renombrar el bloque a `mcu` / "Universo Cinematográfico Marvel", ya que no es solo la Saga del Infinito.

## Scope
- `assets/data/franchises.json`: bloque `mcu_infinity_saga` → `mcu`, nombre general, +16 items tras `Spider-Man: Lejos de casa`. Sin `logo`, con el mismo `posterAsset`.
- No se toca: código, `PrimeCardBadge`, foco TV, ARB.

## Checklist
- [x] FTD creado antes del cambio
- [x] Bloque `mcu` con 39 pelis
- [x] JSON válido + `flutter analyze` limpio

## Evidence
- IDs TMDB verificados vía Wikidata SPARQL (IMDb → TMDB), no a ojo:
- 497698, 566525, 524434, 634649, 453395, 616037, 505642, 640146, 447365, 609681, 533535, 822119, 986056, 617126 (URL TMDB), 969681 (URL TMDB), 1003596 (Wikidata Q113244839).
- Corrección del proceso: Quantumania es tt10954600/tmdb 640146 (tt10954652 es "Old").
- El id viejo solo se referencia en el propio JSON (+ mención en un FTD); las rutas se resuelven dinámicas, renombrar es seguro.
- `Avengers: Doomsday` (dic 2026, aún sin estrenar) se incluye igual: los faltantes sin Seerr se pintan con título/año y badge, sin romper nada.

## Next
- Verificación visual por el desarrollador (sin `flutter build` por norma).
