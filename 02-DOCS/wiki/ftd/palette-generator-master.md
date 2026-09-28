# Intent
Sustituir `palette_generator: ^0.3.3+7` (discontinuado) por `palette_generator_master: ^1.1.0` manteniendo la extracción de paleta del fondo animado del player.

# Scope
- Solo `pubspec.yaml` (+ `pubspec.lock` regenerado) y `lib/features/player/presentation/player_screen.dart` (import + `PaletteGenerator` → `PaletteGeneratorMaster`).
- No se tocan widgets, ARB, skins, ni `PrimeCardBadge`.
- No se ejecuta `flutter build` como verificación; solo `flutter pub get` + `flutter analyze`.

# Checklist
- [x] Verificar en pub.dev que `palette_generator_master ^1.1.0` existe y es rewrite compatible
- [x] Cambiar dependencia en `pubspec.yaml`
- [x] Actualizar import y llamada en `player_screen.dart`
- [x] `flutter pub get` sin conflictos
- [x] `flutter analyze` sin errores nuevos

# Evidence
- `flutter pub get` (28/09/2026): `Got dependencies!`; `pubspec.lock`: `palette_generator_master` `dependency: "direct main"`, `version: "1.1.0"`; sin rastro de `palette_generator:` antiguo.
- `flutter analyze`: `2 issues found` — solo 2 `info` preexistentes en `lib/l10n/app_localizations.dart:90-91` (`deprecated_member_use` GlobalMaterial/CupertinoLocalizations), cero errores relacionados con la migración.

# Next
- Ejecutar `flutter pub get` + `flutter analyze`; si el desarrollador quiere, activar `generateHarmony` / `ColorSpace.lab` o accesibilidad WCAG que ofrece el paquete nuevo.
