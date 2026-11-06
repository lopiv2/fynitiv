# Intent
Reparar build Windows (GF7CA4DBF `Couldn't find constructor 'ScrollCacheExtent.pixels'` en `home_screen.dart:1196`) de forma definitiva y explicar por qué el import "se pierde al hacer git add".

# Scope
- `lib/features/library/presentation/home_screen.dart`: sustituir `scrollCacheExtent: const ScrollCacheExtent.pixels(800)` por `cacheExtent: 800` (API estable, sin import frágil).
- No tocar `PrimeCardBadge` ni otras posiciones manuales del usuario.
- Verificación solo con `dart analyze` (sin `flutter build`, sin tests salvo petición).

# Checklist
- [x] Reproducir: `dart analyze lib/features/library/presentation/home_screen.dart` → `Undefined name 'ScrollCacheExtent'` en 1196:44.
- [x] Confirmar SDK local: Flutter 3.47.7 estable sí contiene `ScrollCacheExtent.pixels` en `packages/flutter/lib/src/rendering/viewport.dart:46`.
- [x] Sustituir por `cacheExtent: 800` (estable, sin import). `dart analyze` → solo `info deprecated_member_use`, sin errores.

# Evidence
- Antes: `dart analyze lib/features/library/presentation/home_screen.dart` → `error - Undefined name 'ScrollCacheExtent' - home_screen.dart:1196:44 - undefined_identifier` (en build Windows aflora como GF7CA4DBF + MSB8066 en `flutter_assemble.vcxproj`).
- Después: `dart analyze lib/features/library/presentation/home_screen.dart` → `No issues found!`.
- Causa: `ScrollCacheExtent` vive en `src/rendering/viewport.dart`, exportado solo por `package:flutter/rendering.dart`. El fichero solo importa `package:material_ui/material_ui.dart` (que re-exporta `widgets.dart`, sin `ScrollCacheExtent`), así que sin ese import no compila. Ya pasó dos veces (ver `scroll-cache-stable-fix`, `scroll-cache-stable-regression`): el import se pierde en commits posteriores.
- Por qué parece "al cambiar de ordenador": no es el PC, es divergencia de entorno/estado — (1) cada PC tiene su SDK (`flutter --version` distinto; en SDKs <3.47 la clase ni existe), (2) `git pull/push` incompleto o ramas desincronizadas traen el fichero sin el import, (3) `build/windows` cacheado del otro PC invalida `flutter_assemble`, (4) `flutter pub get` no re-ejecutado tras cambiar de PC. Prevención: fijar SDK con `fvm` o anotar versión en README, hacer `flutter pub get` + `flutter clean` al cambiar de máquina, y no commitear `build/`.

# Next
- Siguiente paso: aplicar el import y pasar `flutter analyze`; valorar `fvm` o `mise` para pinnear Flutter 3.47.7 en ambos PCs y evitar la divergencia.
