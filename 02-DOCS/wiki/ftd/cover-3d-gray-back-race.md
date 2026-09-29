# Intent
Evitar que la caja 3D pinte la trasera en gris por carrera/fallo al traer las texturas de la API de ROMM. El gris es `backFallback` (`0x808080`) cuando la textura trasera llega nula a `_setup`.

# Scope
- In: `game_box3d_viewer.dart` — la detección de placeholder negro solo para la frontal (las traseras/lomos oscuros son arte válido y no deben descartarse; solo se normalizan a PNG para ANGLE), más guardia `identical` para que un setup viejo no toque escena nueva; `romm_repository.dart` — `downloadAssetBytes` con 1 reintento (400 ms) ante fallo/timeout del NAS.
- Out: cambiar el fallback gris por otro arte, nuevos ARB, tests.

# Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] `rejectBlank` solo en frontal; trasera/lomo solo normalizan
- [x] Reintento en `downloadAssetBytes`
- [x] Guardia `identical` en `_setup`
- [x] `flutter analyze` sin issues

# Evidence (verificacion)
- `flutter analyze` (game_box3d_viewer + romm_repository) → "No issues found!".

# Evidence
- Gris actual: `game_box3d_viewer.dart` usa `backFallback` gris cuando `results[1].texture == null`.
- Sospechoso 1: `_normalizedCoverBytes` descarta por luminancia < 8 también en trasera/lomo (introducido en el fix de frontal negra); una trasera legítima oscura acaba en gris.
- Sospechoso 2: `downloadAssetBytes` (`romm_repository.dart`) sin reintento: un fallo puntual del NAS deja la cara en gris.
- `_setup` guarda `t = _three` pero tras el `await` solo comprueba nulidad, no identidad: un setup viejo puede pintar `setState ready` sobre escena nueva.

# Next
Abrir juegos con trasera oscura y con NAS lento; comprobar que la trasera ya no cae a gris y que no hay caja mezclada al cambiar rápido de juego.
