# Logo del juego en lugar del título en el detalle

## Intent
El detalle muestra siempre el título en texto. RomM envía el logo (wheel) en `ss_metadata` (`logo_path`/`logo_url`): mostrarlo como cabecera del hero y dejar el texto actual como fallback cuando no haya logo o falle la carga.

## Scope
- In: `RommGame.logoUrl` + mapeo en `_mapGame` (reusa `_metaArtworkUrl`: `logo_path` → `/assets/romm/resources/...`, fallback `logo_url`); `_GameHeroInfo` en `game_detail_screen.dart` muestra `Image.network` con `headers` de auth y `errorBuilder` → título actual.
- Out: otros providers con logo (LaunchBox/SteamGridDB), cambios en lista/cards, cadenas ARB (sin texto nuevo de UI).

## Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] `logoUrl` en `RommGame` (+ `copyWith`) y mapeo en `_mapGame`
- [x] `_GameHeroInfo` recibe `headers` y pinta logo (contain, alineado a la izquierda) con fallback al `Text` actual
- [x] `flutter analyze` sin issues en los ficheros tocados

## Evidence
- `backend/handler/metadata/ss_handler.py` (master RomM): `SSMetadataMedia` con `logo_url` (wheel-hd/wheel) y `logo_path` (solo si `LOGO` está en `scan.media`); `RomSchema` expone `ss_metadata` en lista y detalle.
- Limitación conocida: `logo_url` remota va sin credenciales SS (strip), puede no cargar → el `errorBuilder` deja el título como hoy.

- Implementación: `_GameTitle` (logo con `loadingBuilder`/`errorBuilder` → título), `headers` con Bearer en ambas llamadas (compact + wide); `flutter analyze` en los 3 ficheros → "No issues found!".

## Next
Confirmación visual del usuario en un juego con logo (y en uno sin logo, que debe verse el título como antes).
