# Intent
Permitir al usuario elegir el tipo de material de la carátula 3D desde Ajustes → Apariencia, con un desplegable de enum y persistencia, y ofrecer varios materiales para ir viendo.

# Scope
- In: `lib/core/settings/cover3d_material.dart` (enum `Cover3dMaterial` con parámetros metallic/roughness/unlit + provider persistido con SharedPreferences); `game_box3d_scene_viewer.dart` (materiales según el enum, incluido `UnlitMaterial` para el modo plano); `appearance_panel.dart` (dropdown); `l10n/app_en.arb` + `app_es.arb` (etiquetas) + regeneración.
- Out: iluminación direccional (se afinará), geometría, órbita, toggle 2D/3D, tests.

# Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] Enum `Cover3dMaterial` + provider persistido
- [x] Visor aplica el material seleccionado (incluido unlit) y reacciona al cambio
- [x] Dropdown en Apariencia
- [x] ARB en/es autogenerado
- [x] `flutter analyze lib` sin issues

# Evidence (verificacion)
- `lib/core/settings/cover3d_material.dart`: enum con `metallic`/`roughness`/`isUnlit` y `Cover3dMaterialController` (Notifier) persistido en `SharedPreferences` (`app.cover3d_material`, por nombre).
- Materiales ofrecidos: `unlit` (Plano), `matte` (Mate), `softTouch`, `glossy` (default), `brushedMetal`, `chrome`.
- Visor: `_solid`/`_texturedMat` eligen `UnlitMaterial` o `PhysicallyBasedMaterial` según el enum; `_builtMaterial` detecta el cambio desde Ajustes y reconstruye la escena (post-frame).
- `appearance_panel.dart`: `_OptionRow` + `DropdownButtonFormField<Cover3dMaterial>` bajo "Material de la carátula 3D" (Apariencia).
- ARB: `cover3dMaterial`, `cover3dMaterialHint`, `coverMaterial{Unlit,Matte,SoftTouch,Glossy,BrushedMetal,Chrome}` en `app_en.arb`/`app_es.arb`; regenerado con `flutter gen-l10n`.
- `flutter analyze lib` → "No issues found! (ran in 6.0s)".

# Next
- Afinar la luz (direccional/entorno) y ajustar los valores de roughness/metallic de cada preset a gusto del usuario.
- (Nota: el renombrado del fichero se hizo con `Set-Content`; verificado que el texto UTF-8 quedó intacto.)
