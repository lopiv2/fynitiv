# Intent
Desbloquear `flutter build windows`: fallaba en `build_hooks` con `Building native assets failed` por `ogg.dll` duplicada entre `flutter_soloud` y `flutter_recorder` (transitiva de `audio_flux`). Retirar el pin transitorio tras el fix upstream.

# Scope
- Solo `pubspec.yaml` (+ `pubspec.lock` regenerado): eliminar la dependencia directa `flutter_recorder: 2.0.4`; se resuelve transitivamente vía `audio_flux: ^2.0.0`.
- No se toca código de widgets, ni ARB, ni skins, ni `PrimeCardBadge`.
- No se ejecuta `flutter build` como verificación (norma del proyecto); verificación con `flutter analyze`.

# Checklist
- [x] Reproducir y capturar causa raíz en log verbose (`Application asset verification failed`, duplicado `ogg.dll`: `package:flutter_recorder/xiph/ogg.dll` vs `package:flutter_soloud/xiph/ogg.dll`)
- [x] Pin transitorio `flutter_recorder: 2.0.4` en `pubspec.yaml` (mitigación temporal)
- [x] Confirmar fix upstream en `flutter_recorder` 2.0.6 (changelog)
- [x] Eliminar la dependencia directa `flutter_recorder` de `pubspec.yaml`
- [x] `flutter pub get` y confirmar `pubspec.lock` en `2.0.6` como transitiva de `audio_flux`
- [x] `flutter analyze` sin errores nuevos

# Evidence
- Causa raíz (27/09/2026): `flutter_recorder` 2.0.5 introduce `ogg.dll`; colisiona con `flutter_soloud` en `native_assets` → `Target build_hooks failed`.
- Fix upstream `flutter_recorder` 2.0.6 (01/10/2026): *"fix windows: rebuild vendored ogg with export name `fr_ogg.dll` and remove `ogg.dll` alias to avoid Native Assets collision with `flutter_soloud` #66"*.
- `audio_flux: ^2.0.0` declara `flutter_recorder: ^2.0.3`, por lo que acepta `2.0.6` sin dependencia directa.
- `flutter pub get` seguido de `flutter pub upgrade flutter_recorder` (03/10/2026): `flutter_recorder` resuelto a `2.0.6` (transitive) en `pubspec.lock`.
- `flutter analyze` (03/10/2026): `No issues found! (ran in 47.5s)`.
- Build Windows confirmado por el desarrollador (03/10/2026): `build_hooks` pasa; el build compila `flutter_recorder.vcxproj` sin el duplicado `ogg.dll` (solo warnings benignos de terceros: C4018/C4996/C4244 en `capture.cpp`, `flutter_recorder.cpp`, `miniaudio.h`, `pffft.c`).

# Next
- Cerrado. Feature completada sin follow-up. Reabrir solo si reaparece la colisión `ogg.dll` en `build_hooks`.
