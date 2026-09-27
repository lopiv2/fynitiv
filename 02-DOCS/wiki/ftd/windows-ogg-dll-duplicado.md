# Intent
Desbloquear `flutter build windows`: falla en `build_hooks` con `Building native assets failed` por `ogg.dll` duplicada entre `flutter_soloud` y `flutter_recorder` (transitiva de `audio_flux`).

# Scope
- Solo `pubspec.yaml` (+ `pubspec.lock` regenerado): fijar `flutter_recorder` a `2.0.4` como dependencia directa exacta.
- No se toca código de widgets, ni ARB, ni skins, ni `PrimeCardBadge`.
- No se ejecuta `flutter build` como verificación (solo diagnóstico previo); verificación con `flutter analyze`.

# Checklist
- [x] Reproducir y capturar causa raíz en log verbose (`Application asset verification failed`, duplicado `ogg.dll`: `package:flutter_recorder/xiph/ogg.dll` vs `package:flutter_soloud/xiph/ogg.dll`)
- [x] Añadir pin `flutter_recorder: 2.0.4` en `pubspec.yaml`
- [x] `flutter pub get` y confirmar `pubspec.lock` en `2.0.4`
- [x] `flutter analyze` sin errores nuevos

# Evidence
- `flutter pub get` (27/09/2026): `flutter_recorder 2.0.4 (2.0.5 available)`, `Got dependencies!`; `pubspec.lock`: `flutter_recorder` `dependency: "direct main"`, `version: "2.0.4"`.
- `flutter analyze`: `No issues found! (ran in 3.6s)`.
- No se ejecuta `flutter build` como verificación (norma del proyecto); pendiente que el desarrollador compile Windows y confirme que `build_hooks` pasa.
- Log verbose `flutter build windows --debug -v` (27/09/2026): `Rerunning build for flutter_soloud...`, luego `Application asset verification failed - Duplicate dynamic library file name "ogg.dll" for the following asset ids: "package:flutter_recorder/xiph/ogg.dll", "package:flutter_soloud/xiph/ogg.dll"` → `Target build_hooks failed`.
- `flutter_recorder` 2.0.5 changelog: `fix windows: bundle ogg.dll required by the recorder import library` (introduce el duplicado; no hay versión posterior con fix; última en pub.dev a 27/09/2026: 2.0.5).
- La app no usa grabación de micro; `flutter_recorder` solo entra vía `audio_flux` (visualización con FFT de SoLoud), riesgo bajo.
- Upstream ya renombró en Android a `libfr_ogg`/`libfr_opus` para evitar colisiones con `flutter_soloud` (changelog 1.2.0); en Windows el alias `ogg.dll` sigue colisionando.

# Next
- Tras el pin, si el build de Windows pasa, reportar upstream (`flutter_recorder`: renombrar el alias Windows a `fr_ogg.dll` como en Android) y retirar el pin cuando haya fix. Alternativa descartada por ahora: `no_xiph_libs: true` en `flutter_soloud` (perdería Opus/Ogg/Vorbis/FLAC en SoLoud) y eliminar `audio_flux` (cambio mayor).
