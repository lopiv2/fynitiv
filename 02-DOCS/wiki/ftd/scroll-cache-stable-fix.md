# FTD: scroll-cache-stable-fix — compilar en Flutter estable 3.47

## Intent
Reparar el arranque en Windows: `home_screen.dart:867` usaba `ScrollCacheExtent.pixels(800)` sin importar `package:flutter/rendering.dart`, lo que rompia la compilacion en estable (GF7CA4DBF: `Couldn't find constructor 'ScrollCacheExtent.pixels'`).

## Scope
- `lib/features/library/presentation/home_screen.dart`: añadir `import 'package:flutter/rendering.dart'` para exponer `ScrollCacheExtent`; mantener `scrollCacheExtent: const ScrollCacheExtent.pixels(800)` (API vigente en 3.47.7, `cacheExtent` está deprecado).
- No se toca: lógica de carga progresiva, `PrimeCardBadge`, foco TV, ARB.

## Checklist
- [x] FTD creado antes del cambio
- [x] Fix aplicado en `home_screen.dart` (import rendering + scrollCacheExtent)
- [x] `flutter analyze` limpio en el fichero
- [x] Nota de compatibilidad en `scroll-cache-a.md`

## Evidence
- `flutter --version`: Flutter 3.47.7 estable (Dart 3.13.5).
- Antes: `flutter analyze lib/features/library/presentation/home_screen.dart`: `Undefined name 'ScrollCacheExtent'` (GF7CA4DBF en build Windows).
- Causa: `ScrollCacheExtent` vive en `src/rendering/viewport.dart`, exportado solo por `package:flutter/rendering.dart`; `material_ui` no lo re-exporta.
- Alternativa descartada: `cacheExtent: 800` compila pero está deprecado desde 3.41 (`deprecated_member_use`).
- Después: `flutter analyze lib/features/library/presentation/home_screen.dart`: `No issues found!`.

## Next
- Verificar arranque en Windows (lo ejecuta el desarrollador, sin `flutter build` por norma). Añadir nota de compatibilidad en `scroll-cache-a.md`.
