# FTD — Presentación splash San Valentín

## Intent

Crear la presentación de splash de San Valentín con el arte aportado por el usuario (`valentine_back.jpg` + `valentines_splash_reveal.mp3`), siguiendo el modelo `SplashPresentation` (Halloween/Navidad): fondo por fundido, paleta rosa de la temática, icono con contraste sobre fondo claro y pétalos/corazones flotando.

## Scope

- Nuevo `lib/features/splash/presentation/presentations/valentines_splash_presentation.dart` (modelo + efectos puros del progreso).
- Registro en `splash_presentations.dart`: `valentinesDay` → nueva presentación (Pascua sigue en default).
- `pubspec.yaml`: registrar `assets/audio/valentines_splash_reveal.mp3` (la carpeta `seasonal/` ya cubre el jpg).
- `lib/main.dart`: precargar el audio nuevo.
- Sin cambios de textos (no ARB), sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] FTD creado antes del primer cambio.
- [x] Presentación `kValentinesSplashPresentation` (audio, fondo, paleta, icono con sombras, `valentineBackEffect` + brillo + corazones fondo/frente).
- [x] Registro en `splashPresentationFor`.
- [x] `pubspec.yaml` + `main.dart` con el audio nuevo.
- [x] `flutter analyze` limpio.

## Evidence

- `flutter analyze lib/features/splash/presentation/presentations/valentines_splash_presentation.dart lib/features/splash/presentation/presentations/splash_presentations.dart lib/main.dart lib/router/splash_screen.dart` → No issues found.
- `splashPresentationFor(valentinesDay)` → `kValentinesSplashPresentation` (audio `valentines_splash_reveal.mp3`, fondo `valentine_back.jpg` por fundido 8%→43%, brillo rosa inferior, 70 corazones + 12 en frente; icono rosa con sombras oscuras para fondo claro).
- `pubspec.yaml` registra `assets/audio/valentines_splash_reveal.mp3`; `main.dart` lo precarga; `assets/images/seasonal/` ya cubría el jpg.

## Next

- Verificar con override `valentinesDay` en Apariencia/barra debug (fundido del fondo, corazones y legibilidad del logo/tagline sobre fondo claro).
