# Foco de navegación en barras laterales (TV/escritorio)

## Intent
Que el D-pad o el teclado puedan entrar en la barra lateral, moverse por sus elementos y salir al contenido, igual que en la barra superior de Prime, sin quedarse atrapado en las filas de contenido. Debe funcionar tanto en TV como en escritorio.

## Scope
- In:
  - Navegación direccional por flechas desde el `FocusScope` del shell en TV y escritorio.
  - Fallback del grupo del shell cuando el grupo/scope actual no encuentra candidato.
  - Exclusión de campos de texto para no robar las flechas del cursor.
- Out:
  - Cambiar el diseño de la barra lateral ni sus tamaños.
  - Cambiar el comportamiento de móvil (táctil/scroll del sistema).

## Checklist
- [x] Extender `HomeShell` con un handler de flechas en TV y escritorio; `flutter analyze`.
- [x] Intentar primero el grupo actual y luego el grupo del shell; `flutter analyze`.
- [x] Respetar `EditableText`; `flutter analyze`.
- [x] `flutter analyze` sin problemas; demostrar salida.

## Evidence
- Causa: el contenido de cada rama vive en el `FocusScope` de su ruta, mientras que la barra lateral es hermana de ese contenido en `HomeShell`. `FocusNode.focusInDirection` busca en el scope más cercano, así que desde una tarjeta nunca podía alcanzar la barra (Disney+). Prime funcionaba porque el slider tiene un `↑` explícito a `tvInicioFocusNode`.
- `lib/router/home_shell.dart`: el `FocusScope` del shell maneja flechas en `PlatformMode.tv` y `PlatformMode.desktop` mediante `_handleArrowNavigation` (también con `KeyRepeatEvent`, para mantener pulsado):
  1. Ignora el evento si el foco está dentro de un `EditableText` (las flechas mueven el cursor).
  2. Intenta el grupo/scope más cercano con `focus.focusInDirection`: mueve dentro de la fila, rejilla o lista.
  3. Si no hay candidato (borde de la fila), repite con el `FocusScopeNode` del shell, cuyos descendientes incluyen la barra lateral y el contenido. Así se cruza de contenido a sidebar (izquierda) y de sidebar a contenido (derecha/abajo según geometría).
  4. Excepción para la barra superior: hacia arriba solo se cruza al shell si no queda ningún elemento enfocable por encima dentro del scope actual (`_hasFocusableAbove`). Así la barra superior solo se alcanza desde el elemento más alto de la pantalla (p. ej. el featured slider en Inicio/VOD); desde una fila inferior, `↑` mueve a la fila de arriba.
- En móvil no se interviene: se mantienen los gestos táctiles y el scroll por flechas del sistema.
- El scroll horizontal/vertical sigue acompañando al foco mediante `ensureVisible` de `AppHover` y el `requestFocusCallback` del `FocusTraversalPolicy`.
- Se mantiene el comportamiento existente de expandir la sidebar al pulsar izquierda.
- `flutter analyze` → `No issues found!`.

## Next
Probar en escritorio y TV/overlay D-pad: entrar a la barra de Disney+ desde una fila, moverse arriba/abajo, salir a la derecha y repetir en Prime. Verificar también `↑` desde el featured slider en Inicio y VOD, y con la sidebar colapsada en escritorio.

## Corrección (↑ desde el featured slider)
- Causa: el slider sube a la barra con `tvInicioFocusNode.requestFocus()`, pero ese nodo solo se asignaba al item Inicio si `currentIndex == 0 && activeViewId == null`. En VOD (o con una biblioteca activa) el nodo no estaba montado y `requestFocus()` no hacía nada.
- Fix: `Sidebar` asigna `tvInicioFocusNode` al item Inicio siempre que se construye (TV y escritorio), no solo cuando Inicio está activo.
- Además, si la barra no está montada (p. ej. sidebar colapsada en escritorio), el slider sube recorriendo los `FocusScope` padres en dirección arriba.
- `flutter analyze` → `No issues found!`.
