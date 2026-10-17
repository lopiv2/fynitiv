# Intent
Los logos de plataformas (TMDB) que aparecen abajo a la derecha de las carátulas (`ProviderLogoStrip`, usado por `PosterCard` y `BackdropCard`) se veían pequeños. Se pide un poco más grandes.

# Scope
- Solo `lib/core/widgets/provider_logo_strip.dart`: alto/ancho por logo por defecto 20 → 26 px (mismo valor para ambos ejes, `BoxFit.contain`). Documentado el parámetro `height`.
- Ningún llamante pasaba `height`, así que ambos tipos de tarjeta (póster y backdrop) heredan el nuevo tamaño sin cambios.
- Sin ARB. Sin tocar `PrimeCardBadge`.

# Checklist
- [x] FTD creado antes del primer cambio
- [x] Tamaño por defecto 20 → 26 en `ProviderLogoStrip`
- [x] `flutter analyze` limpio

# Evidence
- `flutter analyze` (17/10/2026, proyecto completo): `No issues found!`.
- Sin `flutter build` como verificación (norma del proyecto); sin tests (no pedidos).

# Next
- Ajustar el valor si el usuario lo quiere mayor/menor (una sola constante).
