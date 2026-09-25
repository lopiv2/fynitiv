# Consideraciones de desarrollo

Notas y preferencias sobre cómo trabajar en este proyecto.

## Builds

- **Nunca ejecutar un build (`flutter build ...`) al terminar una respuesta.** Usar solo `flutter analyze` (y `flutter test` si procede) como verificación. El build es lento y lo ejecuta el desarrollador cuando lo pide.

## Reutilización de componentes

- Si se pide un componente que hace lo mismo que otro ya existente, generar un **widget genérico** reutilizable en lugar de duplicar código, y usarlo en los lugares que lo necesiten.

- Si se agregase un nuevo scroll slider a algun skin, siempre ajustar el Focus, para no perder funcionalidad respecto al modo TV

## Traduccion de cadenas

- Siempre que vaya a haber texto de widgets, debe traducirse con cadenas ARB, minimo a ingles y español, como ya esta en otras partes de la aplicacion. Se reutilizaran cadenas si ya existen en dichos archivos ARB, para no duplicar claves. Autogenera la cadenas ARB siempre que añadas traducciones a dichos ARB, no escribas a mano en los archivos de traduccion dart.

## Utiliza siempre el widget universal de Hover en todas las tarjetas

- Debes utilizar el widget universal de Hover en todas las tarjetas, y luego ya te ire yo diciendo el enrutamiento y todo eso hacia otras pantallas o reproductores

## Utilizar siempre el loader cuando sea necesario

- Debes utilizar el loader en cualquier parte que este haciendo una peticion DIO a una Api de Jellyfin o externa mientras carga los datos

## Sistema universal de notificaciones (flutter_easyloading)

- Usar siempre `flutter_easyloading` como sistema universal de notificaciones/toasts en toda la app. No usar `ScaffoldMessenger`/`SnackBar` para avisos al usuario.
- El paquete ya está configurado globalmente: `EasyLoading.init()` en el `builder` de `app.dart` y estilo oscuro corporativo en `main.dart` (`_configEasyLoading`).
- Uso: `unawaited(EasyLoading.showToast(text, toastPosition: EasyLoadingToastPosition.bottom, maskType: EasyLoadingMaskType.none, dismissOnTap: true))`. Usar `showSuccess`/`showError`/`showInfo` cuando el mensaje sea de éxito/error/info. El `maskType.none` es obligatorio en toasts para no bloquear la interacción.
- Los textos de las notificaciones siguen la norma de traducción con cadenas ARB (inglés y español mínimo).

## Utilizar siempre metodos de la api de jellyfin_dart

- Debes utilizar metodos de la api del paquete jellyfin_dart con funciones para obtener datos de la api de Jellyfin cuando se pueda, para agilizar las llamadas a la api, y la obtencion de datos

## Nunca hagas checkout de una version anterior sin preguntarme

- No quiero que vuelvas a una version anterior de codigo de Github haciendo checkout sin preguntarme antes. Podriamos romper algo que ya funciona

## Corrige los problemas siempre que puedas antes de tu respuesta final

- Debes corregir los problemas de consola siempre que puedas antes de dar tu respuesta final

## No tocar elementos corregidos a mano por el usuario

- No corregir la posicion de PrimeCardBadge, dejar tal y como está en las tarjetas posicionada, y no tocar otras cosas que yo toque a mano, en respuestas sucesivas a mi modificacion, y si es necesario hacerlo, preguntame antes.

## No hagas tests si no te lo pido

- No ejecutes, ni escribas ningun test, si el usuario no lo pide por prompt

## Documentos de feature (FTD / RSC)

- Por cada feature o fix que hagas, genera y mantén un documento en `02-DOCS/wiki/ftd/<slug>.md` con este formato exacto: `Intent`, `Scope`, `Checklist`, `Evidence`, `Next`.
- Escríbelo **antes del primer cambio**, márcalo solo con prueba observada (`flutter analyze`, salida de comando, render) y deja en `Next` el siguiente paso, para que una interrupción no cueste nada.
- Aplica de ahora en adelante a todo cambio, sin excepción.


<!-- rsc-suggest:start -->

# rsc-suggest — the always-on layer

Your body is injected at the start of **every** session and again after every compaction, so you
are the one piece guaranteed to be present before any other skill is matched. Two jobs, in order:

1. **Classify every turn into one of three lanes** before anything is written.
2. **Keep the session equipped** — spot the skill the task needs but the user does not have.

Everything below is what only this layer can do. The method behind each rule lives in the skill that
owns it; this is the pointer, not the manual.

---

## 1. The decisor: classify the turn before acting

Every turn takes one of three lanes, and you name the one you took in a line.

**Answer** — the request asks for information: explain, compare, investigate, audit, review,
recommend. Read-only: write nothing, create no artifact, delegate no writer. Asking you to *think
about* building something is still this lane; only asking to build authorises it. When change
intent is ambiguous, ask one question and stay here — ambiguity slows the lane, never raises it.

**FTD — Fast-Track Development** — the request authorises a change. The default for ordinary work,
entered without ceremony. One feature document per feature in `02-DOCS`: intent, scope, checklist,
evidence, next step. Tasks are checked off against observed proof, never intention. A branch if it
writes code, none if it only touches docs, wiki or config; never a worktree. → `../ftd/SKILL.md`.

**SDD** — the ten-phase chain, unchanged, and **never entered by the harness alone**. Propose it only
when durable spec/plan/tasks would remove a *substantial* ambiguity — a test of usefulness, not of
size — and enter it only on explicit request or an accepted proposal. Size, file count and perceived
risk never select it. → `../sdd/SKILL.md`.

Judge the **meaning**, not the wording: the trigger is semantic in any language. A bug fix restoring
intended behaviour is `debug`. Autopilot consent covers a whole run — advance without re-asking.

Lane's skill missing? Offer it (§2) first. SDD recorded as deferred in `.rsc.json`? Run
`npx @ericrisco/rsc@latest reassess`; silent on `RSC_REASSESSMENT_NO_CHANGE`, and on new evidence
show the plan command — SDD still needs a newly accepted plan id, never added silently.

---

## 2. Keeping the session equipped

When the task needs a capability the user has **not installed** — building, creating, automating,
analyzing, connecting, shipping, securing, selling, teaching, governing or documenting something —
name it and offer it. This runs mid-conversation, not only at project start.

1. `npx @ericrisco/rsc catalog --available` lists every not-installed skill as
   `id  available  short description`.
2. Pick the single best fit **by meaning**, the way you would match a request to a teammate's
   expertise — "mandar emails de bienvenida" → an email/outreach skill, though not one keyword
   overlaps. If nothing genuinely fits, say so
   and move on: a tangential suggestion is worse than none.
3. Ask once, plainly: "Para esto instalaría `<id>`, que aún no tienes. ¿La instalo? (sí/no)".
4. On yes, run `npx @ericrisco/rsc add <id>`, then continue the original task.

Installing changes the user's environment, so it is always their call. One suggestion at a time,
and never to interrupt a flow with a nice-to-have. Never recommend something already installed
(`npx @ericrisco/rsc list`).

`npx @ericrisco/rsc consult "<task>"` is a **lexical** hint only: it keyword-matches, and returns
nothing for natural-language or non-English intent. Never let it decide, and never read its silence
as "no skill exists" — the catalog plus your judgment is the source of truth.

### Automation gap — after the work

Delivered work a repeatable **procedure**? Before proposing to *build* anything, run
`npx @ericrisco/rsc capabilities`: covered by a skill or agent → use it, say nothing.
Not covered → one line, skill or agent. Rules: `skill-scout`.

---

## 3. A harness that is broken fixes itself

You are injected into every session, so you are the only thing that can notice a broken
harness before its owner does — and its owner usually cannot, because the symptoms name
nothing they recognise. When any of these is true, act on it **once** in the session:

- `.rsc.json` exists and what it declares is not what is installed;
- the same hook seems to run several times;
- the harness is wired for an assistant that is not the one running.

Run `npx @ericrisco/rsc doctor`, and say in one line what is wrong **as a symptom**, not as
a cause. Then:

- **Nothing built** — `.rsc.json` without `.rsc/`: a clone. Name
  `npx @ericrisco/rsc@<catalogVersion in .rsc.json> sync`, that exact version, **never** `@latest`
  — a release nobody here adopted is drift. Ask in one line, **keep working either way**; silence
  is not a no, `.rsc/.no-harness` is.
- Anything that only puts the harness back to what was already declared — dangling links, a
  repeated hook, a layout no version uses — say you are fixing it and run
  `npx @ericrisco/rsc repair`. Restoring is not deciding, and a recoverable copy is kept.
- Anything that would change a decision — moving to another assistant, adopting a skill a
  teammate added, disarming a gate — **ask first**. A `git pull` never rewrites someone's
  machine.

Offer once per session. Never mention any of it when the harness is healthy.

## 4. First contact

Before handling the first request of a session, check the workspace:

- No `02-DOCS/wiki/harness/user-profile.md` **and** no `.rsc/.no-harness` → the harness has never
  been set up here. Invoke `init` first; it opens with the two gauging questions (technical level +
  accompaniment dial). Do not start the user's task before first contact is done.
- The user declines a harness here ("sin harness", "solo código") → create an empty
  `.rsc/.no-harness`, confirm in one line, and never auto-start `init` in this repo again.
- Once the profile exists, this gate is inert. Never re-onboard.

## Explain without assuming

Define a term at first use; never give a command, flag or path without saying what it does.

## Orientación (siempre)

Cierra cada turno con el **bloque-brújula** (📍 dónde estás · ✅ qué hiciste · 🧭 por qué · ➡️ siguiente,
terminando en pregunta), calibrado al dial de `02-DOCS/wiki/harness/user-profile.md`. Nunca termines
en seco. Protocolo completo: skill `orient` → `skills/orient/references/orientation-contract.md`.
(Defiere a este mismo cuerpo, §2, el "¿instalo la skill que falta?".)

<!-- rsc-suggest:end -->
