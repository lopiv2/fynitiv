# Badge Prime solo para vídeo (música ya no sale como "Tendencias")

## Intent
En Prime, al abrir una biblioteca de música casi todas las tarjetas mostraban el
badge "TENDENCIAS". El badge Prime debe aplicarse solo a contenido de vídeo.

## Scope
- In: `lib/core/widgets/card_badge_resolver.dart`: `resolvePrimeBadge` devuelve
  `null` si el item no es de vídeo.
- Out: no se cambia el resto de la lógica de géneros/rating ni otros skins.

## Checklist
- [x] El badge se limita a tipos de vídeo.
- [x] `flutter analyze` limpio.

## Evidence
- Causa: `resolvePrimeBadge` no filtraba por tipo. Para música (items sin
  géneros o con géneros que no mapean, y sin rating), `_effectiveRating` devuelve
  `7` por defecto (fallback "sin metadatos"), que cumple `>= 7` → badge
  "TENDENCIAS" en casi todos los items.
- Fix: guarda por tipo al inicio, permitiendo solo
  `movie/series/episode/season/video`; el resto (música, libros, etc.) → `null`.
- Prime es el único skin con `showCardBadge: true`, y las tarjetas backdrop de la
  biblioteca usan `resolvePrimeBadge`.
- `flutter analyze` → `No issues found!`.

## Next
- Comprobar en Prime que la biblioteca de música (álbumes/artistas) ya no muestra
  el badge, y que películas/series lo siguen mostrando.
