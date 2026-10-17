# Intent
En la pantalla de Seerr sin configurar (`_SetupPanel`), el botón de QR ("Conexión rápida") no deja ver su texto: `FilledButton` toma fondo de `colorScheme.primary` (sobrescrito con `skin.primary`) y texto de `colorScheme.onPrimary` (generado por `ColorScheme.fromSeed`). En skins con `primary` oscuro (p. ej. Disney+ `0xFF0B1030`) queda texto oscuro sobre fondo oscuro → ilegible. El `OutlinedButton` "Usar API key" de la misma pantalla sufre la misma causa (foreground = `colorScheme.primary`).

# Scope
- Solo `lib/features/seerr/presentation/seerr_screen.dart`, `_SetupPanelState.build`.
- Botón QR: fondo `skin.accent` + texto/icono blancos explícitos (mismo patrón ya usado en `radio_filters.dart`).
- Botón "Usar API key": foreground `Colors.white70` y borde `Colors.white24` explícitos.
- Sin cambios de ARB (cadenas ya existentes). Sin tocar `PrimeCardBadge`.

# Checklist
- [x] FTD creado antes del primer cambio
- [x] Estilo explícito en el botón QR (`skin.accent` + blanco)
- [x] Estilo explícito en el botón "Usar API key"
- [x] `flutter analyze` limpio

# Evidence
- `flutter analyze lib/features/seerr/presentation/seerr_screen.dart` (17/10/2026): `No issues found!`.
- Sin `flutter build` como verificación (norma del proyecto); sin tests (no pedidos).

# Next
- Si se quiere, extraer un `SkinAccentButton` genérico y reutilizarlo también en `radio_filters.dart`.
