# Foco visible en los controles del reproductor (mando/D-pad)

## Intent
Que todos los controles del overlay de vídeo del reproductor muestren un efecto de
hover/foco claramente visible al pasar con el mando o el D-pad (y con el ratón), usando el
foco nativo de cada control sin añadir nodos de foco extra que romperían la navegación.

## Scope
- In:
  - `_PlayerIconButton` (IconButton con foco/hover blancos marcados y esquinas redondeadas)
    para: atrás, `<<`, play/pausa, `>>`, silencio y pantalla completa.
  - `_BigButton` central con `focusColor`/`hoverColor` explícitos.
  - Menús (`_PlaybackSpeedButton`, `_SubtitleButton`, `_AudioButton`): pasar de `child:` a
    `icon:` + `style` con fondo que resuelve `focused`/`hovered` (el path `child:` ignora
    `style` y usa un InkWell con colores de tema sutiles).
  - Sliders (progreso y volumen): `overlayColor` visible solo en `focused`, sin tocar el resto
    de estados.
  - `_SearchSubtitlesButton` (InkWell): `focusColor`/`hoverColor` explícitos.
- Out:
  - UI de música (`_AudioCover` y portada): mismo reproductor pero otra pantalla.
  - Diálogos (sync de subtítulos): fuera del transporte; se hará aparte si se pide.
  - Cambiar las flechas en raíz (siguen haciendo seek); dentro del overlay `←`/`→` pasan a
    recorrer una secuencia explícita en vez de depender de posiciones geométricas.
  - Build o tests (según AGENTS.md).

## Checklist
- [x] FTD creado antes del primer cambio.
- [x] `_PlayerIconButton` y sustitución de los 6 IconButton; `flutter analyze`.
- [x] Menús a `icon:` + `style`; sliders e InkWell con foco; `flutter analyze`.
- [x] `flutter analyze` sin problemas (`No issues found!`).

## Navegación con teclado y D-pad (TV)

### Intent
Permitir entrar, moverse y salir de los controles del overlay de vídeo solo con teclado y
D-pad: Up/OK entran y enfocan play/pausa, las flechas navegan entre controles, OK activa,
Atrás vuelve a la raíz, y el auto-hide nunca deja el foco en botones invisibles.

### Scope
- In:
  - Entrada a navegación: `arrowUp`/`arrowDown`/`select`/`enter` en raíz muestran controles y
    enfocan play/pausa (`_playFocus`); `select`/`enter` con foco dentro se ignoran (activación
    nativa del botón).
  - `escape`/`goBack` con foco dentro devuelven el foco a la raíz; en raíz mantienen el
    comportamiento actual (fullscreen/exit).
  - Auto-hide y salida del ratón devuelven el foco a la raíz antes de ocultar.
  - `ExcludeFocus` con controles ocultos para que el traversal no caiga en invisibles.
  - Cualquier tecla con foco dentro rearma el auto-hide (no se oculta navegando).
- Out:
  - Cambiar seeks con `←`/`→` en raíz, `space`, `z`/`x` (se mantienen).
  - UI de música y diálogos.
- Fix fugas de foco: el timer y la salida del ratón robaban el foco a la raíz aunque se
  estuviera navegando, y con foco perdido las flechas volvían a hacer seek. Ahora un flag
  `_navMode` gobierna: en navegación no se oculta ni se roba el foco, y cualquier flecha
  re-ancla a play si el foco se perdió.
- Flujo entre controles (como el cliente oficial de TV):
  - Slider de progreso + `↓` → rebobinar (`<<`); `↑` → atrás; `←`/`→` seek ±10 s.
  - Cadena con `→`: rebobinar → play → adelantar → velocidad → (silencio) → volumen →
    subtítulos → audio → pantalla completa. Atrás cierra el menú de velocidad y el foco
    vuelve a su disparador.
  - Volumen: `Enter` acopla/desacopla; solo acoplado `←`/`→` ajustan ±5. Atrás desacopla
    primero; al perder el foco se desacopla solo.
  - Implementación: los Slider internos no son enfocables (`canRequestFocus: false`); el foco
    lo tiene un wrapper (`_SliderFocusFrame` con anillo) y `_onKey` pilota las flechas a mano,
    idéntico en escritorio y TV (el mapa nativo del Slider difiere por plataforma y en
    tradicional consumiría Up/Down).
- Navegación izquierda/derecha explícita: `FocusTraversalGroup` dedicado al overlay con
  `OrderedTraversalPolicy` y `FocusTraversalOrder` para atrás/progreso/controles/volumen/
  subtítulos/audio/fullscreen; en `_navMode`, `←`/`→` usan `previousFocus()`/`nextFocus()` del
  foco actual para resolver el orden del grupo, en vez de delegar a la geometría. Corrige el
  hop que fallaba velocidad → silencio.
- Orden aplicado en `_buildOverlay`: atrás 10, sync subtítulos 15, progreso 20, rebobinar 30,
  play 40, play central 35 (solo pausado), avanzar 50, velocidad 60, mute 70, slider de volumen
  80, subtítulos/buscar 90, audio 100, fullscreen 110. `_onKey` usa el foco primario
  (`nextFocus`/`previousFocus`), que resuelve el `OrderedTraversalPolicy` del grupo.
- `flutter analyze` → `No issues found! (ran in 5.8s)`.

### Evidence
- El traversal direccional desde un foco a pantalla completa no alcanza ningún control
  (toda la pantalla es el rect inicial), así que la entrada es explícita por tecla.
- Los botones del overlay siguen montados con opacidad 0 (`AnimatedOpacity` + `IgnorePointer`
  no excluyen foco), de ahí `ExcludeFocus` y el retorno a raíz al ocultar.

## Evidence
- `_buildOverlay` monta los controles con `IconButton` crudos (sin `focusColor`), tres
  `PopupMenuButton(child:)` y dos `Slider` sin `overlayColor`.
- El traversal ya existe (`Focus` raíz con `_onKey`: en raíz flechas = seek, con foco en hijo
  el D-pad navega entre controles); solo faltaba feedback visual.
- SDK Flutter 3.50 (C:\flutter): `IconButton` mapea `focusColor` al overlay en foco;
  `Slider` incluye `WidgetState.focused` en el overlay y `widget.overlayColor` tiene
  prioridad; `PopupMenuButton(child:)` envuelve en `InkWell` ignorando `style`, mientras el
  path `icon:` sí lo reenvía al `IconButton` interno.
- Repositorio en rama `main`.
- `_PlayerIconButton` (IconButton con `focusColor` blanco 28%, `hoverColor` 14% y forma
  redondeada r12): atrás, `<<`, play/pausa, `>>`, silencio y pantalla completa.
- `_BigButton` con foco/hover explícitos; menús de velocidad/subtítulos/audio con `icon:` +
  `_playerMenuTriggerStyle()` (fondo blanco 28% en foco, 14% en hover); sliders de progreso y
  volumen con overlay blanco 25% solo en foco; `_SearchSubtitlesButton` con foco/hover en el
  InkWell.
- Navegación TV: `_playFocus` como entrada; `arrowUp`/`arrowDown`/`select`/`enter` en raíz
  entran a navegación; `escape`/`goBack` con foco dentro vuelven a raíz; auto-hide y salida de
  ratón devuelven el foco a raíz; `ExcludeFocus` con overlay oculto; cualquier tecla rearma el
  hide.
- `flutter analyze` → `No issues found! (ran in 6.0s)`.

## Next
Probar con mando/TV que cada control se ilumina al pasar el foco y que el menú elegido se
abre con OK; si el anillo del slider queda tenue, subir su alfa.
