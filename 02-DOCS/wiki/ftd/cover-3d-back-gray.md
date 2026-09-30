# Intent
Cuando el juego no tiene carátula trasera, la cara trasera de la caja 3D debe verse gris neutro, no con el tinte verdoso que aparece ahora con el material PBR.

# Scope
- In: `lib/features/games/presentation/widgets/game_box3d_scene_viewer.dart` — el material de respaldo de la cara trasera pasa a gris neutro sin reflejos (mate, roughness 1.0, metallic 0); en modo plano, gris plano (`UnlitMaterial`).
- Out: resto de caras, geometría, iluminación global, ajustes, ARB, tests.

# Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] Fallback de trasera sin arte = gris neutro mate
- [x] `flutter analyze lib` sin issues

# Evidence (verificacion)
- Iteración 1: el respaldo gris usaba PBR brillante y sus reflejos teñían la cara. Se pasó a gris mate PBR. El usuario confirma que **sigue verde** → el gris mate neutro bajo IBL neutra no puede virar a verde, así que el verde no venía del color sólido.
- Iteración 2 (causa real): ROMM devuelve una **imagen placeholder** (verde) para la trasera cuando no existe, y el probe de artwork la acepta. Se añade `_looksLikePlaceholder(ui.Image)` (baja desviación tonal o dominancia verde con poca variación) y se descarta la textura en trasera/lomo (`rejectPlaceholder: true`).
- Además el respaldo de trasera pasa a `UnlitMaterial` gris plano (`_backFallbackMat()`), garantizando gris exacto sin tinte de entorno.
- Logs de diagnóstico `[Scene3D]` retirados tras confirmar el fix (petición del usuario).
- `flutter analyze lib` → "No issues found! (ran in 12.6s)".

# Next
- Cerrado.
- Revisar en runtime si el tono gris es el deseado; si no, ajustar valor/roughness.
