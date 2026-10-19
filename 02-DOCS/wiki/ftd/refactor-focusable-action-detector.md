# Refactor de controles de foco

## Intent
Refactorizar la implementación propia de foco/hover para aprovechar el `FocusableActionDetector` incluido en Flutter, sin añadir `focusable_control_builder` ni otra dependencia y sin perder el comportamiento de TV/escritorio.

## Scope
- In:
  - Evaluar/refactorizar el interior de `ScaleButton` con el `FocusableActionDetector` nativo.
  - Mantener la API pública y el soporte de `FocusNode` externo, autofocus, Enter/OK, hover/focus, sonido configurado y callbacks visuales.
  - Conservar la navegación direccional y los FocusNodes compartidos de barras/featured slider.
- Out:
  - Añadir la dependencia `focusable_control_builder`.
  - Cambiar el comportamiento visual o el enrutamiento de la navegación.

## Checklist
- [ ] Revisar la API existente y mapear las interacciones de `ScaleButton` a `FocusableActionDetector`.
- [ ] Implementar el refactor conservando nodos externos y atajos de mando.
- [ ] Verificar con `flutter analyze` y pruebas manuales en TV/escritorio.

## Evidence
- El usuario eligió la opción A: no añadir el paquete; considerar el `FocusableActionDetector` nativo para el refactor.
- A petición del usuario, hoy solo se registra esta tarea; no se modifica código ni se ejecutan verificaciones.

## Next
Retomar mañana: inspeccionar `ScaleButton`, implementar el refactor de forma compatible y comprobar foco/hover en teclado y D-pad, especialmente la navegación desde el featured slider a las barras superior y lateral.
