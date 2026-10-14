# Sugerencias estacionales en Inicio

## Intent
Mostrar automáticamente en Inicio una fila de películas y series relacionadas con fechas temáticas del calendario, en todos los skins, y permitir al usuario activar o desactivar la función desde Preferencias con el ajuste persistido.

## Scope
- In:
  - Una preferencia persistente para habilitar las sugerencias estacionales.
  - Identificación de temáticas de calendario y búsqueda de títulos en la biblioteca Jellyfin del usuario.
  - Una fila reutilizable en Inicio con las tarjetas y navegación comunes existentes, solo visible cuando corresponda y haya resultados.
  - Textos localizados en español e inglés y traducciones generadas.
- Out:
  - Personalización de la temporada por ubicación/hemisferio.
  - Contenido externo a la biblioteca del usuario.

## Checklist
- [x] Preferencia persistente integrada en Ajustes > Preferencias; comprobar en código lectura/escritura con `SharedPreferences` y ejecutar `flutter analyze`.
- [x] Selección de temática según calendario y consulta de títulos Jellyfin; comprobar selección/consulta en código y ejecutar `flutter analyze`.
- [x] Fila estacional reutilizable integrada en todos los layouts de Inicio; comprobar ambos puntos de inserción y ejecutar `flutter analyze`.
- [x] Traducciones ARB en español e inglés generadas; ejecutar `flutter gen-l10n` y comprobar getters generados.
- [x] Análisis estático sin problemas; demostrar salida de `flutter analyze`.

## Evidence
- `HomeScreen` es común: crea sus filas para skins con layout heredado y layout personalizado; las sugerencias de ánimo existentes se insertan en el Inicio.
- `ContentRow` ya presenta tarjetas universales con hover y navegación configurable.
- `ThemeModeNotifier` muestra el patrón local de persistencia con `SharedPreferences`; Ajustes > Preferencias agrupa idioma y tema.
- El repositorio está actualmente en la rama `main`.
- `SeasonalSuggestionsNotifier` lee `jellyfin.seasonal_suggestions_enabled` (valor predeterminado activado) y persiste cambios con `setBool`; Ajustes presenta el switch bajo Preferencias.
- `seasonalEventForDate` detecta Halloween (octubre), Navidad (diciembre–6 de enero), San Valentín (1–14 de febrero) y Pascua (dos semanas antes hasta el lunes de Pascua).
- `seasonalSuggestionItemsProvider` llama a `getItemsApi().getItems` para películas/series, buscando términos en español e inglés; deduplica resultados y prioriza títulos no vistos.
- `SeasonalSuggestionsRow` omite la fila si está desactivada, fuera de las fechas configuradas o sin resultados; muestra `AppLoader` durante la búsqueda y usa `ContentRow` para las tarjetas. `HomeScreen` la añade tanto al layout heredado como al personalizado.
- La fila es además un `LayoutSection` propio (`LayoutSectionType.seasonal`,
  `LayoutSection.seasonal()`), así que se puede **ubicar desde los presets** en
  `homeLayout`/`vodLayout`. En layouts custom solo aparece si el preset incluye
  la sección; en layouts heredados se inserta tras las sugerencias de ánimo.
  Preset Disney+ la coloca tras el featured slider. `home_screen.dart` y
  `vod_screen.dart` resuelven la sección; en el cálculo de backdrops es no-op.
- `SeasonalSuggestionsRow` añade `kBetweenSectionsGap` como espacio superior
  (solo cuando renderiza la fila o su loader) para separarla de las sugerencias
  de ánimo; cuando está oculta no ocupa espacio.
- **Badge por tarjeta**: assets `assets/images/seasonal/*.webp` (Halloween,
  Navidad, San Valentín, Pascua) + carpeta registrada en `pubspec.yaml`.
  `seasonalBadgeAsset(SeasonalEvent)` en `core/seasonal/seasonal_event.dart`
  mapea evento → asset (`.webp`). Nuevo `core/widgets/seasonal_card_badge.dart`
  (disco oscuro translúcido + `Image.asset` con la imagen webp, `IgnorePointer`).
  `PosterCard`/`BackdropCard` tienen `Widget? cornerBadge` y lo pintan
  arriba-izquierda (`top/left: 6`); `ContentRow` lo reenvía;
  `SeasonalSuggestionsRow` construye el badge del evento. No se tocó
  `PrimeCardBadge` (arriba-derecha).
- `flutter gen-l10n` completó con la configuración de `l10n.yaml`; los getters estacionales aparecen en `app_localizations.dart`, `app_localizations_en.dart` y `app_localizations_es.dart`.
- `flutter analyze` → `No issues found!`.

## Teñido estacional del skin
- Núcleo en `lib/core/seasonal/seasonal_event.dart`: `SeasonalEvent` y
  `seasonalEventForDate` movidos a core (los usa también el teñido); más
  `SeasonalPalette`/`kSeasonalPalettes` (colores por temática) y
  `tintSkinForSeason(base, event, intensity)` (mezcla con `Color.lerp` sobre
  fondo arriba/abajo, acento y primario). El feature `seasonal_suggestion.dart`
  reexporta el evento desde core.
- Preferencias separadas en `lib/core/settings/seasonal_theme_controller.dart`:
  `seasonalThemeEnabledProvider` (bool, por defecto activado) y
  `seasonalThemeIntensityProvider` (double 0..1, por defecto 0.35), persistidas
  en `jellyfin.seasonal_theme_enabled` / `jellyfin.seasonal_theme_intensity`.
- `lib/core/skin/effective_skin_provider.dart`: devuelve el skin teñido cuando
  el tema estacional está activado y hay temática activa; si no, el skin tal
  cual. No modifica el skin persistido.
- Aplicado en `app.dart` (`AppTheme.fromSkin(effectiveSkin)`) y en
  `DashboardBackground` (`SkinScope.maybeOf(context) ?? effectiveSkinProvider`,
  respetando pantallas con skin fijo como el E-Reader).
- Ajustes > Preferencias: tarjeta "Tema estacional" con interruptor y slider de
  intensidad (0–100%, 20 pasos) visible solo si está activado.
- Alcance acordado: fondo + acento + primario (sin secundario ni barra lateral).
- ARB: `seasonalTheme`, `seasonalThemeHint`, `seasonalThemeIntensity` (EN+ES) +
  `flutter gen-l10n`.
- `flutter analyze` → `No issues found!`.

## Géneros de Halloween (sin acción)
- `seasonalEventGenres` pasa a devolver `List<String>` (nombres exactos de la
  API) para poder cubrir bibliotecas en inglés y español. Halloween ahora usa
  `['Horror', 'Terror', 'Suspense']` (antes horror/mystery/thriller).
- `seasonalSuggestionItemsProvider` filtra las coincidencias por **nombre** a
  los géneros de la temática (case-insensitive), de modo que un título de otro
  género (p. ej. Acción) no entre en Halloween. Los títulos sin género declarado
  se conservan. Las coincidencias por género (ya restringidas por la API) no se
  filtran.
- `flutter analyze` → `No issues found!`.

## Layout configurable de la sección seasonal
- La fila ignoraba el `HomeScroll` de `LayoutSection.seasonal(...)`, así que su
  config (poster/backdrop, `imageSource`, `metaOverlay`, `bottomVignette`,
  `showLogo`/`logoPosition`/`logoSize`, `hideTitle`, alineación, hover, etc.) no
  se aplicaba. Ahora `SeasonalSuggestionsRow(scroll: …)` reenvía toda esa config
  a `ContentRow` (como el resto de filas).
- `sort` se respeta: el proveedor pasa a ser family de
  `(SeasonalEvent, HomeScrollSort)` y usa `homeScrollSortParams`; solo se
  baraja (variedad) cuando el orden es `random`.
- `tapAction` se respeta (detalle o reproducción); el tap en la imagen abre el
  detalle.
- `home_screen.dart` y `vod_screen.dart` pasan `section.scroll` a la fila.
- El título es siempre el de la temática activa (`seasonalEventTitle`), no el
  `titleKey` del scroll; las cadenas ya existen en ARB
  (`seasonalHalloween`, `seasonalChristmas`, `seasonalValentinesDay`,
  `seasonalEaster`).
- `flutter analyze` → `No issues found!`.

## Next
Probar en la app con Jellyfin que el ajuste se conserva al reiniciar y que la fila aparece con títulos pertinentes durante cada periodo temático. Validar visualmente el matiz estacional (intensidad por defecto 35%) en varios skins y ajustar la paleta si choca con Prime/Disney.

## Corrección (no aparecía la fila)
- Causa: la primera versión solo buscaba por término de texto ("Halloween",
  "Navidad"...). Si la biblioteca no tiene títulos con ese nombre literal, la
  fila quedaba vacía. Las sugerencias de ánimo sí funcionaban porque consultan
  por **género**.
- Fix: `seasonalSuggestionItemsProvider` ahora combina búsqueda por término
  (coincidencias reales) con búsqueda por género (garantiza contenido).
  `seasonalEventGenres` añade géneros por temática (Halloween → terror/misterio/
  suspense; Navidad → familia/infantil/animación; San Valentín → romance/drama/
  comedia; Pascua → familia/aventura/animación). El dedupe prioriza el término.
- Además la fila se movió junto a las sugerencias de ánimo (arriba), en lugar
  del final de Inicio, para que sea visible sin desplazarse.
- `flutter analyze` → `No issues found!`.
