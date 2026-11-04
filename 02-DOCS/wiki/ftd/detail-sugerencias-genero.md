# FTD: detail-sugerencias-genero — relacionados por género, no alfabéticos

## Intent
En el detalle, Sugerencias/Relacionado trae siempre los mismos 10 (orden alfabético del servidor). Debe sugerir contenido del mismo género o parecido y variar entre visitas.

## Scope
- `lib/features/library/application/library_providers.dart`: `similarItemsProvider`.
  - Causa: sin `sortBy` el servidor devuelve SortName asc + `limit: 10`; si `item.genres` viene vacío (tarjetas sin campo Genres) el filtro es nulo y siempre caen los mismos.
  - Fix: pedir pool amplio (30) con `sortBy: [ItemSortBy.random]`, incluir `ItemFields.genres` en `fields`, puntuar en cliente por géneros compartidos (y desempate aleatorio), devolver 10. Incluir `book` en el filtro de géneros (antes se excluía). Fallback sin géneros: mismo tipo en aleatorio, no alfabético.
  - Límite por tipo: movie→movie, series→series (se amplía a season/episode→series para fichas abiertas desde capítulo), book→book; resto sin restricción (comportamiento actual).
- No se toca: UI de `_RelatedSection`, `PrimeCardBadge`, foco TV, ARB (sin textos nuevos).

## Checklist
- [x] FTD creado antes del cambio
- [x] `similarItemsProvider` con pool random + score por género
- [x] `flutter analyze` limpio

## Evidence
- `flutter analyze` (3 ficheros incl. `library_providers.dart`): `No issues found!`.
- Pool 30 en `ItemSortBy.random` + `ItemFields.genres`, score por géneros compartidos, fallback sin filtro si el AND del servidor vacía el pool; `book` ya filtra por género.

## Next
- Si el pool random + score funciona, valorar misma técnica para `personFilmographyProvider` (ya ordena por año, no toca).
