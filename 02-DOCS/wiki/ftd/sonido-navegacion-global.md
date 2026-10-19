# Sonido de navegación global

## Intent
Que el tono elegido en Ajustes > Sonidos suene al mover el foco con teclado/D-pad o al hacer hover sobre cualquier elemento interactivo de la app, igual que en la pantalla de juego online, para localizar el foco en TV.

## Scope
- In:
  - Listener global de foco primario (`FocusManager`) para teclado/D-pad.
  - Detección global de hover sobre elementos con acción de pulsación.
  - Uso del tono configurado en `buttonSoundKeyProvider` y del debounce existente.
  - Supresión del sonido durante el arranque para no sonar con el autofoco inicial.
  - `AppHover` con sonido de hover activado por defecto y `ScaleButton` con sonido de hover.
- Out:
  - Cambiar el catálogo de sonidos.
  - Sonidos al pulsar (solo foco/hover).

## Checklist
- [x] Crear `NavigationSoundListener` con foco y hover globales; `flutter analyze`.
- [x] Montarlo en `MaterialApp.builder`; comprobar que cubre rutas y diálogos.
- [x] Activar sonido por defecto en `AppHover` y añadirlo a `ScaleButton`; quitar los `false` explícitos de elementos interactivos.
- [x] `flutter analyze` sin problemas; demostrar salida.

## Evidence
- Nuevo `lib/core/audio/navigation_sound_listener.dart`:
  - Foco: `FocusManager.instance.addListener`; cuando cambia `primaryFocus` a un nodo distinto del `rootScope` reproduce el tono configurado.
  - Hover: `Listener` raíz con `onPointerHover`; hace un `hitTestInView` y busca el primer `RenderSemanticsGestureHandler` con acción `onTap`/`onLongPress`. Solo suena cuando cambia ese gesto, no en cada píxel; los scrolls y textos no pulsables no suenan.
  - Ambos caminos usan `buttonSoundKeyProvider` + `assetForButtonSoundKey` y el debounce de 90 ms de `HoverSoundPlayer`. Los primeros 800 ms se silencian para no sonar con el autofoco inicial.
- `lib/app.dart`: `MaterialApp.builder` envuelve `DeviceSimulatorHost` con `NavigationSoundListener`, así que cubre Navigator, rutas, diálogos, menús y la barra de debug.
- `lib/core/widgets/app_hover.dart`: `playSoundOnHover` pasa a `true` por defecto (todas las tarjetas y botones que usan el hover universal suenan al entrar con ratón; el foco ya lo cubre el listener global).
- `lib/core/widgets/scale_button.dart`: pasa a `ConsumerStatefulWidget` y reproduce el tono al entrar con el ratón; cubre menú de Ajustes, sidebar, isla flotante, presets, sliders y splash.
- Eliminados los `playSoundOnHover: false` explícitos de radio (chips y emisoras), botón Jukebox de cabecera y segmentos 2D/3D.
- `flutter analyze` → `No issues found!`.

## Next
Probar en TV/escritorio: mover foco por todas las pantallas comprobando un tono por salto real, hover sobre tarjetas/botones/switches, y confirmar que con "Sin sonido" en Ajustes > Sonidos no suena nada.
