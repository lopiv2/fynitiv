---
type: spec
title: Spec — Juego local RomM con sync de dispositivo
description: WHAT and WHY for local RomM play (pairing, download, emulador externo, sync de saves/sesiones) — problem, goals, behaviour, acceptance criteria.
tags: [sdd, spec]
timestamp: 2026-10-01T00:00:00Z
topic: sdd
slug: romm-local-play-sync
status: planned
---

# Spec — Juego local RomM con sync de dispositivo

> Slug: `romm-local-play-sync` · Status: clarified · Created: 2026-10-01
> Inherits: [constitution](../constitution.md)

## Problem & why

Hoy fynitiv reproduce los juegos de RomM abriendo el reproductor del **servidor** (navegador o
streaming de EmulatorJS). Esa vía depende de una sesión de navegador que un cliente con API key no
puede sostener, no funciona sin conexión, y deja la partida atada al servidor. El dueño de una
instancia RomM quiere jugar en el **dispositivo** con su propio emulador y que biblioteca, sesiones
de juego y partidas guardadas sigan sincronizadas entre dispositivos.

## Cost of not building it

Se sigue dependiendo del juego en navegador (sin offline, sin continuidad de partidas entre
dispositivos) y de pegar a mano un token largo. El usuario que juega fuera de casa o en un handheld
no puede continuar su partida; la biblioteca de fynitiv queda como catálogo, no como consola.

## The cheapest alternative

Mantener el juego en navegador actual y seguir usando la app oficial **Argosy** (Android) o **Grout**
(handheld) en paralelo solo para el juego local. Coste: dos apps, dos bibliotecas, sin la integración
con la UI/skins de fynitiv, y el usuario ya tiene fynitiv como cliente único de su multimedia. Es un
parche aceptable solo si no se quiere el juego local dentro de fynitiv.

## Goals

- Emparejar el dispositivo con RomM mediante **QR (aprobación desde el móvil)**, sin teclear la API
  key ni el token.
- **Descargar** un juego a demanda y **lanzarlo en el emulador externo** del dispositivo.
- Reportar **sesiones de juego** (tiempo jugado) a RomM al terminar la sesión.
- Mantener **partidas guardadas** (saves) sincronizadas en dos direcciones con RomM, con resolución
  de conflictos clara.
- Continuidad entre dispositivos que comparten la misma cuenta RomM.

## Non-goals / out of scope

- Emulador embebido en la app (libretro/FFI). Diferido a otro ciclo.
- Navegar/descargar toda la biblioteca offline de golpe (catálogo offline completo).
- Transporte SSH de sync.
- Share de tokens entre usuarios o multi-cuenta.
- RetroAchievements, netplay, ROM patcher.

## Users & context

Dueño de una instancia RomM self-hosted 5.x que usa fynitiv en un dispositivo Android (handheld/TV)
o Windows. Quiere pulsar Jugar en fynitiv, que se abra su emulador con el juego, y que al volver la
partida y el progreso estén en RomM para poder retomarlo en otro dispositivo.

## Behaviour

- Main path: el usuario abre Ajustes → Juego online, introduce la URL del servidor y pulsa **Emparejar
  con QR**; fynitiv muestra un QR (y un código) que el usuario escanea/aprueba desde su móvil ya
  logueado en RomM. El dispositivo queda conectado y registrado, sin teclear la API key. En el detalle
  de un juego, Jugar descarga el juego (si falta) mostrando progreso, lo entrega al emulador
  configurado, y al cerrar la sesión registra el tiempo jugado y sincroniza las partidas. Plataformas
  de este ciclo: **Android y Windows**.
- Edge cases: juego ya presente en local (no se vuelve a descargar); sin emulador configurado (se
  guía al usuario a configurarlo); descarga interrumpida (se puede reintentar); partida cambiada en
  dos dispositivos desde el último sync (conflicto).
- Error paths: código caducado o denegado (se pide/reintenta); sin permiso suficiente (se explica);
  servidor inalcanzable (se avisa y se sigue pudiendo jugar offline); fallo al abrir el emulador (se
  avisa); subida de partida rechazada por tamaño (se explica el límite).
- Sync: cubre **partidas (saves) y estados (states)**. Se dispara de forma **manual** y
  **automáticamente al cerrar cada sesión de juego**.
- Conflictos: ante una partida cambiada en local y en servidor desde el último sync, **se conservan
  ambas sin sobrescribir nada**; el usuario decide después qué hacer.

## Acceptance criteria

- Given un servidor RomM 5.x, When el usuario pulsa Emparejar con QR y aprueba el dispositivo desde su
  móvil, Then fynitiv queda conectado sin introducir la API key.
- Given un QR no aprobado dentro de la ventana de validez, When caduca, Then fynitiv lo indica y
  permite reintentar.
- Given un juego descargable que no está en local, When el usuario pulsa Jugar, Then el juego se
  descarga con progreso visible y se entrega al emulador configurado.
- Given un juego ya descargado, When el usuario pulsa Jugar, Then se abre directamente sin volver a
  descargar.
- Given una sesión de juego terminada, When el usuario vuelve a fynitiv, Then el tiempo jugado queda
  registrado en RomM y se lanza un sync automático.
- Given una partida local más reciente que la del servidor, When se sincroniza, Then la partida se
  sube y sigue disponible en otro dispositivo.
- Given que existen saves y states locales, When se sincroniza, Then ambos tipos se sincronizan.
- Given una partida o estado modificado en dos dispositivos desde el último sync, When se sincroniza,
  Then se conservan ambas versiones y no se sobrescribe nada sin confirmación del usuario.
- Given que el servidor no responde, When el usuario quiere jugar a un juego ya descargado, Then
  puede jugarlo igualmente en local.

## Points to clarify

Resueltos en la fase `clarify` (2026-10-01):

- **resuelto** — Plataformas de este ciclo: **Android + Windows**. (Antes: pregunta abierta.)
- **resuelto** — Sync de **saves + states**. (Antes: pregunta abierta.)
- **resuelto** — Sync **manual + automático al cerrar sesión**. (Antes: pregunta abierta.)
- **resuelto** — Conflictos: **conservar ambas sin sobrescribir**, el usuario decide después.
  (Antes: pregunta abierta.)
- **suposición tomada** — se conserva el modo API Key manual como alternativa cuando el servidor no
  soporte emparejamiento. *Base:* respuesta del usuario en la planificación. *Riesgo:* mantener dos
  flujos de auth duplica UI y pruebas.
- **suposición tomada** — el juego local se delega a un **emulador externo** que el usuario tiene
  instalado, no a uno embebido. *Base:* modelo Argosy, elegido por el usuario. *Riesgo:* si se quiere
  in-app, cambia por completo el alcance y los goals.
- **decisión diferida** — retención y limpieza de ROMs/partidas descargadas (cuántas copias de
  seguridad locales se conservan); fuera de este ciclo.
- **área no formulable** — mapeo de rutas de partidas/estados por emulador/plataforma en cada SO;
  sospecho que hay una pregunta de configuración aún no bien enunciada (a resolver en `plan`).
