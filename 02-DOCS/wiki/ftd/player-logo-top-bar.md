# Logo de película/serie en el player

## Intent
La barra superior del player de vídeo muestra siempre el nombre en texto. Jellyfin expone el logo del item (`ImageType.logo`, con respaldo al padre vía `parentLogoItemId` para episodios): mostrarlo arriba a la izquierda en lugar del texto, con fallback al `Text` actual cuando no haya logo o falle la carga.

## Scope
- In: `_buildOverlay` en `lib/features/player/presentation/player_screen.dart` — resuelve detalle vía `itemDetailProvider(itemId) ?? widget.item`, calcula `itemLogoUrl(serverUrl, detail)` y pinta `Image.network` (contain, alineado a la izquierda, altura fija) con `errorBuilder` → título actual.
- Out: modo audio (`_AudioCover` ya muestra logo), overlay del skin (`_buildLogoOverlay`), cadenas ARB (sin texto nuevo de UI).

## Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] Barra superior pinta logo con fallback a texto
- [x] `flutter analyze` sin issues en el fichero tocado

## Evidence
- `flutter analyze lib/features/player/presentation/player_screen.dart` → "No issues found!".
- Sin cadenas ARB nuevas (sin texto nuevo de UI).

## Next
- Confirmación visual del usuario en una peli con logo y en una sin logo (debe verse el título como antes).
