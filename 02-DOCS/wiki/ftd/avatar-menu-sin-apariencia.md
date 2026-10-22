# Quitar Apariencia del menú del avatar

## Intent
Dejar en el menú del avatar solo Ajustes + Cerrar sesión, ya que Apariencia vive dentro de Ajustes; eliminar el deep-link que queda sin uso.

## Scope
- In:
  - `UserAvatarMenu`: fuera callback `onAppearance` y su entrada de menú.
  - `Sidebar` + `NetflixTopBar`: fuera callbacks `onAppearance`.
  - `SettingsScreen`: fuera `initialSection` (`initState`/`didUpdateWidget`); `app_router.dart` vuelve a `const SettingsScreen()` sin `?section=`.
- Out:
  - No tocar el resto del menú ni el router; sin ARB nuevas; sin tests (no pedidos) y sin `flutter build` (solo `flutter analyze`).

## Checklist
- [x] Entrada y callback eliminados; comprobar `flutter analyze`.
- [x] Deep-link revertido sin código muerto; comprobar `flutter analyze`.
- [x] `flutter analyze` sin problemas; demostrar salida.

## Evidence
- `user_avatar_menu.dart`: solo Ajustes + `Divider` + Cerrar sesión.
- `sidebar.dart`, `netflix_top_bar.dart`: solo `onSettings` → rama 7.
- `settings_screen.dart` sin `initialSection`; `app_router.dart` con `const SettingsScreen()`.
- `flutter analyze` → `No issues found! (ran en 10.1s)`.

## Next
- Probar en app: avatar → Ajustes, avatar → Cerrar sesión; Apariencia solo desde dentro de Ajustes.
