# Botón Reanudar T/E en hover Prime de series

## Intent
En el skin Prime, el botón del panel hover de una serie en curso muestra "Reanudar T1 E18" (temporada/episodio reales del capítulo), como la foto.

## Scope
- In:
  - ARB `resumeSeasonEpisode` ("Reanudar T{season} E{episode}" / "Resume S{season} E{episode}") + `flutter gen-l10n`.
  - Helper compartido `primeSeriesResumeLabel` en `hover_play_card.dart` (solo Prime + episodio con progreso y S/E; resto `null` → "Reanudar").
  - `BackdropCard` y `PosterCard`: `hoverActionLabel ?? primeSeriesResumeLabel(...)`.
- Out:
  - No tocar otros skins, panel ni navegación; sin tests (no pedidos) y sin `flutter build` (solo `flutter analyze`).

## Checklist
- [ ] ARB + helper + 2 tarjetas; comprobar `flutter analyze`.
- [ ] `flutter analyze` sin problemas; demostrar salida.

## Evidence
- ARB `resumeSeasonEpisode` (ES/EN con placeholders int) + `flutter gen-l10n`; helper `primeSeriesResumeLabel` en `hover_play_card.dart` (Prime + episodio con progreso y S/E reales; resto `null`).
- `BackdropCard` y `PosterCard`: `hoverActionLabel ?? primeSeriesResumeLabel(...)` sin tocar navegación ni panel.
- `flutter analyze` → `No issues found! (ran en 10.7s)`.

## Next
- Probar en Prime con una serie a medias: el botón debe decir su T/E reales.
