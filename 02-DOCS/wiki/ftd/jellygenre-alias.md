# Alias por género en JellyGenre

## Intent
Que cada valor del enum admita varios nombres de la API (p. ej. sciFi = Science Fiction, Sci-Fi, SciFi, Ciencia ficción) para que los scrolls filtren aunque el servidor etiquete distinto.

## Scope
- In:
  - `JellyGenre`: lista `aliases` + `allValues` (principal + alias); `_byValue`/`fromValue` resuelven alias; helper `jellyGenresFilter` para el OR con `|`.
  - Queries `homeScrollItemsProvider` y `fetchRandomMoodItem`: expanden alias. JSON sigue guardando el principal (compatible).
- Out:
  - No tocar `MusicScroll` (strings), presets ni editor; sin ARB; sin tests (no pedidos) y sin `flutter build` (solo `flutter analyze`).

## Checklist
- [ ] Enum con alias + helper; comprobar `flutter analyze`.
- [ ] 2 queries con alias; comprobar `flutter analyze`.
- [ ] `flutter analyze` sin problemas; demostrar salida.

## Evidence
- `home_scroll.dart`: `JellyGenre(value, [aliases])` + `allValues`; `_byValue`/`fromValue` con alias; helper `jellyGenresFilter` (OR con `|`). Alias solo en inglés (`Sci-Fi`/`SciFi`, `Children`); resto valor único.
- `library_providers.dart` (`homeScrollItemsProvider`) y `mood_providers.dart` (`fetchRandomMoodItem`): expanden alias. JSON guarda el principal (compatible); `MusicScroll` intacto (strings).
- `flutter analyze` → `No issues found! (ran en 10.3s)`.

## Next
- Probar un scroll de sciFi contra un servidor con etiquetas distintas.
