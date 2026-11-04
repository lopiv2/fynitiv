# FTD — Presentación splash Pascua

## Intent

Crear la presentación de splash de Pascua con el arte aportado por el usuario (`easter_back.jpg` + `easter_splash.mp3`), siguiendo el modelo `SplashPresentation` (Halloween/Navidad/San Valentín): fondo nocturno por fundido, paleta morada de la temática y enjambre de luciérnagas volando con parpadeo (fondo + primer plano).

## Scope

- Nuevo `lib/features/splash/presentation/presentations/easter_splash_presentation.dart` (modelo + efectos puros del progreso: fondo, brillo y luciérnagas).
- Registro en `splash_presentations.dart`: `easter` → nueva presentación.
- `pubspec.yaml`: registrar `assets/audio/easter_splash.mp3` (la carpeta `seasonal/` ya cubre el jpg).
- `lib/main.dart`: precargar el audio nuevo.
- Sin cambios de textos (no ARB), sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] FTD creado antes del primer cambio.
- [x] Presentación `kEasterSplashPresentation` (audio, fondo, paleta, `easterBackEffect` + brillo + luciérnagas fondo/frente con parpadeo).
- [x] Registro en `splashPresentationFor`.
- [x] `pubspec.yaml` + `main.dart` con el audio nuevo.
- [x] `flutter analyze` limpio.

## Evidence

- `flutter analyze lib/features/splash/presentation/presentations/easter_splash_presentation.dart lib/features/splash/presentation/presentations/splash_presentations.dart lib/main.dart lib/router/splash_screen.dart` → No issues found.
- `splashPresentationFor(easter)` → `kEasterSplashPresentation` (audio `easter_splash.mp3`, fondo `easter_back.jpg` por fundido 8%→43%, brillo cálido inferior, 70 luciérnagas + 12 en frente con deriva errática, halo y parpadeo propio; icono oro con sombras oscuras para fondo nocturno).
- `pubspec.yaml` registra `assets/audio/easter_splash.mp3`; `main.dart` lo precarga; `assets/images/seasonal/` ya cubría el jpg.

## Next

- Verificar con override `easter` en Apariencia/barra debug (fundido del fondo, luciérnagas y legibilidad del logo/tagline sobre fondo nocturno).
