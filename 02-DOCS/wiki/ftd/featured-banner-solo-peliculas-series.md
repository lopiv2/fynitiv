# Featured slider de Inicio: solo películas y series

## Intent
Evitar que el carrusel de novedades (banner destacado) de Inicio muestre carpetas o
colecciones vacías que devuelve la API de Jellyfin, limitando la consulta a contenido
multimedia real (películas y series), como ya hace el banner equivalente de VOD.

## Scope
- In:
  - `latestBannerItemsProvider` (Inicio) pasa a pedir `includeItemTypes: [movie, series]`.
  - Se mantiene la exclusión de stubs/placeholders (`.disc`).
- Out:
  - Cambiar el diseño o la lógica del `FeaturedSlider`.
  - El listado `latestItemsProvider` de la fila "Novedades" (otra consulta; se evaluará aparte
    si el usuario lo pide).
  - Build o tests (según AGENTS.md).

## Checklist
- [x] FTD creado antes del primer cambio.
- [x] Añadir `includeItemTypes` al proveedor del banner de Inicio; `flutter analyze`.
- [x] Confirmar que el banner de VOD ya lo hacía (referencia de comportamiento).

## Evidence
- `latestBannerItemsProvider` (`lib/features/library/application/library_providers.dart`, ~línea
  244) llama a `getItemsApi().getItems(...)` con `recursive: true`, orden por `dateCreated` y
  límite 10, **sin** `includeItemTypes`; Jellyfin devuelve cualquier tipo (CollectionFolder,
  BoxSet, Season, Episode…), incluidas carpetas vacías.
- `vodLatestBannerProvider` (mismo archivo, ~línea 801) sí usa
  `includeItemTypes: [BaseItemKind.movie, BaseItemKind.series]` y comenta "solo películas y
  series".
- Ambos aplican `excludePlaceholders(...)` para descartar stubs `.disc`.
- Repositorio en rama `main`.
- Fix aplicado en `latestBannerItemsProvider`: `includeItemTypes: [BaseItemKind.movie,
  BaseItemKind.series]` (mismos tipos que el banner de VOD) manteniendo `excludePlaceholders`.
- `flutter analyze` → `No issues found! (ran in 13.9s)`.

## Next
Verificar en la app que el banner de Inicio no muestra carpetas y que sigue mostrando las
novedades reales; si la fila "Novedades" (`latestItemsProvider`) también muestra carpetas,
aplicar el mismo filtro (o el adecuado a su alcance) en una segunda pasada.
