# FTD: scroll-cache-a — caché y carga rápida de scrolls (opción A)

## Intent
Que los elementos de los scrolls del home (`ContentRow` + tarjetas) aparezcan antes y sin tirones, sin virtualizar ni cambiar el banner ni el foco TV. Solo afinado de caché y peticiones.

## Scope
- `lib/features/library/application/image_url.dart`: bajar defaults landscape a 800 y añadir resolución única por tarjeta (sin cadenas de fallback por red).
- `lib/features/library/presentation/widgets/poster_card.dart`: póster 1000 → 500 (red + memoria + disco).
- `lib/features/library/presentation/widgets/backdrop_card.dart`: memoria/disco 1920 → 800 y una sola URL calculada por tags (un solo request, fallback a color).
- `lib/features/library/presentation/widgets/content_row.dart`: precache de las 8 primeras tarjetas con `CachedNetworkImageProvider` (sin `cacheExtent`: el `SingleChildScrollView` de este SDK no lo soporta).
- `lib/features/library/presentation/home_screen.dart`: no bloquear todo el home por resume/nextUp/banner; solo por `views`. `cacheExtent` vertical.
- `lib/features/library/application/library_providers.dart`: `_kLibraryCache` 5 → 20 min (y timers manuales de 5 a 20).
- `lib/features/library/presentation/widgets/featured_slider.dart`: fijar explícito 1280/600 para no degradarse con el nuevo default de 800.
- No se toca: virtualización del `Stack`, `PrimeCardBadge`, foco TV, ARB (sin textos nuevos).

## Checklist
- [x] FTD creado antes del cambio
- [x] image_url: defaults + helper de URL única
- [x] poster_card: 500px
- [x] backdrop_card: 800px + URL única
- [x] content_row: precache 8 (sin cacheExtent: no soportado en SingleChildScrollView de este SDK)
- [x] home_screen: carga progresiva + scrollCacheExtent vertical
- [x] providers: caché 20 min
- [x] featured_slider: tamaños explícitos anti-regresión
- [x] `flutter analyze` limpio

## Evidence
- `flutter analyze` (7 ficheros): `No issues found! (ran in 5.1s)`.
- Ajuste intermedio: `cacheExtent` deprecado → `ScrollCacheExtent.pixels(800)` en `ListView` vertical (SDK Flutter 3.50 master).
- Usuario confirma en sesión: el TTI del home ha bajado tras la opción A.

## Next
- Cerrado salvo regresión. Si reaparece lentitud con bibliotecas grandes, reabrir opción B (virtualizar `ContentRow` con `ListView.builder`) y migrar banner a `CachedNetworkImage`.
