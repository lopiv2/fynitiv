# FTD: Spotlight horizontal Netflix

## Intent
Al enfocar con teclado una tarjeta Netflix, centrar verticalmente su fila en pantalla sin alterar la alineación horizontal a la izquierda.

## Scope
- In: centrar verticalmente la fila Netflix enfocada usando el scroll de página, manteniendo el scroll horizontal manual en el borde izquierdo.
- Out: cambiar el layout spotlight de otros skins, el billboard, el enrutamiento o los badges.

## Checklist
- [x] Mostrar contorno blanco al enfocar tarjetas en scrolls horizontales Netflix.
- [x] Expandir la tarjeta Netflix activa y desplazar las siguientes sin cambiar otros skins.
- [x] Integrar metadatos en la tarjeta activa con altura de fila reservada.
- [x] Ajustar la imagen enfocada a la escala de la referencia y separar/agrandar el meta bajo ella.
- [x] Reducir a la mitad el tamaño actual de la imagen enfocada sin cambiar los metadatos ni otros skins.
- [x] Mostrar el reborde blanco solo alrededor de la imagen activa.
- [x] Desplazar la tarjeta activa a la izquierda y mantenerla ahí durante el hover automático.
- [x] Permitir al scroll llegar al último elemento alineado a la izquierda.
- [x] Sincronizar la selección de ratón y teclado sin dejar hover fijado al cambiar de modalidad.
- [x] Evitar bordes de selección simultáneos en tarjetas Netflix no activas.
- [x] Mostrar logo o texto fallback en la imagen activa, encima del meta.
- [x] Aumentar ligeramente la altura del logo y fallback.
- [x] Mantener el elemento enfocado al borde izquierdo también con el autoscroll de teclado.
- [x] Elegir la dimensión de referencia mayor según orientación del viewport.
- [x] Añadir un límite superior responsive al ancho calculado.
- [x] Aplicar factores distintos para TV y escritorio sin cambiar móvil.
- [x] Mostrar clasificación/géneros una sola vez, en el meta inferior.
- [x] Restaurar la alineación izquierda del foco Netflix.
- [x] Centrar verticalmente la fila con spotlight Netflix al enfocarla con teclado.
- [x] `flutter analyze` sin problemas.

## Evidence
- `ContentRow._wrapForTv` aplica el contorno blanco al skin Netflix mediante `scaleHighlightOutline`; el análisis anterior fue limpio.
- Los spotlight actuales escalan la tarjeta dentro de su espacio y pintan los metadatos en una capa separada, por eso las tarjetas vecinas no se desplazan.
- `ContentRow` ahora calcula la posición acumulada y el ancho del scroll con el ancho spotlight; `AnimatedPositioned` anima tamaño y desplazamiento. La tarjeta activa usa `BackdropCard` y muestra la tira de metadatos dentro de la misma tarjeta.
- Se reserva altura según el backdrop expandido y su tira de metadatos para evitar que invada la siguiente fila.
- La referencia aportada muestra la tarjeta enfocada cercana a la mitad del viewport y el meta con separación bajo la imagen; el render actual queda más pequeño y el texto demasiado pegado.
- El ancho enfocado Netflix ahora toma el mayor entre el ancho base multiplicado por `spotlightScale` y el 49 % del viewport; sus metadatos usan tipografía mayor y espaciado propio, en fondo negro debajo de la imagen.
- Solicitud de ajuste: conservar el resto del resultado y reducir a la mitad el tamaño actual de la imagen enfocada.
- `_spotlightCardWidth` en Netflix ahora devuelve el 50 % del ancho enfocado calculado anteriormente; los demás skins no cambian.
- `flutter analyze` → `No issues found! (ran in 4.0s)`.
- En el spotlight Netflix actual, `AppHover` aplica el outline alrededor de toda la tarjeta compuesta, incluida la zona de metadatos.
- En Netflix spotlight, `AppHover` conserva la notificación de foco/hover pero no dibuja su outline exterior; la tarjeta de imagen muestra el borde mediante `AppHoverScope`.
- `flutter analyze` → `No issues found! (ran in 4.0s)`.
- Solicitud: en Netflix, el elemento ampliado debe quedar alineado al borde izquierdo, sin tarjetas visibles a su izquierda.
- `ContentRow` anima el scroll al inicio de la tarjeta activa en hover/foco; mantiene el índice hover activo mientras el contenido se mueve bajo el puntero.
- `_contentWidth` reserva trailing space solo cuando hace falta, permitiendo alinear a la izquierda incluso la última tarjeta.
- `flutter analyze` → `No issues found! (ran in 4.2s)`.
- Reporte: el hover fijado podía seguir activo al navegar con teclado, haciendo que ambos focos destacaran elementos diferentes.
- El foco de teclado limpia los índices de hover/fijado; el hover tiene prioridad visual temporal, mientras el borde de imágenes no activas queda oculto.
- Las tarjetas `PosterCard` y `BackdropCard` también dibujan bordes desde su estado local; Netflix spotlight debe ocultar el borde de las no activas.
- `PosterCard`/`BackdropCard` aceptan `showImageHoverBorder`; en Netflix spotlight solo la tarjeta activa conserva su borde. El getter de selección prioriza hover/pin y después foco, y el foco limpia el hover al tomar el control.
- `flutter analyze` → `No issues found! (ran in 4.1s)`.
- `itemLogoUrl` resuelve el logo propio o el del padre, pero el spotlight activo no lo muestra de forma obligatoria ni ofrece texto fallback si falta.
- El spotlight Netflix ahora superpone el logo del item (incluido fallback de logo padre de `itemLogoUrl`) abajo a la izquierda; si falta o falla la imagen, muestra el nombre del item encima del meta.
- El tamaño actual usa `cardWidth * 0.23`, limitado entre 38 y 56 px; se conserva el multiplicador ajustado manualmente y solo se ampliará el máximo.
- Límite máximo aumentado de 56 a 64 px; el fallback de texto comparte la misma altura.
- `flutter analyze` → `No issues found! (ran in 4.3s)`.
- `AppHover.setFocused` llama a `Scrollable.ensureVisible` con `alignment: 0.5`, que centra el elemento después de que `ContentRow` solicita alinearlo a la izquierda.
- `AppHover.ensureVisibleOnFocus` ahora permite desactivar ese centrado; `ContentRow` lo desactiva solo para el spotlight Netflix y conserva su alineación izquierda.
- `flutter analyze` → `No issues found! (ran in 4.1s)`.
- El cálculo actual usa la dimensión mayor del viewport multiplicada por `0.65`, luego por `0.7`; estos factores manuales deben conservarse.
- El ancho final ahora se limita al 55 % del viewport, excepto si el ancho base de tarjeta es mayor; se conservan los factores `0.65` y `0.7`.
- `PlatformMode` distingue `tv`, `desktop` y `mobile`; la propuesta conserva `0.65` en móvil, usa `0.55` en TV y `0.40` en escritorio.
- `_spotlightCardWidth` selecciona esos factores por `platformModeProvider`; `flutter analyze` → `No issues found! (ran in 4.0s)`.
- En el spotlight activo, `BackdropCard` construye su propio subtítulo con clasificación y géneros; `_buildSpotlightInfo` vuelve a mostrar esos segmentos debajo.
- `BackdropCard.hideSubtitle` permite suprimir ese subtítulo solo en la imagen activa Netflix; `_buildSpotlightInfo` conserva la línea inferior concatenada.
- `flutter analyze` → `No issues found! (ran in 4.2s)`.
- El último cambio reactivó `Scrollable.ensureVisible` con alineación `0.0` para Netflix; también alteró la alineación de su scroll horizontal.
- Se revirtió la opción de alineación genérica y se volvió a desactivar `ensureVisibleOnFocus` solo para Netflix spotlight; su scroll horizontal manual sigue activo.
- `ContentRow` conserva la `ScrollPosition` vertical de la página; al reactivar `Scrollable.ensureVisible` se alteró también el scroll horizontal.
- Al terminar la expansión, `ContentRow` revela la fila en el `RenderViewport` vertical con alineación `0.5`; el controlador horizontal sigue alineando el elemento a la izquierda.
- `flutter analyze` → `No issues found! (ran in 4.2s)`.
- `flutter analyze` → `No issues found! (ran in 4.1s)`.

## Next
- Verificar visualmente que la fila queda centrada verticalmente y el elemento continúa a la izquierda.
