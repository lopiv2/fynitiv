# Logo de máquina junto a plataforma en detalle de juego

## Intent
En el detalle del juego el stat de plataforma solo muestra texto. Poner el logo de máquina (consola) a la izquierda del nombre de la plataforma, en tamaño no muy grande, reutilizando el resolver ya existente.

## Scope
- In: `game_detail_screen.dart` (`_GameHeroInfo` con fila-plataforma bajo el título); resolución con `PlatformMachineAssetResolver` a partir de `platformId/slug/displayName` del juego; `Image.asset` contenido (40x26) con `errorBuilder` a vacío; stat de plataforma fuera del `Wrap` (quedan 4 stats).
- Out: cambios en lista/cards de plataformas, nuevos assets, cadenas ARB (sin texto nuevo de UI), cambios en `RommGame`/`RommPlatform`.

## Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] Resolver machine asset en `_GameHeroInfo` (sintético `RommPlatform`, null-safe)
- [x] Fila-plataforma bajo `_GameTitle`: `Row` icono (40x26) + nombre (14/w600, ellipsis)
- [x] Stat de plataforma eliminado del `Wrap`; `_Stat` vuelve a su forma simple
- [x] `flutter analyze` sin issues en el fichero tocado

## Evidence
- `flutter analyze lib/features/games/presentation/game_detail_screen.dart` → "No issues found!" (tras mover a opción 1)
- Implementación: `_GameHeroInfo` resuelve con `PlatformMachineAssetResolver` (id/slug/displayName del juego); fila bajo el título con `Image.asset(40x26, contain, errorBuilder→vacío)` a la izquierda del nombre; sin asset se ve solo el texto como antes.

## Next
- Confirmación visual del usuario en un juego con máquina conocida (p. ej. NES/SNES/PS1) y en uno sin asset (debe verse solo el texto como antes).
