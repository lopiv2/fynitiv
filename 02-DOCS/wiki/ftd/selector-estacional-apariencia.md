# Selector estacional en Apariencia

## Intent
Permitir al usuario elegir la temática estacional (Auto, Sin tema o una estación concreta) desde Apariencia, sin esperar a la fecha del calendario, y que esa selección sea la misma que usa la barra de debug y quede persistida para cuando la barra se elimine.

## Scope
- In:
  - Selector de temática en Apariencia con las mismas opciones que la barra de debug.
  - Estado único y persistente compartido por Apariencia y debug.
  - Lectura de la preferencia al arrancar para que splash/skin no parpadeen a `auto`.
  - Textos ARB en español e inglés y traducciones generadas.
- Out:
  - Cambiar el calendario de estaciones ni añadir estaciones nuevas.
  - Eliminar todavía la barra de debug.

## Checklist
- [x] Controlador persistente con `SharedPreferences` y valor inicial inyectado desde `main`; comprobar lectura/escritura y `flutter analyze`.
- [x] Barra de debug usando el mismo provider (sincronía bidireccional); comprobar referencias y `flutter analyze`.
- [x] Selector integrado en Apariencia reutilizando las cadenas de estación; comprobar render y `flutter analyze`.
- [x] La selección manual respeta los interruptores de "Sugerencias estacionales" y "Tema estacional" de Preferencias; comprobar providers y `flutter analyze`.
- [x] Cadenas ARB generadas; ejecutar `flutter gen-l10n` y comprobar getters.
- [x] `flutter analyze` sin problemas; demostrar salida.

## Evidence
- `lib/core/seasonal/active_seasonal_event.dart`: `SeasonalEventOverrideController` pasa a persistir en `jellyfin.seasonal_event_override` (`SharedPreferences.setString`). Se añade `seasonalEventOverrideFromName` y `seasonalEventOverrideInitialProvider`, que `main` sobrescribe con el valor leído antes del primer frame. Eliminado `seasonalEventOverrideActiveProvider`.
- `lib/main.dart`: lee la clave junto a `allow_bad_certificates` y monta `ProviderScope(overrides: [seasonalEventOverrideInitialProvider...])`.
- `lib/core/debug/device_simulator_host.dart`: sin cambios; ya usa `seasonalEventOverrideProvider`, así que sus chips y los de Apariencia comparten estado y persisten.
- `lib/features/settings/presentation/widgets/appearance_panel.dart`: sección "Contenido estacional" con `ChoiceChip` para Auto, Sin tema y las cuatro estaciones (`seasonalEventTitle`), más hint.
- `lib/core/skin/effective_skin_provider.dart` y `seasonal_suggestions_row.dart`: la estación manual sustituye a la del calendario, pero se respetan los interruptores "Tema estacional" y "Sugerencias estacionales" (antes el override de debug los anulaba).
- ARB: `seasonalContent` y `seasonalContentHint` en `app_en.arb`/`app_es.arb`; `flutter gen-l10n` actualizó `app_localizations*.dart`.
- `flutter analyze` → `No issues found!`.

## Next
Probar en la app: elegir cada estación en Apariencia y comprobar que Inicio, skin y splash cambian al instante; reiniciar y verificar que se conserva; alternar desde la barra de debug y comprobar que los chips de Apariencia reflejan el mismo valor.
