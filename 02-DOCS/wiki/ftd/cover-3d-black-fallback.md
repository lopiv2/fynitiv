# Intent
Evitar la caratula 3D en negro: a veces la imagen frontal que sirve la API de ROMM llega en un formato que ANGLE/D3D11 no sube a textura (o es un placeholder negro) y la caja sale negra, mientras el 2D de Flutter si la muestra. Normalizar la frontal via codec de Flutter a PNG antes de crear la textura y tratar la imagen negra como ausente (fallback 2D validado / letra inicial en vez de caja negra).

# Scope
- In: `lib/features/games/presentation/widgets/game_box3d_viewer.dart` — helper `_normalizedFrontBytes` (decodifica con `ui.instantiateImageCodec`, descarta si falla o si la luminancia media < 8/255 o todo transparente, re-codifica a PNG), `_loadFace` lo usa para la textura three.js, y `_build2D` pasa a mostrar `Image.memory` de esos bytes validados con `_CoverFallback` si son nulos (misma URL, sin depender de `Image.network`).
- Out: cambios en resolucion de URLs (`romm_repository`), nuevos ARB (se reutiliza `gameBoxNoData`), cambios visuales del modelo 3D, tests.

# Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] Helper de normalizacion + deteccion de negro en `game_box3d_viewer.dart`
- [x] `_loadFace` usa bytes normalizados
- [x] `_build2D` validado (fallback en vez de negro)
- [x] `flutter analyze` sin issues

# Evidence (verificacion)
- `flutter analyze` (4 ficheros) → "No issues found!" (en el camino se cazaron `unnecessary_import` de `dart:typed_data` y `unawaited_return_in_try_block` en el nuevo widget y se corrigieron).

# Evidence
- Negro actual: `_loadFace` en `game_box3d_viewer.dart:292` pasa los bytes crudos a `three.TextureLoader.fromBytes`; si ANGLE no sube ese JPEG el material `MeshBasicMaterial` muestrea negro sin error (el null solo cubre descarga fallida).
- NPOT ya mitigado en `game_box3d_viewer.dart:308` (ClampToEdge + Linear + sin mipmaps); lo que queda es formato/contenido.
- Fallback existente: frontal null en `_setup` (`game_box3d_viewer.dart:432`) cae a 2D con toast `gameBoxNoData`; `_CoverFallback` (`game_box3d_viewer.dart:706`) muestra la inicial.

# Next
Abrir detalles con caratulas problematicas y comprobar que ya no sale la caja negra (2D validado o letra inicial); si alguna sigue negra, mirar el log `asset bytes failed` conservado.
