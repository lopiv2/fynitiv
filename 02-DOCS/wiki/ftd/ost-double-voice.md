# OST suena dos veces a la vez (doble voz)

## Intent
A veces la misma canción del OST suena duplicada (efecto coro). El singleton `GameOstPlayer` permite dos `playUrl` concurrentes sobre el mismo `SoloudSinglePlayer`: ambos superan el chequeo de sesión (es la MISMA sesión) y lanzan dos voces; solo una queda trackeada y la otra suena huérfana hasta el final.

## Scope
- In: `SoloudSinglePlayer.playUrl/playAsset` (guardia de generación: solo la última carga lanza; `stop()` cancela cargas en curso) y `GameOstPlayer._playCurrent` (dedup de re-entrada con misma sesión en carga + no matar la voz del nuevo dueño en rama stale).
- Out: cambios UI, ARB, otros players (Bg/Theme usan su propio `SoloudSinglePlayer`; se benefician del guardia sin tocarlos).

## Checklist
- [x] FTD doc creado antes del primer cambio — este fichero
- [x] Disparador localizado: `game_detail_screen.dart:79` (`resumeIfNeeded` en cada `resumed`) con `state==idle` durante la carga lenta del FLAC → `_playCurrent(misma sesión)` concurrente; también `setMuted` (línea 186-187) durante la carga
- [x] Guardia `_loadGen` en `SoloudSinglePlayer` (playUrl/playAsset + `stop()` cancela)
- [x] Dedup `_loadingSession` en `_playCurrent` + rama stale sin `stop()` ajeno
- [x] `flutter analyze` (soloud_single_player, game_ost_player) → "No issues found!"

## Evidence
- Log usuario: un solo `playQueue` + un solo `play idx=0` pero doble audio = dos voces, no dos queues.
- `game_ost_player.dart:139-171`: el chequeo `session != _session` tras `playUrl` no cubre re-entrada con la MISMA sesión (ambas la pasan).
- `soloud_single_player.dart:77-96`: `playUrl` hace `stopVoice` + `loadUrl` lento + `_launch` sin comprobar si otra carga lo adelantó.
- `flutter analyze` (soloud_single_player, game_ost_player) → pendiente.

## Next
Abrir detalle con OST, cambiar foco de ventana durante la carga inicial y confirmar una sola voz.
