# FTD — Chorretes de Halloween hasta la base de la letra

## Intent

Corregir la trayectoria: los hilos de sangre deben nacer en la parte superior visible de cada glifo, estirarse hasta su línea base (fin de la tinta, no la sombra) y solo entonces desprender la gota para que caiga al suelo. Tras el impacto, el hilo vuelve a empezar desde arriba.

## Scope

- Implementación refinada en `splash-halloween-capdrips-caida-sincronizada.md`: los capdrips del `SnowDripClipper` se extienden dentro del glifo hasta su baseline; el painter exterior solo desprende la gota desde ese mismo extremo.
- Mantener la variación pseudoaleatoria por ciclo, el brillo viscoso, el impacto en el borde inferior y la geometría sin lecturas inválidas de RenderBox.
- No tocar personalizaciones manuales, sin tests (no solicitados), sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] FTD creado antes del primer cambio.
- [x] El chorrete recorre la letra desde arriba hasta el baseline visible.
- [x] La gota solo se desprende al llegar a la base y después cae hasta el suelo.
- [x] `flutter analyze` limpio.

## Evidence

- `dart format lib/router/splash_screen.dart` → archivo formateado.
- `flutter analyze lib/router/splash_screen.dart` → No issues found.
- La revisión concreta del usuario aclaró que el origen/recorrido buscado son los `capDrips` recortados dentro de las letras, no las líneas independientes añadidas al overlay. La nueva FTD sincroniza esos capdrips con la caída exterior usando los mismos centros y semillas.

## Next

- Verificación visual absorbida por `splash-halloween-capdrips-caida-sincronizada.md`.
