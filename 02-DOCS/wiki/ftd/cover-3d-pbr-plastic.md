# Intent
Dar acabado de plástico brillante a la carátula 3D usando materiales PBR (`PhysicallyBasedMaterial`) en todas las caras, sustituyendo el `UnlitMaterial` plano. La iluminación se refinará después.

# Scope
- In: `lib/features/games/presentation/widgets/game_box3d_scene_viewer.dart` — caras con textura, lomo y cantos/sólidos pasan a `PhysicallyBasedMaterial` con `metallicFactor = 0` y `roughnessFactor` bajo (plástico brillante).
- Out: geometría, órbita/rotación 360, toggle 2D/3D, fallback 2D, luz direccional (se afinará en otra iteración), ARB, tests.

# Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] `_solid` y las caras con textura usan `PhysicallyBasedMaterial` (metallic 0, roughness plástico)
- [x] `flutter analyze lib` sin issues

# Evidence (verificacion)
- `PhysicallyBasedMaterial` y `StandardFragment` ya vienen en el shader bundle base del paquete (verificado en `flutter_scene-0.20.0`); la IBL por defecto es `EnvironmentMap.studio()` memoizada, así que no hay setup extra.
- `_solid` → PBR dieléctrico (`metallicFactor = 0`, `roughnessFactor = 0.35`) con `baseColorFactor` lineal (ya venía de `_linearFromArgb`).
- Caras/lomo con textura → `_plasticTexture(tex)` (mismo metallic/roughness, `vertexColorWeight = 0`).
- El shader hace `SRGBToLinear(base_color_texture)`, así que los colores de la carátula se mantienen correctos (sin el bug de gris del antiguo three_js).
- `flutter analyze lib` → "No issues found! (ran in 11.9s)".

# Next
- Afinar luz (direccional/entorno) y ajustar `roughnessFactor`/`environmentIntensity` a gusto del usuario.
