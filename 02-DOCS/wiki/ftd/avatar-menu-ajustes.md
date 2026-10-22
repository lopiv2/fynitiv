# Ajustes y Apariencia en el menú del avatar

## Intent
Al pulsar el avatar, mostrar encima de "Cerrar sesión" accesos a Ajustes y a Apariencia (para modificar el skin u otras cosas), con enlace directo a la sección correspondiente.

## Scope
- In:
  - `UserAvatarMenu` genérico: nuevos callbacks `onSettings`/`onAppearance` y dos entradas de menú (icono ajustes + icono paleta) con `Divider` antes de "Cerrar sesión"; reutiliza claves ARB existentes (`settings`, `appearance`, `logout`).
  - `Sidebar` y `NetflixTopBar`: pasan `onNavigateBranch(7)` para Ajustes y `context.go('/settings?section=appearance')` para Apariencia.
  - `SettingsScreen`: nuevo `initialSection` (defecto `preferences`); `initState`/`didUpdateWidget` lo aplican al provider de sección.
  - Router: `/settings` parsea `?section=` (`preferences|appearance|home|games|sounds|account|about`, fallback `preferences`).
- Out:
  - No cambiar items ni estilo del menú salvo las dos entradas nuevas; no tocar `PrimeCardBadge`; sin ARB nuevas; sin tests (no pedidos) y sin `flutter build` (solo `flutter analyze`).

## Checklist
- [ ] `UserAvatarMenu` con las dos entradas + divider; comprobar `flutter analyze`.
- [ ] Callbacks en `Sidebar` + `NetflixTopBar`; comprobar `flutter analyze`.
- [ ] `initialSection` + query param en router; comprobar `flutter analyze`.
- [ ] `flutter analyze` sin problemas; demostrar salida.

## Evidence
- `user_avatar_menu.dart`: callbacks `onSettings`/`onAppearance`; menú con Ajustes (icono) + Apariencia (paleta) + `Divider` antes de Cerrar sesión; reutiliza ARB `settings`/`appearance`/`logout`.
- `sidebar.dart` (lateral + classic) y `netflix_top_bar.dart`: Ajustes → rama 7, Apariencia → `/settings?section=appearance`.
- `settings_screen.dart`: `initialSection` aplicado en `initState`/`didUpdateWidget` al provider de sección.
- `app_router.dart`: `/settings` parsea `?section=` con fallback a `preferences` (corregido orden de params del builder).
- `flutter analyze` → `No issues found! (ran en 6.7s)`.

## Next
- Probar en app: avatar → Ajustes (sección Preferencias), avatar → Apariencia (panel de skin), volver y comprobar sección recordada; mando en modo TV.
