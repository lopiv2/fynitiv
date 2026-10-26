# FTD — Fondo del skin en pantalla de libros

## Intent

La pantalla de libros (`EReaderScreen`) ignora los colores de fondo del skin
activo (Netflix y todos los demás): muestra siempre el degradado de
`SkinPresets.jellyfinDefault` por el `SkinScope` fijo con `eReaderSkin`.
Debe seguir el skin global como el resto de pantallas de biblioteca
(p. ej. `AllMoviesScreen`: `DashboardBackground` sin `SkinScope`).

## Scope

- Solo `lib/features/ereader/presentation/ereader_screen.dart`
  (quitar `SkinScope` fijo) y `lib/features/ereader/application/ereader_providers.dart`
  (quitar la constante `eReaderSkin` si queda sin uso).
- Sin cambios de textos, navegación ni `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] Quitar `SkinScope(skin: eReaderSkin)` en `EReaderScreen`.
- [x] Eliminar `eReaderSkin` sin uso y sus imports.
- [x] `dart format` del fichero editado.
- [x] `flutter analyze` limpio.

## Evidence

- `EReaderScreen` (`ereader_screen.dart:57`) ahora es `Scaffold > DashboardBackground`
  sin `SkinScope`, igual que `AllMoviesScreen`: el fondo y las tarjetas siguen el
  skin global (Netflix incluido, con su tinte estacional).
- Constante `eReaderSkin` eliminada de `ereader_providers.dart` (era su único uso).
- `dart format` aplicado; `flutter analyze lib/features/ereader` → No issues found.

## Next

- Comprobar visualmente libros con skin Netflix y otro skin.
