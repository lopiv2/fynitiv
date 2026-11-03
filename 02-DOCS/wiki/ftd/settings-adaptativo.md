# Ajustes adaptativo (TV / móvil / tablet / escritorio)

## Intent

Rehacer la pantalla de Ajustes (`/settings`) para que sea óptima en tamaño y
distribución en los cuatro perfiles reales de la app —Android TV, móvil,
tablet y escritorio—, sustituyendo el layout actual (breakpoint único
`width >= 700`, `maxWidth` fijo 560/620 por panel y densidad heredada del
escritorio en TV) por tres piezas compartidas: **tokens de densidad**,
**scaffold único** y **filas de ajuste agrupadas**.

Este documento queda **en implementación Fase 1–2 (Preferencias)** con las
decisiones ya tomadas el 2026-11-03 (una sola página con scroll por
sección; filas agrupadas con divisor; `?section=` aparcado: se corrige
el doc, no se recupera deep-link en esta fase).

## Scope

### In

- Shell de Ajustes (`settings_screen.dart`): navegación adaptativa + scaffold.
- Los cinco paneles actuales (`preferences`, `appearance`, `home`,
  `games`, `sounds`) y los dos informativos (`account`, `about`).
- Densidad específica de TV (fuente, alto de fila, overscan, foco).
- Nuevas cadenas ARB `es`/`en` para cabeceras de grupo (si se aprueban los grupos).

### Out

- Lógica de negocio de cada ajuste (controladores Riverpod, Jellyfin, ROMM).
- Otros skins, `PrimeCardBadge` y posiciones ya ajustadas a mano.
- Tests (no pedidos) y `flutter build` (solo `flutter analyze`).

### Diagnóstico (estado actual)

Evidencia de código, no impresiones:

| Hallazgo | Evidencia |
|---|---|
| Un único breakpoint: menú lateral a partir de 700 px | `settings_screen.dart:63` `final useMenu = width >= 700` |
| Menú lateral de ancho fijo 240 en cualquier pantalla | `settings_screen.dart:120` `width: 240` |
| Cuatro scaffolds duplicados con anchos distintos | `settings_screen.dart:205-209` (560), `sounds_panel.dart:18-22` (560), `games_panel.dart:75-79` (560), `appearance_panel.dart:67-71` (620) |
| `TabBar` sin `TabController` ni `DefaultTabController` → `FlutterError` en debug en la rama móvil, y el resaltado no sigue a `_section` | `settings_screen.dart:90-101`; assert en `flutter/packages/flutter/lib/src/material/tabs.dart:1655` |
| Nada consulta `platformModeProvider` en Ajustes | sin coincidencias en `lib/features/settings` |
| `Switch`s fuera de `AppHover` (sin sonido de hover ni autoscroll al foco) | `settings_screen.dart:255-362`; `AppHover.ensureVisibleOnFocus` existe en `app_hover.dart:241,474` |
| `Row` de `ChoiceChip` puede desbordar con traducciones largas | `settings_screen.dart:388-400` |

Consecuencias medidas con los tamaños del simulador (`debug_device.dart:6-9`:

| Perfil | Efecto |
|---|---|
| Móvil 390×844 | 7 pestañas icono+texto (~110 px cada una) en 390 px; contenido útil 310 px; assert del `TabBar` |
| Tablet 768×1024 | Menú 240 (31 % del ancho) + contenido 527; alto sin aprovechar |
| Escritorio 1920×1080 | Menú 240 (12 %) + columna de 560 centrada: ~1.100 px vacíos; ~1.000 px de scroll |
| TV 1280×720 | Layout de escritorio; texto 12–15 px a 3 m; sin autofocus al entrar; sin overscan |

### Propuesta

#### Eje 1 — Tokens de densidad (`SettingsMetrics`)

Dos ejes independientes:

- **Ancho** → decide navegación y nº de columnas.
- **`PlatformMode.tv`** → decide densidad (fuente, alto de fila, overscan)
  sea cual sea el ancho. Sin esto, una TV 1080p se trata como escritorio.

| Token | Móvil <600 | Tablet 600–1023 | Escritorio ≥1024 (2 col desde 1600) | TV |
|---|---|---|---|---|
| Navegación | chips scrollables arriba, 48 px | rail 88 (iconos) | menú lateral 264 | menú lateral 320 |
| Ancho de contenido | ancho − 32 | 640 | 720 / 2×520 | 960 |
| Padding de página | 16 / 16 | 24 / 24 | 32 / 32 | 5 % H (48–96), 32–56 V |
| Gap entre tarjetas | 12 | 16 | 16 | 20 |
| Padding de tarjeta | 14 | 16 | 18 | 24 |
| Título de página | 22 | 24 | 26 | 30 (720p) / 34 (1080p) |
| Título de fila / subtítulo | 15 / 12 | 16 / 13 | 16 / 13 | 19 / 16 |
| Alto mínimo de fila | 64 | 68 | 64 | 76 |
| Radio | 12 | 14 | 16 | 18 |
| Control trailing | 56 | 64 | 64 | 88 |

Escala TV por alto de pantalla (`<1000` → 1.25, `≥1000` → 1.35), en la línea de
`uiScaleFor` (`ui_constants.dart:80`).

#### Eje 2 — Scaffold y fila compartidos

- `SettingsScaffold`: scroll + safe area inferior + `ConstrainedBox` desde
  tokens + título + hueco. Sustituye las 4 copias (560/560/560/620).
- `SettingsGroup` + `SettingsRow`: una tarjeta por grupo semántico con filas
  separadas por `Divider(1px)` y control alineado a un borde derecho fijo
  (switch 88, dropdown 140). Pasa de 6 tarjetas con 6 bordes y 24 px entre
  ellas (~1.000 px de scroll, ~2,5 pantallas en TV) a 2 grupos con 6 filas de
  64–72 px (~560 px, ~1,3 pantallas): **≈ −45 % de scroll**.
- Cada fila interactiva envuelve `AppHover` (regla del proyecto): escala 1.02,
  contorno 2 px, sonido de hover y `ensureVisibleOnFocus: true`.
- Preferencias se agrupa en “Idioma y tema” y “Reproducción y contenido”;
  a ≥1600 los dos grupos van lado a lado. Cabeceras como claves ARB nuevas.

#### Eje 3 — Navegación sin duplicar código

- Móvil: `AppTabBar` (`app_tab_bar.dart:19`, index-based y con `AppHover`) con
  un parámetro `scrollable` nuevo, en vez del `TabBar` roto.
- Tablet: rail de iconos; etiqueta completa desde 840.
- Escritorio: menú lateral 264 con `ScaleButton` (el actual).
- TV: menú 320 con filas de 64 y `autofocus` en la sección activa; el
  contenido en su propio `FocusTraversalGroup` para que ↑/↓ no salten al menú
  lateral hasta recorrer el contenido.

### Archivos previstos

Nuevos: `widgets/settings_metrics.dart`, `widgets/settings_scaffold.dart`,
`widgets/settings_row.dart`, `widgets/preferences_panel.dart`,
`widgets/home_panel.dart` (extrae `_HomePanel`, hoy ~390 líneas dentro de la
pantalla).

Tocados: `settings_screen.dart`, `appearance_panel.dart`, `games_panel.dart`,
`sounds_panel.dart`, `core/widgets/app_tab_bar.dart` (+`scrollable`),
`core/constants/ui_constants.dart`, ARB `es/en`.

### Fases

1. Doc FTD + tokens + `SettingsScaffold` (cambio casi neutro: solo
   anchos/paddings).
2. `SettingsRow`/`SettingsGroup` + migración de Preferencias, Cuenta y Acerca de.
3. Navegación adaptativa (arregla el assert del `TabBar`, autofocus TV).
4. Apariencia/Juegos/Sonidos al mismo scaffold + dos columnas ≥1600.
5. Pulido TV: overscan, `AppHover` en todas las filas, `viewInsets` en los
   formularios de “Hogar”.
6. `flutter gen-l10n`, `flutter analyze`, matriz de perfiles (390×844,
   768×1024, 1280×720, 1920×1080) y `textScale` 1.3.

### Riesgos

- Formularios de PIN/hogar en TV con fuente ×1.35 y sin IME.
- `Row` de chips del tema debe pasar a `Wrap`.
- Mini-player y barras laterales no deben recortar el último grupo (padding
  inferior de safe area).

### Decisiones abiertas

Resueltas el 2026-11-03 para el rediseño de Preferencias:

1. **Modelo de navegación en móvil/tablet**: una sola página con scroll
   por sección (propuesta original). Móvil: chips scrollables arriba;
   tablet: rail de iconos; sin hub intermedio.
2. **Patrón de filas**: agrupar los ajustes en filas con divisor
   (`SettingsGroup` + `SettingsRow`): menos bordes, ~45 % menos scroll.
3. **Deuda documental detectada**: `avatar-menu-ajustes.md:10-11` documenta
   `initialSection` y el parseo de `?section=` que no existen en el
   `SettingsScreen` actual. En esta fase **no** se recupera el deep-link;
   se deja constancia aquí y se corrige el doc dependiente aparte.

## Checklist

- [x] Decidir las tres cuestiones de "Decisiones abiertas"
- [x] Fase 1 — `settings_metrics.dart` + `settings_scaffold.dart`
- [x] Fase 2 — `settings_row.dart` + migrar Preferencias (Cuenta/Acerca de pendientes)
- [x] Fase 3 — navegación adaptativa (móvil desplegable / tablet rail / escritorio-TV menú; `TabBar` roto eliminado)
- [ ] Fase 4 — Apariencia/Juegos/Sonidos al scaffold + 2 columnas ≥1600 (solo Preferencias usa 2 columnas)
- [x] Fase 5 — pulido TV en Preferencias (overscan vía tokens, `AppHover` en filas/menú/chips, `FocusTraversalGroup`); formularios “Hogar” pendientes
- [x] Fase 6 — ARB `es/en` (`prefsGroupLanguageTheme`, `prefsGroupPlaybackContent`), `flutter gen-l10n`, `flutter analyze` limpio; matriz visual en simulador pendiente

## Evidence

Análisis de solo lectura, sin cambios de código:

- `settings_screen.dart`: breakpoint 700, menú 240, `maxWidth` 560,
  `TabBar` sin controlador, `Switch` sin `AppHover`.
- `sounds_panel.dart`, `games_panel.dart` (560) y `appearance_panel.dart`
  (620): scaffolds duplicados.
- `app_tab_bar.dart`: componente index-based reutilizable con `AppHover`.
- `app_hover.dart`: `ensureVisibleOnFocus` ya implementado (autoscroll al foco).
- `ui_constants.dart:80`: `uiScaleFor` como referencia de escalado por resolución.
- `debug_device.dart:6-9`: perfiles de prueba 390×844 / 768×1024 / 1280×720 /
  1920×1080.

Implementación Preferencias (2026-11-03, prueba observada):

- Nuevos: `widgets/settings_metrics.dart` (tokens por ancho + `PlatformMode.tv`),
  `widgets/settings_scaffold.dart` (scaffold único), `widgets/settings_group.dart`
  (`SettingsGroup` + `SettingsRow` con `AppHover` universal),
  `widgets/preferences_panel.dart` (grupos “Idioma y tema” y
  “Reproducción y contenido”; `Wrap` en chips de tema; 2 columnas ≥1600).
- Tocados: `settings_screen.dart` (desplegable de sección en móvil en vez
  del `TabBar` sin controlador —los chips horizontales no se veían bien ni
  hacían scroll—; rail 88 en tablet con etiquetas ≥840; menú
  264/320 con `autofocus` en TV; `FocusTraversalGroup` en el contenido;
  `_PreferencesPanel` antiguo eliminado), ARB `es/en`
  (`prefsGroupLanguageTheme`, `prefsGroupPlaybackContent`) + `flutter gen-l10n`.
- `flutter analyze` → `No issues found!` (full, 4.5s).
- Sin tocar: paneles Hogar/Cuenta/Acerca de/Apariencia/Juegos/Sonidos
  (siguen con `_SettingsPanel`), `PrimeCardBadge`, lógica de controladores.

## Next

Validar visualmente en el simulador (`debugDevice`: 390×844, 768×1024,
1280×720 con D-pad, 1920×1080) y `textScale` 1.3; después migrar
Cuenta/Acerca de y Apariencia/Juegos/Sonidos al scaffold compartido.
