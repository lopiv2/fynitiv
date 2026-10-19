# Selector de tema estacional en la barra de debug

## Intent
Poder forzar desde la barra de debug (la que ya elige plataforma/dispositivo) cualquiera
de los temas estacionales definidos, sin depender de la fecha del sistema, para probar
skins y presentaciones. La elección debe anular los toggles de Ajustes mientras haya un
override activo.

## Scope
- In:
  - Un override (Auto / Sin tema / Halloween / Navidad / San Valentín / Pascua) en la barra
    de debug de `device_simulator_host.dart`, reutilizando el chip ya existente.
  - Fuente única de verdad del evento estacional activo, consumida por el teñido del skin y
    por la fila de sugerencias.
  - El override anula los toggles de Ajustes (tema estacional y sugerencias) mientras esté
    activo; `Auto` vuelve al comportamiento normal.
  - Cadenas ARB en inglés y español para las etiquetas nuevas.
- Out:
  - Persistir la elección (es debug; arranca siempre en `Auto`).
  - Cambiar paletas o el algoritmo de detección por calendario.
  - Ejecutar build o tests (según AGENTS.md).

## Checklist
- [x] FTD creado antes del primer cambio.
- [x] `active_seasonal_event.dart` con override + provider del evento activo; `flutter analyze`.
- [x] `effective_skin_provider.dart` y `seasonal_suggestions_row.dart` consumen el provider; `flutter analyze`.
- [x] Chips de estación en la barra de debug reutilizando `_DebugChip`; `flutter analyze`.
- [x] ARB EN+ES + `flutter gen-l10n`.
- [x] `flutter analyze` sin problemas (`No issues found!`).

## Evidence
- `_DebugDeviceBar` (en `lib/core/debug/device_simulator_host.dart`) es la barra superior de
  debug con chips de dispositivo; usa `Container`/`GestureDetector` (sin ancestro `Material`
  de Flutter), por eso los chips se reutilizan en vez de un `DropdownButton`.
- El evento estacional se calcaba con `seasonalEventForDate(DateTime.now())` en
  `effective_skin_provider.dart` (tiñe el skin) y en `seasonal_suggestions_row.dart`.
- Cadenas existentes: `seasonalHalloween`, `seasonalChristmas`, `seasonalValentinesDay`,
  `seasonalEaster` + helper `seasonalEventTitle(l10n, event)`.
- Repositorio en rama `main`.
- `lib/core/seasonal/active_seasonal_event.dart` (nuevo): `SeasonalEventOverride`
  (`auto`/`none`/4 estaciones), `seasonalEventOfOverride`, `seasonalEventOverrideProvider`
  (`Notifier`, arranca en `auto`), `seasonalEventOverrideActiveProvider` (true salvo `auto`)
  y `activeSeasonalEventProvider` (override o calendario).
- `effective_skin_provider.dart` y `seasonal_suggestions_row.dart` leen
  `activeSeasonalEventProvider`; mientras `seasonalEventOverrideActiveProvider` es true,
  ignoran los ajustes `seasonalThemeEnabledProvider` / `seasonalSuggestionsEnabledProvider`.
- La barra de debug añade un grupo "Estación:" tras los chips de dispositivo, con
  `_DebugChip` reutilizado; `DropdownButton` descartado por falta de ancestro `Material`.
- ARB: `seasonalDebugLabel`, `seasonalDebugAuto`, `seasonalDebugNone` (EN+ES) generados con
  `flutter gen-l10n` (getters presentes en `app_localizations*.dart`).
- `flutter analyze` → `No issues found! (ran in 24.0s)`.

## Next
Validar visualmente en la app que al elegir cada estación cambian skin y fila al instante y
que `Auto` restaura la fecha real. Si al probar se ve poco el matiz, subir la intensidad en
Ajustes o considerar aplicar intensidad 1.0 en modo debug.
