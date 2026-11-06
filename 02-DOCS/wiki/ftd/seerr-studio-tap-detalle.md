# Intent
En Estudios (Seerr), el tap en una peli disponible en biblioteca reproduce directo (`pushPlayForDetail`). Debe abrir su ficha como hacen las series.

# Scope
- `lib/features/seerr/presentation/seerr_studio_screen.dart`: tap de item disponible → `pushDetailForType` siempre; `hoverActionLabel` → `details` (antes `watchNow` para disponibles).
- Sin cambios de strings ARB (se reutiliza `details`). Sin tocar reproductor ni `play_routing.dart`.
- Verificación: `dart analyze` del fichero.

# Checklist
- [x] Causa: rama `real.type == BaseItemKind.movie → pushPlayForDetail` (línea ~53). Preexistente, no de la regresión de layouts.
- [x] Tap disponible → `pushDetailForType(context, real)` para pelis y series.
- [x] `hoverActionLabel: l10n.details` siempre (el tap ya no reproduce). Import `jellyfin_dart` sobrante eliminado.
- [x] `dart analyze` sin errores.

# Evidence
- Antes: tap en peli disponible de Estudios → `/player/:id` directo.
- Después: `dart analyze` de ambos ficheros → `No issues found!`. Tap → `/home/details/:id` (ficha con layout del skin y botón Ver dentro).

# Next
- Siguiente paso: aplicar y analizar. Si se quiere "Ver ahora" directo en algún grid, hacerlo vía botón explícito en la ficha, no vía tap.
