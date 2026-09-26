import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/skin/skin_controller.dart';
import '../../../../core/widgets/app_hover.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../music/application/soloud_music_provider.dart';

/// Tarjeta Jukebox reutilizable con `AppHover` universal y dot LED
/// persistente cuando hay música sonando.
///
/// Reutiliza el lenguaje visual de `_PlatformCard` (glassmorphism +
/// `scaleHighlightOutlineLed`) pero con tamaño ajustado y un LED de
/// esquina que sobrevive sin hover/focus — imprescindible en TV a
/// distancia de sofá (D-Pad).
class JukeboxEntryCard extends ConsumerWidget {
  const JukeboxEntryCard({
    super.key,
    this.heroTag,
    this.size,
    this.dotSize = 10,
    this.showLed = true,
  });

  /// Tag hero opcional (no se usa por defecto en Jukebox).
  final String? heroTag;

  /// Tamaño cuadrado opcional para uso fuera de grid. Si es null,
  /// la tarjeta expande al espacio del grid (comportamiento previo).
  final double? size;

  /// Diámetro del dot LED y si se muestra (lógica LED ya integrada).
  final double dotSize;
  final bool showLed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final skin = ref.watch(skinControllerProvider).value;
    final accent = skin?.accent ?? const Color(0xFF2B7FFF);
    final textPrimary = skin?.textPrimary ?? Colors.white;
    final textSecondary = skin?.textSecondary ?? Colors.white70;

    // Estado de música: dot visible cuando hay pista sonando.
    final soloudState = ref.watch(soloudMusicProvider);
    final isPlaying =
        soloudState.hasItem && soloudState.playing && !soloudState.completed;

    final isLedVisible = showLed && isPlaying;
    final cardChild = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header compacto: icono + título
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(
                        Icons.library_music_rounded,
                        color: accent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n.jukeboxTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Centro: icono grande (mismo lenguaje que máquina en plataforma)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(10, 2, 10, 6),
                  child: Center(
                    child: Icon(
                      Icons.queue_music_rounded,
                      color: Colors.white.withValues(alpha: 0.85),
                      size: 48,
                    ),
                  ),
                ),
              ),
              // Footer: badge + chevron
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        l10n.jukeboxOpen,
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: textSecondary.withValues(alpha: 0.6),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Dot LED persistente (sin hover) — esquina superior derecha.
          // Lógica integrada: visible solo al sonar.
          if (isLedVisible)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: const Color(0xFF3EE07F),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3EE07F).withValues(alpha: 0.65),
                      blurRadius: 8,
                      spreadRadius: 1.2,
                    ),
                    BoxShadow(
                      color: const Color(0xFF3EE07F).withValues(alpha: 0.28),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    final glassCard = RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: cardChild,
        ),
      ),
    );

    const solidHover = Color(0xFF1E2633);
    final hover = AppHover(
      effect: AppHoverEffect.scaleHighlightOutlineLed,
      config: AppHoverConfig.scaleHighlightOutlineLed(
        scale: 1.04,
        radius: BorderRadius.circular(16),
        duration: const Duration(milliseconds: 180),
        outlineHoveredWidth: 1.8,
        outlineHoveredColor: accent,
        ledHoveredColor: accent,
        ledBlurRadius: 22,
        ledSpreadRadius: 2,
        highlightNormal: Colors.transparent,
        highlightHovered: solidHover,
      ),
      onTap: () => context.push('/games/jukebox'),
      playSoundOnHover: true,
      child: glassCard,
    );
    if (size != null) {
      return SizedBox(width: size, height: size, child: hover);
    }
    return hover;
  }
}

/// Botón Jukebox compacto para header (mismo lenguaje, reutilizable).
/// `size` = lado del cuadrado (38 por defecto), `dotSize` = diámetro LED.
/// LED integrado: visible solo al sonar, en `Stack` externo para no
/// recortarse con el `ClipRRect` de `AppHover`.
class JukeboxHeaderButton extends ConsumerWidget {
  const JukeboxHeaderButton({
    super.key,
    this.size = 38,
    this.dotSize = 10,
    this.showLed = true,
  });

  /// Lado del botón cuadrado.
  final double size;

  /// Diámetro del dot LED.
  final double dotSize;

  /// Si false, nunca muestra LED aunque suene (útil para previews).
  final bool showLed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final skin = ref.watch(skinControllerProvider).value;
    final accent = skin?.accent ?? const Color(0xFF2B7FFF);
    final soloud = ref.watch(soloudMusicProvider);
    final isPlaying = soloud.hasItem && soloud.playing && !soloud.completed;
    final isLedVisible = showLed && isPlaying;

    final iconBox = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(size * 0.26),
        border: Border.all(color: Colors.white12),
      ),
      child: Icon(
        Icons.library_music_rounded,
        color: Colors.white70,
        size: size * 0.47,
      ),
    );

    // Nodo propio para el ancla del Tooltip: sin él, la config del ancla se
    // fusiona con las tarjetas vecinas en el scrollable y el bridge de
    // accesibilidad de Windows rechaza el update en cada hover
    // (`Failed to update ui::AXTree ... will not be in the tree`, bug
    // upstream flutter/flutter#182444). Solo agrupa, no cambia nada visual.
    return Semantics(
      container: true,
      child: Tooltip(
        message: l10n.jukeboxOpen,
        child: Stack(
        clipBehavior: Clip.none,
        children: [
          AppHover(
            effect: AppHoverEffect.scaleHighlightOutlineLed,
            config: AppHoverConfig.scaleHighlightOutlineLed(
              scale: 1.06,
              radius: BorderRadius.circular(size * 0.26),
              duration: const Duration(milliseconds: 180),
              outlineHoveredWidth: 1.5,
              outlineHoveredColor: accent,
              ledHoveredColor: accent,
              ledBlurRadius: 16,
              ledSpreadRadius: 1.4,
              highlightNormal: Colors.transparent,
              highlightHovered: const Color(0xFF1E2633),
            ),
            onTap: () => context.push('/games/jukebox'),
            playSoundOnHover: false,
            child: iconBox,
          ),
          if (isLedVisible)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: const Color(0xFF3EE07F),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3EE07F).withValues(alpha: 0.65),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: const Color(0xFF3EE07F).withValues(alpha: 0.28),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
