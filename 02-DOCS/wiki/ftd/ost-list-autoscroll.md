# Auto-scroll de la lista OST al cambiar de pista

## Intent
El scroll de la lista de temas no salta a la pista en curso. Causa: `_scrollToCurrent` solo hacía scroll cuando `GameOstPlayer.sounding == true`, con 8 reintentos de 300ms (2,4s). Con archive.org (MP3 streaming) bastaba; con ROMM (`loadUrl` descarga el FLAC completo a temporal antes de sonar) se agota el presupuesto y nunca salta, sobre todo en pistas grandes o cambio manual.

## Scope
- In: `_OstTrackList._scrollToCurrent` en `game_detail_screen.dart`: scroll inmediato al cambiar la pista (sigue al resaltado, que ya es inmediato) + re-afirmado tardío por si el layout aún asentaba.
- Out: lógica de reproducción, resto de la UI.

## Checklist
- [x] FTD doc creado antes del primer cambio — este fichero
- [x] Intento 1: scroll inmediato sin esperar `sounding` — `flutter analyze` OK, pero el usuario confirma que sigue sin saltar
- [x] Intento 2: el `ListView.builder` solo monta items visibles → si el item no tiene contexto, acercar scroll estimado (idx×64) y reintentar (6×300ms) + logs `[OST-LIST]` + dedupe `_lastJumpUrl` — `flutter analyze` sin issues
- [ ] Confirmación visual del usuario pasando de pista (y pegar líneas `[OST-LIST]` de consola si sigue fallando)

## Evidence
- `flutter analyze lib/features/games/presentation/game_detail_screen.dart` → "No issues found!" (ambos intentos)

## Next
`flutter analyze` y prueba del usuario pasando de pista.
