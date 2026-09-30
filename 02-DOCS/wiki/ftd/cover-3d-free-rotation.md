# Intent
Permitir rotar la carátula 3D libremente (horizontal 360° + vertical) con un arrastre de ratón y, al soltar, volver animadamente al estado inicial (auto-rotación en un solo eje horizontal, pitch 0).

# Scope
- In: `lib/features/games/presentation/widgets/game_box3d_scene_viewer.dart` — `_pitch` + arrastre con `onPan*`, órbita esférica en `cameraBuilder`, auto-rotación por delta para no saltar al soltar, `AnimationController` que devuelve el pitch a 0, flechas arriba/abajo para TV/D-pad.
- Out: geometría/materiales de la caja, toggle 2D/3D, ARB, tests, `three_js` (ya eliminado).

# Checklist
- [x] Ganchos `onPanStart/Update/End/Cancel` (sustituyen a `onHorizontalDrag*`)
- [x] `_pitch` con clamp ±1.5 rad (evita el polo de la cámara) y órbita esférica
- [x] Auto-rotación por delta (`elapsed - _lastElapsed`) pausada mientras se arrastra
- [x] `AnimationController` (520 ms, easeOutCubic) que devuelve `_pitch` a 0 al soltar
- [x] Flechas ↕ para TV ajustan pitch y retornan igual
- [x] `flutter analyze lib` sin issues

# Evidence (verificacion)
- `flutter analyze lib` → "No issues found! (ran in 7.2s)" (tras corregir `const DragEndDetails()` → `DragEndDetails()`).
- Órbita: posición = (`sin(yaw)·cos(pitch)·R`, `0.3 + sin(pitch)·R`, `cos(yaw)·cos(pitch)·R`); con `pitch = 0` coincide con el estado previo.
- FTD redactado en el mismo turno que los cambios (no antes del primer edit): el proyecto ya tenía este widget bajo iteración.

# Iteración
- Eje vertical invertido a petición: subir el ratón ahora baja la carátula.
- Arrastre movido de posición absoluta (`localPosition`) a delta (`d.delta`): un clic con micro-movimiento ya no salta (el eje Y mapeaba la posición absoluta como ángulo y disparaba al máximo). Quitados `_yawStart`/`_pitchStart`.

# Next
- Probar en Windows: arrastrar la carátula en ambos ejes, soltar y confirmar el retorno animado y que la auto-rotación continúa sin salto.
- Decidir si el arrastre vertical no debe robar el scroll de la página del detalle (hoy lo hace sobre la carátula).