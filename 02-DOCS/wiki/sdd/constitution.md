---
type: constitution
title: fynitiv — Constitution
description: The non-negotiable principles every rsc-sdd phase obeys.
tags: [sdd, constitution]
timestamp: 2026-10-01T00:00:00Z
topic: sdd
version: v1.0.0
---

# fynitiv — Constitution

> Version: v1.0.0 · Ratified: 2026-10-01 · Last amended: 2026-10-01
> Principios no negociables que toda fase rsc-sdd obedece. El detalle mecánico vive en
> `02-DOCS/wiki/` y en `AGENTS.md`; este fichero ratifica el principio y enlaza el detalle.

## 1. Stack canon

1. Lenguaje y runtime: **Dart** (`sdk: ^3.12.2`) sobre **Flutter 3.49** (channel master),
   fijados en `pubspec.yaml`. Detalle: `AGENTS.md`.
2. Frameworks fijos: **Riverpod** (estado/DI), **go_router** (rutas), **Dio** (HTTP),
   **material_ui**, **gen-l10n** (i18n). Cambiar uno es una enmienda MAJOR.
3. Gestor de paquetes: **pub** (`flutter pub`). Un único `pubspec.lock` commiteado.

## 2. Barra de calidad

4. `flutter analyze` pasa sin issues en los ficheros tocados antes de cerrar la respuesta.
   Enforcer: comando `flutter analyze`.
5. **Nunca se ejecuta `flutter build ...`** al terminar una respuesta; el build lo lanza el
   desarrollador. Enforcer: regla en `AGENTS.md`.
6. **No se escriben ni ejecutan tests** salvo petición explícita del usuario en el prompt.
   Enforcer: regla en `AGENTS.md`.
7. **No se añaden comentarios** al código salvo que el usuario los pida. Enforcer: `AGENTS.md`.

## 3. Convenciones

8. Todo texto de widget se traduce con cadenas **ARB** (`lib/l10n/app_en.arb` + `app_es.arb`),
   reutilizando claves existentes y autogenerando (no editar ficheros `app_localizations*.dart`
   a mano). Enforcer: `AGENTS.md`.
9. Notificaciones de usuario siempre con **flutter_easyloading** (nunca
   `ScaffoldMessenger`/`SnackBar`). Enforcer: `AGENTS.md`.
10. Toda petición Dio a Jellyfin/RomM usa el loader universal (**AppLoader**) mientras carga.
    Enforcer: `AGENTS.md`.
11. Las tarjetas usan el **widget universal de Hover**. Enforcer: `AGENTS.md`.
12. Se prefieren métodos de la API de **jellyfin_dart** antes de llamadas crudas. Enforcer:
    `AGENTS.md`.
13. Los ficheros `PrimeCardBadge` y cualquier elemento corregido a mano por el usuario **no se
    tocan** sin preguntar. Enforcer: `AGENTS.md`.
14. Todo skin nuevo con scroll slider debe ajustar el **Focus** para no perder funcionalidad del
    modo TV. Enforcer: `AGENTS.md`.

## 4. Ramas y entrega

15. **La autoría de los commits es del humano.** Sin `Co-Authored-By` de una IA, sin footer
    "generated with". Enforcer: fase `ship`.
16. **No se commitea** salvo petición explícita del usuario. Enforcer: `AGENTS.md`.
17. **No se hace checkout de una versión anterior** sin preguntar antes. Enforcer: `AGENTS.md`.

## 5. Seguridad y privacidad

18. Ningún secreto se commitea. Los tokens de RomM/Jellyfin se guardan en
    `flutter_secure_storage`; la contraseña nunca se persiste en claro. Enforcer:
    `RommStorage` / `SessionStorage`.

## 6. Conocimiento y decisiones

19. Por cada feature o fix se crea y mantiene un documento **FTD** en
    `02-DOCS/wiki/ftd/<slug>.md` con el formato exacto `Intent`, `Scope`, `Checklist`,
    `Evidence`, `Next`, escrito antes del primer cambio. Enforcer: `AGENTS.md`.
20. Toda decisión significativa se anota en `02-DOCS/wiki/sdd/decisions.md` (fecha, opciones,
    por qué). Este fichero es el registro de decisión de mayor orden.

## Definition of Done (barra de merge que `verify` comprueba)

Un cambio se entrega solo cuando TODO se cumple:

- [ ] `flutter analyze` limpio (principio 4).
- [ ] No se ha ejecutado `flutter build` (principio 5).
- [ ] No se han añadido tests ni comentarios no pedidos (principios 6-7).
- [ ] Cadenas ARB EN+ES, EasyLoading, AppLoader y Hover universal donde aplica (principios 8-11).
- [ ] No se han tocado elementos corregidos a mano sin permiso (principio 13).
- [ ] Sin secretos commiteados (principio 18).
- [ ] FTD creado/actualizado y decisiones anotadas (principios 19-20).

## Amendment log (append-only)

| Date | Version | Change | Why |
|------|---------|--------|-----|
| 2026-10-01 | v1.0.0 | Constitución inicial redactada y **ratificada** por el usuario. | Arranque del SDD del feature `romm-local-play-sync`. |
