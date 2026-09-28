# Intent
Dejar `flutter analyze` en cero avisos: los únicos 2 `info` (`deprecated_member_use` en `lib/l10n/app_localizations.dart:90-91`) vienen del código generado por `gen-l10n`, que aún emite `GlobalMaterial/CupertinoLocalizations` de `flutter_localizations` (deprecados desde Flutter 3.47 en favor de `material_ui`/`cupertino_ui`).

# Scope
- Solo `analysis_options.yaml`: excluir los dart generados `lib/l10n/app_localizations*.dart`.
- No se tocan los `.arb` ni los dart generados a mano (norma del proyecto: las traducciones se autogeneran).
- No se toca `lib/app.dart`: ya usa los delegates de `material_ui` (`GlobalMaterialLocalizations.delegates`), sin avisos.
- No se ejecuta `flutter build`; verificación con `flutter analyze`.

# Checklist
- [x] Diagnosticar: los 2 infos están en archivo generado por `gen-l10n` (plantilla aún no migrada en Flutter master 3.49); `app.dart` limpio
- [x] Añadir exclude de `lib/l10n/app_localizations*.dart` en `analysis_options.yaml`
- [x] `flutter analyze` → `No issues found!`

# Evidence
- `flutter analyze --no-pub` (28/09/2026): `No issues found! (ran in 5.8s)`. Antes: 2 `info` `deprecated_member_use` en `lib/l10n/app_localizations.dart:90-91`.

# Next
- Cuando la plantilla `gen-l10n` de Flutter emita los delegates de `material_ui`/`cupertino_ui`, retirar el exclude. Alternativa descartada: editar el dart generado a mano (se sobrescribe al regenerar).
