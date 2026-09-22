# Formato de fecha localizado según idioma

## Intent
Las fechas de juegos usaban formatos fijos (`dd.MM.yyyy` en detalle, `dd/MM HH:mm` en "Continuar jugando"). Localizarlos con `intl` según `l10n.localeName` (es → `12/3/1998`, en → `3/12/1998`).

## Scope
- In: `_formatDate` en `game_detail_screen.dart` → `DateFormat.yMd(locale)`; `_formatLastPlayed` en `game_continue_card.dart` → `DateFormat.yMd(locale).add_Hm()`. Aplica a fecha de lanzamiento y última vez jugada.
- Out: otros formatos fijos de la app fuera de juegos; cadenas ARB (no hay texto nuevo, solo formato).

## Checklist
- [x] Detalle usa `yMd(locale)` — `flutter analyze` sin issues
- [x] `GameContinueCard` usa `yMd(locale).add_Hm()` — `flutter analyze` sin issues
- [x] Coherente con precedente `person_detail_screen.dart` (`yMMMMd(l10n.localeName)`)

## Evidence
- `flutter analyze lib/features/games/presentation/game_detail_screen.dart` → "No issues found!"
- `flutter analyze lib/features/games/presentation/widgets/game_continue_card.dart lib/features/games/presentation/game_detail_screen.dart` → "No issues found!"

## Next
Opcional: rastrear si quedan más `DateFormat('dd/MM...')` fijos en la app (pendiente de confirmación del usuario).
