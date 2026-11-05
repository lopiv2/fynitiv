# FTD: scroll-cache-stable-regression — regresión del import de rendering

## Intent
Reparar de nuevo el arranque en Windows: `home_screen.dart:1196` usa `ScrollCacheExtent.pixels(800)` sin importar `package:flutter/rendering.dart`. `flutter analyze` da `Undefined name 'ScrollCacheExtent'` (en build Windows: GF7CA4DBF `Couldn't find constructor 'ScrollCacheExtent.pixels'`). Ya pasó ayer (ver `scroll-cache-stable-fix`); el import se perdió en un commit posterior.

## Scope
- `lib/features/library/presentation/home_screen.dart`: re-añadir `import 'package:flutter/rendering.dart'`; mantener `scrollCacheExtent: const ScrollCacheExtent.pixels(800)`.
- No se toca: lógica de carga, `PrimeCardBadge`, foco TV, ARB.

## Checklist
- [x] FTD creado antes del cambio
- [x] Import re-aplicado en `home_screen.dart`
- [x] `flutter analyze` limpio en el fichero

## Evidence
- `flutter --version`: Flutter 3.47.7 estable (Dart 3.13.5). No obsoleto: `ScrollCacheExtent.pixels` existe en `G:\flutter\packages\flutter\lib\src\rendering\viewport.dart:46`; `material_ui 1.8.0` pide `flutter >=3.47.0`.
- Antes: `flutter analyze lib/features/library/presentation/home_screen.dart` → `error - Undefined name 'ScrollCacheExtent' - home_screen.dart:1196:44`.
- Causa: `material_ui` solo exporta `package:flutter/widgets.dart`, que no re-exporta `ScrollCacheExtent` (solo `rendering.dart` lo expone).

## Next
- `flutter analyze` limpio; arranque en Windows lo verifica el desarrollador (sin `flutter build` por norma).
