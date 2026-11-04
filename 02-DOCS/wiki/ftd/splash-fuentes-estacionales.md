# FTD — Fuentes estacionales en splash

## Intent

Usar las fuentes aportadas por el usuario en el texto de la presentación (título FYNITIV vía `titleFontFamily`): `PWHappyChristmas` en Navidad, `HEARRG__` en San Valentín y `EGGS` en Pascua, igual que Halloween usa `SuperMidnight`.

## Scope

- `pubspec.yaml`: registrar las familias nuevas (`assets/fonts/` ya contiene los ttf; se mantiene `BunnyRabbits` registrada).
- `christmas_splash_presentation.dart`: `titleFontFamily: 'PWHappyChristmas'`.
- `valentines_splash_presentation.dart`: `titleFontFamily: 'Hearrg'`.
- `easter_splash_presentation.dart`: `titleFontFamily: 'Eggs'`.
- Sin cambios de textos (no ARB), sin navegación, sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] FTD creado antes del primer cambio.
- [x] 3 familias registradas en `pubspec.yaml`.
- [x] `titleFontFamily` fijado en las 3 presentaciones.
- [x] `flutter analyze` limpio.

## Evidence

- `flutter analyze lib/features/splash/presentation/presentations/christmas_splash_presentation.dart lib/features/splash/presentation/presentations/valentines_splash_presentation.dart lib/features/splash/presentation/presentations/easter_splash_presentation.dart` → No issues found.
- `pubspec.yaml`: familias `PWHappyChristmas` (`PWHappyChristmas.ttf`), `KingthingsChristmas` (`Kingthings Christmas 2.2.ttf`), `Hearrg` (`HEARRG__.TTF`), `BunnyRabbits` (`Bunny Rabbits.ttf`), `Eggs` (`EGGS.TTF`), `Chrici` (`CHRICI__.TTF`).
- Navidad → `titleFontFamily: 'Chrici'` (antes `PWHappyChristmas` y `KingthingsChristmas`, eliminada junto a sus ficheros); San Valentín → `'Hearrg'`; Pascua → `'Eggs'`.
- Cambio posterior: Pascua pasa de `'BunnyRabbits'` a `'Eggs'`; `flutter analyze lib/features/splash/presentation/presentations/easter_splash_presentation.dart` → No issues found.

## Next

- Verificar con overrides `christmas` / `valentinesDay` / `easter` (título con la fuente nueva y legible sobre cada fondo).
