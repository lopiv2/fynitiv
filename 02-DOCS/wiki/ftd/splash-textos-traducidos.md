# Textos de la splash traducidos

## Intent
Que el texto de las presentaciones de splash (el tagline «Watch. Read. Play. Anything») se
muestre en el idioma elegido en Preferencias. Los textos de debug **no se traducen** (norma del
proyecto).

## Scope
- In:
  - Cuatro cadenas ARB para las palabras del tagline (`splashWatch`, `splashRead`, `splashPlay`,
    `splashAnything`) en inglés y español.
  - `splash_screen.dart` lee `AppLocalizations` para el tagline de la presentación.
- Out:
  - Textos de debug (badge «Repetir presentación» / «Resetear configuración», barra de
    dispositivo): se mantienen fijos, sin traducir.
  - Traducir el nombre de marca `FYNITIV` (no se traduce).
  - El texto del selector de idioma (ya está localizado).
  - Cambiar tiempos ni animación del tagline.
  - Build o tests (según AGENTS.md).

## Checklist
- [x] FTD creado antes del primer cambio.
- [x] Cadenas ARB EN+ES del tagline y `flutter gen-l10n`.
- [x] `splash_screen.dart` usa las cadenas localizadas del tagline; `flutter analyze`.
- [x] Textos de debug sin traducir.
- [x] `flutter analyze` sin problemas (`No issues found!`).

## Evidence
- `splash_screen.dart` fija las palabras del tagline (`'Watch.'`, `'Read.'`, `'Play.'`,
  `'Anything'`) y los textos «Repetir presentación» / «Resetear configuración» en constantes.
- Existe `splashTagline` en ARB pero la splash no lo usa (el tagline se pinta palabra a palabra
  con color y momento de revelado propios), así que hacen falta cadenas por palabra.
- La splash es `ConsumerState`, por debajo de `Localizations`: `AppLocalizations.of(context)`
  provoca rebuild al cambiar el idioma en Preferencias.
- Repositorio en rama `main`.
- ARB nuevas (EN/ES): `splashWatch` (Watch./Ver.), `splashRead` (Read./Leer.),
  `splashPlay` (Play./Jugar.), `splashAnything` (Anything/Todo.). Getters generados en
  `app_localizations*.dart` con `flutter gen-l10n`.
- `_buildTaglineWords` construye la lista de palabras desde `AppLocalizations.of(context)`; al
  cambiar el idioma en Preferencias el `SplashScreen` se reconstruye por la dependencia de
  `Localizations`.
- El badge de desarrollo y la barra de dispositivo mantienen sus textos fijos (sin ARB), según la
  norma de no traducir debug.
- `flutter analyze` → `No issues found! (ran in 10.9s)`.

## Next
Revisar en español e inglés que el tagline no desborda en móvil/tablet (el `FittedBox` lo escala)
y que el cambio de idioma en Preferencias se refleja al volver a la splash.
