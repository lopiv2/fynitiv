# Intent
Que el ajuste "Desplazamiento del título al pasar el ratón" de Apariencia sobreviva al reinicio (y al cambio de preset). Causa: vive solo dentro del JSON del skin (`jellyfin.skin`) y `SkinController.build()` prioriza el preset guardado (`jellyfin.skin_preset`); si la carga cae al preset o el JSON no trae la clave, el valor se pierde.

# Scope
- In: `lib/core/skin/skin_controller.dart` — nueva clave `fynitiv.title_marquee` en SharedPreferences; helper `_withMarquee` que la siembra desde el skin resuelto y la impone con `copyWith`; aplicado en `build` (todas las salidas), `apply` (sincroniza la clave con el draft), `applyPresetSkin`/`reset` (el cambio de preset ya no resetea el ajuste). Sin tocar el panel, las tarjetas, `PrimeCardBadge`, hover ni ARB (mismas cadenas).
- Out: extraer el ajuste a otro provider, cambios visuales, tests.

# Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] Clave `fynitiv.title_marquee` + `_withMarquee` en `skin_controller.dart`
- [x] `build`/`apply`/`applyPresetSkin` la aplican/sincronizan
- [x] `flutter analyze` sin issues

# Evidence (verificacion)
- `flutter analyze` (skin_controller + appearance_panel) → "No issues found!" (en el camino se cazaron 3 `unawaited_return_in_try_block` por los nuevos `return _withMarquee` dentro del `try` y se corrigieron con `await`).

# Evidence
- Guarda: `appearance_panel.dart:45` (`_applyDraft` → `apply`) y `skin.dart:724` (`toJson` con la clave) — el guardado existe.
- Carga: `skin_controller.dart:24` (si hay `jellyfin.skin_preset` se devuelve el preset en código, ignorando el custom) y `skin.dart:644` (`?? false` si falta la clave) — puntos donde el valor se pierde al reiniciar.
- Solo `jellyfinDefault` define `titleMarqueeOnHover: true` (`skin_presets.dart:28`); el resto de presets van a `false` por defecto.

# Next
Activar el ajuste, reiniciar la app y comprobar que sigue activo; cambiar de preset y comprobar que se conserva.
