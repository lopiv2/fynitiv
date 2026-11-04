# FTD — Goteo mucoso de sangre en Halloween

## Intent

Hacer más realista el goteo de Halloween: cada gota debe estirarse desde su letra, alcanzar una longitud límite, desprenderse y caer al suelo (borde inferior de la ventana), con forma viscosa, brillo húmedo y un pequeño impacto.

## Scope

- `lib/router/splash_screen.dart`: sustituir la gota ovalada con trazo lineal por una animación por fases (estiramiento pegajoso, desprendimiento/caída, salpicadura), manteniendo orígenes medidos desde las letras y activación solo tras la presentación.
- No tocar las personalizaciones manuales de color/tamaño/borde/chorretes de Halloween ni la nieve navideña.
- Sin cambios de textos (no ARB), sin tests (no solicitados), sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] FTD creado antes del primer cambio.
- [x] Gotas se estiran desde la letra hasta un límite y luego se desprenden.
- [x] Caen al borde inferior con brillo viscoso e impacto.
- [x] `flutter analyze` limpio.

## Evidence

- `dart format lib/router/splash_screen.dart` → archivo formateado.
- `flutter analyze lib/router/splash_screen.dart lib/features/splash/presentation/presentations/halloween_splash_presentation.dart` → No issues found.
- Los capdrips interiores se estiran con el clipper hasta la línea base durante el 58% inicial del ciclo. Luego `_BloodRainPainter` desprende en los mismos centros, con anchura de cuerpo, velocidad, hilo brillante y salpicadura en el borde inferior.

## Next

- Verificar visualmente con override `halloween` que la transición estirar → caer → salpicar es legible mientras se espera Play y ajustar escala si hiciera falta.
