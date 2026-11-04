# FTD — Pétalos de rosa en splash San Valentín

## Intent

Añadir pétalos de rosa volando a la presentación de San Valentín, además de los corazones existentes: caída lateral con giro y balanceo, en dos capas (fondo + primer plano tenue) como en el resto de presentaciones.

## Scope

- Solo `lib/features/splash/presentation/presentations/valentines_splash_presentation.dart` (nuevo `_PetalsPainter` + `valentinesPetalsEffect` / `valentinesForegroundPetalsEffect`, registro en `backgroundEffects`/`effects`).
- Sin cambios de textos (no ARB), sin navegación, sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] FTD creado antes del primer cambio.
- [x] Pétalos fondo + frente añadidos sin quitar los corazones.
- [x] `flutter analyze` limpio.

## Evidence

- `flutter analyze lib/features/splash/presentation/presentations/valentines_splash_presentation.dart` → No issues found.
- `backgroundEffects`: `valentinesPetalsEffect` (50 pétalos); `effects`: `valentinesForegroundPetalsEffect` (10 pétalos grandes tenues). Los corazones existentes quedan intactos.

## Next

- Verificar con override `valentinesDay` (pétalos + corazones legibles, sin tapar el logo).
