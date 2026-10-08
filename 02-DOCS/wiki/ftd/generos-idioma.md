# Géneros de Jellyfin traducidos al idioma de la app

## Intent
Los géneros que devuelve Jellyfin (normalmente en inglés: `Action`, `Science
Fiction`, `Horror`…) se muestran en crudo en tarjetas y detalles. Traducirlos al
locale activo para que se lean correctamente, sin tocar los usos donde el género
es un dato (filtros de API, badge, Auto-EQ).

## Scope
- In: helper central `localizeGenre`/`localizeGenres` + claves ARB `genre*`
  (EN+ES); aplicación en display de `poster_card`, `backdrop_card`,
  `featured_slider`, `item_detail_screen`, `book_detail_screen`, `music_screen`
  y `playlist_detail_screen`. Fallback al original si no se reconoce.
- Out: `card_badge_resolver` (no muestra género), `library_providers` (filtros a
  la API), `player_screen`/`auto_eq_toggle` (matching Auto-EQ), edición de
  metadatos en Jellyfin.

## Checklist
- [x] FTD antes del primer cambio
- [x] Claves ARB genre* EN+ES + `flutter gen-l10n`
- [x] Helper `genre_localizer.dart` con normalización y fallback
- [x] Aplicar en todas las vistas de display
- [x] No tocar usos de género como dato
- [x] `flutter analyze` limpio

## Evidence
- ARB: añadidas 28 claves `genre*` en `app_en.arb` y `app_es.arb`;
  `flutter gen-l10n` genera los getters (`app_localizations.dart:2235` +
  `genreAction`).
- Helper `lib/l10n/genre_localizer.dart`: `localizeGenre`/`localizeGenres`
  normalizan (trim, minúsculas, sin acentos, espacios colapsados) y resuelven
  variantes EN/ES (`sci-fi`/`science fiction`, `action & adventure`,
  `sci-fi & fantasy`, `war & politics`, `kids`...). Fallback al original.
- Display traducido: `poster_card` y `backdrop_card` (`_MetaLine` + subtítulo),
  `featured_slider` (inline meta y banner), `item_detail_screen`
  (`_DetailMeta`/`_LinkText` + meta de serie), `book_detail_screen`
  (`_LinkText`/`_DetailMeta` + meta de serie), `music_screen` y
  `playlist_detail_screen` (etiqueta de género).
- Sin tocar: `card_badge_resolver.dart`, `library_providers.dart` (filtros API),
  `player_screen.dart`/`auto_eq_toggle.dart` (Auto-EQ).
- `flutter analyze` → `No issues found!`.
- Verificado por el usuario en app contra servidor real: los géneros se
  muestran traducidos correctamente.

## Next
- Cerrado. No hay pasos pendientes.

