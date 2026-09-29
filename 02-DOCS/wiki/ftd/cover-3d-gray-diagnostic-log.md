# Intent
Añadir log temporal de diagnóstico que explique por qué una carátula 3D cae a gris: qué URL llega de la API, cuántos bytes descargan, si el decode falla y si se descarta por negra/vacía.

# Scope
- In: `game_box3d_viewer.dart` (`_normalizedCoverBytes` + `_loadFace` con etiqueta `front/back/spine` y `debugPrint('[Box3D] ...')` en cada descarte). `downloadAssetBytes` ya loguea su fallo con error.
- Out: cambios de comportamiento, ARB, tests.

# Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] Logs `[Box3D]` en normalize + caras
- [x] `flutter analyze` sin issues

# Evidence (verificacion)
- `flutter analyze` (game_box3d_viewer) → "No issues found!".
- No se tocaron los bloques FIX manuales del usuario (`_loadFace` headers, flipY, needsUpdate).

# Evidence
- Gris = `results[1].texture == null` en `_setup` sin rastro del motivo.
- Tras el cambio, abrir un detalle problemático debe mostrar en consola: URL pedida, bytes descargados y motivo de descarte (vacío/decode/negra) por cara.

# Next
Reproducir un gris, leer el log y decidir fix (reintento extra, fallback a frontal, o nada si falta arte en ROMM). Retirar o silenciar los logs cuando se cierre el diagnóstico.
