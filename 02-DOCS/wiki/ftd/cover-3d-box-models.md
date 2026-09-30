# Intent
Definir un enum de modelos de caja 3D (cartucho, CD jewel, DVD, Blu-ray, caja grande, snap-lock Neo Geo…) con dimensiones por plataforma, para que el visor 3D muestre formas variadas. Todas al mismo tamaño (misma altura); solo cambia la forma. Automático por slug, sin selector manual.

# Scope
- In: `lib/features/games/domain/box_model.dart` (enum `BoxModel` + `forSlug`); `game_box3d_scene_viewer.dart` (`_boxSizeFor` delega en el enum).
- Out: selector manual en Ajustes, escala por modelo, geometría/UV/materiales, cámara, ARB, tests.

# Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] Enum `BoxModel` con w/h/d y resolución por slug normalizado
- [x] Visor usa `BoxModel.forSlug(slug).size`
- [x] `flutter analyze lib` sin issues

# Evidence (verificacion)
- `BoxModel` (cartridge, cdJewel, dvdCase, bluRayCase, neoGeoSnap, bigBox, defaultBox) con `width`/`height`/`depth`; altura 1.40 en todos (mismo tamaño en escena) y variación en ancho/grosor.
- `forSlug` normaliza el slug (quita `-`, `_`, espacios) y busca en un único mapa de sets; fallback `defaultBox`.
- Visor: `_boxSizeFor(slug) => BoxModel.forSlug(slug).size` (antes sets hardcodeados thin/thick).
- `flutter analyze lib` → "No issues found! (ran in 12.4s)".

# Next
- Ver en runtime la variedad (CD fino, cartucho grueso, caja PC ancha) y ajustar valores si hace falta.
