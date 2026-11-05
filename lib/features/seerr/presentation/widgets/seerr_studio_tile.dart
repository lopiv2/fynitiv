import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/logo_image.dart';
import '../../application/seerr_studios_providers.dart';

/// Tarjeta de un estudio: logo a sangre si tiene fondo propio, o logo sobre
/// degradado con panel glassmorphism si es transparente.
class SeerrStudioTile extends StatelessWidget {
  const SeerrStudioTile({super.key, required this.studio});

  final SeerrStudioEntry studio;

  @override
  Widget build(BuildContext context) {
    final logo = studio.logo?.trim() ?? '';
    final gradient = studio.gradient.length >= 2
        ? LinearGradient(
            colors: studio.gradient.take(2).toList(),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    // Logos con fondo propio: ocupan toda la tarjeta.
    if (studio.fillCard && logo.isNotEmpty) {
      return LogoImage(logo: logo, fit: BoxFit.cover);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 200.0;
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 120.0;
        // Logos más grandes: ~55 % del alto de la tarjeta (mín. 48 px).
        final logoHeight = (maxH * 0.55).clamp(48.0, 110.0).toDouble();
        final pad = (maxH * 0.08).clamp(6.0, 14.0).toDouble();
        final radius = (maxH * 0.12).clamp(12.0, 22.0).toDouble();
        final panelWidth = maxW * 0.84;
        return DecoratedBox(
          decoration: BoxDecoration(gradient: gradient),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topLeft,
                    radius: 1.2,
                    colors: [Color(0x33FFFFFF), Color(0x00000000)],
                  ),
                ),
              ),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: panelWidth,
                      padding: EdgeInsets.symmetric(
                        horizontal: pad,
                        vertical: pad * 0.7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(radius),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: logo.isEmpty
                          ? Text(
                              studio.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF111111),
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            )
                          : LogoImage(
                              logo: logo,
                              height: logoHeight,
                              width: double.infinity,
                              fit: BoxFit.contain,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
