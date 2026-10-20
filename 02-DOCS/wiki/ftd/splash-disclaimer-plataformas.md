# Disclaimer de plataformas en la splash

## Intent
Mostrar bajo el badge de desarrollo de todas las presentaciones de splash el disclaimer de
plataformas disponibles (Android, Linux y Windows) con sus logos, traducido según el locale
seleccionado en Preferencias.

## Scope
- In:
  - Nuevo `_buildPlatformDisclaimer()` bajo `_buildDevBadge()` en el `build` común de la
    splash (vale para todas las estaciones: default, Halloween, Navidad…).
  - Cadena ARB `splashAvailableOn` (EN/ES) + `flutter gen-l10n`.
  - Registro en `pubspec.yaml` de `android.svg`, `Linux-Logo.png` y `windows.png`
    (existían en `assets/images/` pero sin registrar).
  - `SvgPicture` para Android (svg) e `Image.asset` para Linux/Windows (png).
- Out:
  - Traducir el badge de desarrollo (norma: los textos de debug nunca se traducen).
  - Traducir los nombres de plataforma (nombres propios, iguales en ambos idiomas).
  - Build o tests (según AGENTS.md).

## Checklist
- [x] FTD creado antes del primer cambio.
- [x] Assets registrados + ARB EN/ES + `flutter gen-l10n`.
- [x] Disclaimer bajo el badge en `splash_screen.dart`; `flutter analyze`.
- [x] `flutter analyze` sin problemas (`No issues found!`).

## Evidence
- El `build` de `SplashScreen` es común a todas las presentaciones (la estación solo cambia
  fondo/colores/efectos/audio): `_buildDevBadge()` se pinta siempre al final de la columna.
- Los logos existen en `assets/images/` raíz sin entrada en `pubspec.yaml` (solo están
  registrados `icons/surfer.svg` y `icons/spaceship.svg` de esa zona).
- `flutter_svg` ya es dependencia (`^2.2.2`) y se usa en player/juegos/waveform.
- ARB de splash existentes: `splashTagline`, `splashWatch/Read/Play/Anything`.
- Repositorio en rama `main`.
- `splash_screen.dart`: `_buildPlatformDisclaimer()` bajo `_buildDevBadge()` (texto ARB +
  `SvgPicture` para `android.svg` e `Image.asset` para `Linux-Logo.png`/`windows.png`, 28 px,
  con `semanticsLabel` por plataforma); vale para todas las estaciones al estar en el `build`
  común.
- ARB `splashAvailableOn` ("Available on:"/"Disponible en:") generada con `flutter gen-l10n`
  (getters presentes en `app_localizations*.dart`); `pubspec.yaml` registra los 3 logos.
- `flutter analyze` → `No issues found! (ran in 16.8s)`.

## Next
Revisar visualmente el tamaño de los logos sobre fondos claros (p. ej. `halloween_back`) y
oscuros; si el SVG de Android no contrasta, aplicarle color o fondo.
