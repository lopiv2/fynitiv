# FTD: Prime topbar glassmorphism

## Intent
La barra top de Prime es transparente arriba pero al hacer scroll se vuelve negra sólida arriba. Se quiere un glassmorphism transparente (blur + translúcido) en lugar del negro opaco.

## Scope
- `lib/features/library/presentation/widgets/sidebar.dart`: variante barra superior fija Prime (no isla, no Netflix).
- Mantener: altura 60, margen horizontal 40 / vertical 8, radius inferior 12 en Prime, navegación, lupa, avatar, foco TV, `barOpacity` desde `home_shell.dart`.
- No tocar: `FloatingIslandBar`, `NetflixTopBar`, badges, ARB (sin textos nuevos).

## Checklist
- [x] Doc FTD creado antes del cambio
- [x] Barra Prime usa `ClipRRect` + `BackdropFilter` con blur proporcional a `barOpacity`
- [x] Fondo translúcido (`sidebarBackground` con alpha ~0.55 * opacity) en vez de opaco
- [x] Borde/sombra sutiles proporcionales a `barOpacity`, transparentes arriba
- [x] `flutter analyze` sin nuevos problemas en el archivo tocado

## Evidence
- Antes: `effectiveBg = bg.withValues(alpha: barOpacity)` → negro opaco al scrollear (`sidebar.dart:319`), `AnimatedContainer` con color sólido.
- Después: `flutter analyze lib/features/library/presentation/widgets/sidebar.dart` → No issues found. Barra Prime con `ClipRRect` + `BackdropFilter` (blur 18 * barOpacity), fondo `bg` alpha 0.55 * barOpacity, borde blanco 0.14 y sombra 0.28.

## Next
- Verificar visualmente en skin Prime: arriba transparente sin blur, al scrollear glass con blur.
- Si gusta, extender el mismo glass a `NetflixTopBar`.
