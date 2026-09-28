# Intent
Actualizar `dio`, `material_ui` y `go_router` a sus últimas versiones estables resolubles sin romper la navegación ni los interceptores Dio existentes.

# Scope
- Solo `pubspec.yaml` (+ `pubspec.lock` regenerado): `dio ^5.9.0` → `^5.11.1`, `material_ui ^1.0.0` → `^1.4.0`, `go_router ^17.5.0` → `^18.0.1`.
- No se tocan widgets, ARB, skins, ni `PrimeCardBadge`.
- No se ejecuta `flutter build`; verificación con `flutter pub get` + `flutter analyze`.

# Checklist
- [x] Diagnosticar: `dio` 5.11.1 y `material_ui` 1.4.0 ya en lock (latest); `go_router` 17.5.0 → 18.0.1 pendiente (major)
- [x] Verificar changelog `go_router` 18.0.0 (migra a material_ui/cupertino_ui, SDK mín Flutter 3.44/Dart 3.12; sin breaking en API usada) y SDK local (Flutter 3.49/Dart 3.14 OK)
- [x] Subir constraints en `pubspec.yaml`
- [x] `flutter pub get` sin conflictos
- [x] `flutter analyze` sin errores nuevos

# Evidence
- `flutter pub get` (28/09/2026): `Got dependencies!`; `go_router` ya no aparece en `outdated`; `pubspec.lock`: `dio 5.11.1`, `material_ui 1.4.0`, `go_router 18.0.1` (todos `direct main`).
- `flutter analyze`: `2 issues found` — solo 2 `info` preexistentes en `lib/l10n/app_localizations.dart:90-91` (`deprecated_member_use`), cero errores nuevos. Sin cambios de código necesarios: `GoRoute`/`StatefulShellRoute`/`matchedLocation`/`pathParameters`/`extra` siguen compatibles.

# Next
- Tras el bump, si `analyze` pasa, el desarrollador compila cuando quiera; vigilar `ShellRoute` observers por defecto (cambio 17.0.0 ya asumido) y que `go_router` 18 no altera `matchedLocation`/`pathParameters`/`extra` usados en `app_router.dart` y `home_shell.dart`.
