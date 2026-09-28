# Intent
Mostrar el loader universal (`AppLoader`) en la zona de “Continuar jugando” de Juego online mientras carga (`rommContinuePlayingProvider`), en vez del hueco vacío actual.

# Scope
- Solo `lib/features/games/presentation/games_screen.dart`: rama `loading` del `continueAsync.when` → caja de alto 280 (igual que la fila) con `AppLoader` centrado.
- No se tocan ARB, providers, ni el resto de la pantalla (auth/config/plataformas ya tienen su `AppLoader`).
- Sin `flutter build`; verificación con `flutter analyze`.

# Checklist
- [x] Localizar: `games_screen.dart:111` `loading: () => const SizedBox.shrink()`
- [x] Sustituir por `SizedBox(height: 280, child: Center(child: AppLoader()))`
- [x] `flutter analyze` sin errores nuevos

# Evidence
- `flutter analyze --no-pub` (28/09/2026): `No issues found!`.

# Next
- Si se quiere, esqueleto con título “Continuar jugando” + loader en vez de solo spinner.
