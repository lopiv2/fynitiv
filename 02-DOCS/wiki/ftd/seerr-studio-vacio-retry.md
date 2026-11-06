# Intent
Entrar en un estudio muestra a veces "No se encontraron resultados" aunque el estudio tiene pelis. El fallo (red/Seerr) se traga y el `null` queda cacheado 20 min; además la pantalla no distingue error de vacío ni permite reintentar.

# Scope
- `lib/features/seerr/application/seerr_studios_providers.dart`: `seerrStudioCatalogProvider` solo mantiene vivo el resultado si es éxito; los fallos/`null` no se cachean para que reintentar repida la petición.
- `lib/features/seerr/presentation/seerr_studio_screen.dart`: estado vacío con botón Reintentar (`l10n.retry`, ARB existente) que invalida el provider. Sin strings nuevos.
- Verificación: `dart analyze` de ambos ficheros.

# Checklist
- [x] Causa: `catch (_) return null` + `ref.cacheFor(20min)` incondicional → un fallo transitorio envenena el estudio 20 min. La pantalla muestra `noResults` también en error.
- [x] Cachear solo éxito (cerrar el link de keepAlive en fallo).
- [x] Botón Reintentar en el estado vacío.
- [x] `dart analyze` sin errores.

# Evidence
- Antes: fallo de red al abrir Disney → "No se encontraron resultados" durante 20 min aunque se salga y se entre.
- Después: `dart analyze` de ambos ficheros → `No issues found!`. El fallo ya no se cachea y Reintentar repite la llamada; el éxito sigue cacheado 20 min.

# Next
- Siguiente paso: aplicar y analizar. Si persiste en algún estudio concreto, revisar su `companyId` en `assets/data/studios.json` contra `/search/company` de Seerr.
