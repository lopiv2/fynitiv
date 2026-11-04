# `HomeScroll.titleKey` opcional

## Intent

Permitir crear un `HomeScroll` para una sección `recent` sin obligar a elegir un título:
las filas de recientes resuelven el suyo en caliente con la biblioteca
(`l10n.recentIn(view.name)`), así que el `titleKey` no aporta nada ahí.

## Scope

- `lib/core/skin/home_scroll.dart`: `titleKey` deja de ser `required` y usa
  `HomeScrollTitle.custom` por defecto (mismo fallback que `fromJson`).
- `lib/core/skin/skin_presets.dart`: el `HomeScroll` de la sección `recent` del preset
  personalizado ya no declara `titleKey`.

## Checklist

- [x] `HomeScroll.titleKey` opcional (default `custom`)
- [x] Preset de recientes sin `titleKey`
- [x] `flutter analyze --no-pub` sin incidencias

## Evidence

- `flutter analyze --no-pub` → `No issues found! (ran in 17.8s)`

## Next

Nada pendiente. Si se quiere personalizar el título de una sección `recent` en el futuro,
se resolverá por biblioteca en el render, sin volver a hacer obligatorio el campo.
