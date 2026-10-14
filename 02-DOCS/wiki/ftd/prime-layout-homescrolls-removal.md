# Prime: homeLayout/vodLayout y eliminación de homeScrolls

## Intent
Migrar el skin de Amazon Prime al sistema de layouts (`homeLayout`/`vodLayout`)
manteniendo el estilo de sus HomeScrolls, y eliminar la propiedad `homeScrolls`
de `Skin`, que ya estaba marcada como deprecada.

## Scope
- In:
  - `SkinPresets.amazonPrime`: `homeLayout` y `vodLayout` con la misma
    estructura, usando `LayoutSection.custom(HomeScroll…)` para las filas de
    acción y familia (cardType backdrop, estilo Prime).
  - Eliminar el campo `Skin.homeScrolls` (constructor, `copyWith`, `fromJson`,
    `toJson`) y todos sus usos: bucles en `home_screen.dart`/`vod_screen.dart`
    (cómputo de backdrops y path legado) y la migración en `skin_controller.dart`.
  - `seasonalBadgeAsset`: corregir el asset de Navidad a `tree.webp`.
- Out:
  - No se cambian otros skins ni el comportamiento del orden legado (los presets
    que no definen layout siguen usando su orden legado, ya sin `homeScrolls`).

## Checklist
- [x] `amazonPrime` con `homeLayout`/`vodLayout` equivalentes; comprobar en código.
- [x] Sin referencias a `homeScrolls`; comprobar con búsqueda (`grep homeScrolls`).
- [x] `flutter analyze` limpio.

## Evidence
- `skin_presets.dart`: `amazonPrime.homeLayout` y `.vodLayout` =
  `featuredSlider, seasonal, continueWatching, nextUp, recent, custom(action),
  custom(family)`; los dos `custom` conservan `cardType: backdrop`.
- Búsqueda `homeScrolls` en `lib/**/*.dart` → sin resultados.
- `skin.dart` sin el campo y sin su serialización; `skin_controller.dart` sin la
  migración de `homeScrolls` (se mantiene la de `homeLayout`/`vodLayout`).
- `seasonal_event.dart`: `SeasonalEvent.christmas → assets/images/seasonal/tree.webp`.
- `flutter analyze` → `No issues found!`.

## Next
- Revisar en Prime que Inicio y VOD muestran las filas configuradas (banner,
  seasonal, continuar, a continuación, reciente, acción, familia) con el aspecto
  de siempre.
- Nota: skins guardados en JSON con la antigua clave `homeScrolls` la ignorarán
  (campo eliminado); si un usuario tenía un Prime personalizado, conviene
  reaplicar el preset (los que tengan `homeLayout` vacío lo heredan por la
  migración existente).
