# Trick-play boost estilo Amazon (x64 efectivo)

## Intent
El avance a 64x con `setRate` real se atasca (mpv/HLS no dan 64x de decodificación/red) y la reversa con seeks literales (`velocidad × 250ms`) cruza una peli de 2h en ~112s. Igualar la sensación de Amazon/Movistar manteniendo las etiquetas `2x…64x`.

## Scope
- In: `lib/features/player/presentation/player_screen.dart` (`_trickSpeeds`, `_trickTick`, `_enterTrickPlay`, `_applyTrickLevel`, `_trickRewindTick`, tick de avance nuevo).
- Out: insignia `ffBadge` (tamaño de fuente pendiente en cambio aparte), `PrimeCardBadge`, audio (sigue con saltos de 10s).

## Checklist
- [x] Añadir `_trickSeekBoost = 4.0` y unificar avance/reversa a seeks periódicos (`salto = velocidad × intervalo × boost`).
- [x] Posición optimista por tick + clamps a cero/duración.
- [x] `flutter analyze` sin issues.
- [x] `flutter analyze lib/features/player/presentation/player_screen.dart` → "No issues found!" (2.6s).
- [ ] Prueba manual DirectPlay y HLS a 2x/16x/64x (cronometrar cruce).

## Evidence
- Código: `_enterTrickPlay` pausaba solo en reversa y avance usaba `setRate`; `_trickRewindTick` con salto literal.
- Implementado: `_trickSeekBoost = 4.0`, `_enterTrickPlay` unificado (pause + `Timer.periodic` → `_trickSeekTick`), `_applyTrickLevel` sin `setRate`, posición optimista + clamps en `_trickSeekTick`.
- `flutter analyze lib/features/player/presentation/player_screen.dart` → "No issues found!".

## Next
- Ejecutar `flutter analyze`; prueba manual en DirectPlay + HLS; ajustar boost a 5 si se quiere más agresivo.
