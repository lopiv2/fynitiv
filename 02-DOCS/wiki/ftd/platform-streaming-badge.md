# Intent
Badge verde de play arriba-derecha en las tarjetas de plataforma de Juego online cuando la plataforma tiene streaming en navegador (como ROMM original). Solo se muestra si disponible; nada mientras carga.

# Scope
- `romm_repository.dart`: `streamingPlatformSlugs()` (parsea `containers` una vez).
- `romm_providers.dart`: `rommStreamingSlugsProvider` + family reescrito encima (nadie lo usaba).
- `games_screen.dart` (`_PlatformCard`): `Stack` + badge verde con tooltip ARB. Sin tocar `PrimeCardBadge` ni el hover.
- ARB EN+ES `gamesPlayInBrowser` + `gen-l10n`. Sin tests, sin build; solo `analyze`.

# Checklist
- [x] `streamingPlatformSlugs()` en el repo
- [x] Providers compartidos (single fetch + select por card)
- [x] Badge + tooltip en `_PlatformCard`
- [x] ARB EN+ES + `gen-l10n` + `flutter analyze` limpio

# Evidence
- `flutter gen-l10n`: getter `gamesPlayInBrowser` generado.
- `flutter analyze --no-pub` (28/09/2026): `No issues found!` (en el camino se cazó un `unchecked_use_of_nullable_value` en el set-literal y se reescribió con bucle).
- Verde fijo `0xFF2ED9A3` según respuesta del usuario; `hasStreamingFor` conservado y reescrito encima del nuevo método.

# Next
- Si se pide: badge también en la lista de plataformas (`game_list_screen`) o tap directo a streaming.
