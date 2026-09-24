import 'dart:async';

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/app_loader.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/romm_providers.dart';
import '../../domain/romm_game.dart';

/// Verde invader clásico para el rating geek.
const _invaderAccent = Color(0xFF39FF6A);

/// Cangrejo invader clásico, matriz 11×8 (`X` = píxel).
const _invaderMatrix = <String>[
  '..X.....X..',
  '...X...X...',
  '..XXXXXXX..',
  '.XX.XXX.XX.',
  'XXXXXXXXXXX',
  'X.XXXXXXX.X',
  'X.X.....X.X',
  '...XX.XX...',
];

/// Nota media de la comunidad con invaders (`_GameHeroInfo`, fila de stats).
/// Sin media (`average == null`): guion como el resto de stats vacíos.
class GameCommunityRating extends StatelessWidget {
  const GameCommunityRating({super.key, required this.average});

  /// Media normalizada a 0–10 o null si ROMM no la trae.
  final double? average;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final avg = average;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.gameRatingCommunity,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 3),
        if (avg == null)
          const Text(
            '—',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: EdgeInsets.only(right: i < 4 ? 3 : 0),
                  child: GameInvaderIcon(
                    fill: (avg / 2 - i).clamp(0, 1).toDouble(),
                    size: 18,
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                avg.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Voto personal del usuario con invaders pulsables (1–5 = 2–10 en ROMM).
/// Repulsar la nota actual la borra (0 = sin votar). Guarda con
/// `PUT /api/roms/{id}/props` y refresca `rommGameProvider` al acertar.
class GameUserRating extends ConsumerStatefulWidget {
  const GameUserRating({super.key, required this.game});

  final RommGame game;

  @override
  ConsumerState<GameUserRating> createState() => _GameUserRatingState();
}

class _GameUserRatingState extends ConsumerState<GameUserRating> {
  late int _rating;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.game.userRating;
  }

  @override
  void didUpdateWidget(covariant GameUserRating oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sincroniza el valor del servidor (p. ej. tras invalidar el provider
    // al votar) sin pisar un voto en vuelo.
    if (!_busy && widget.game.userRating != _rating) {
      _rating = widget.game.userRating;
    }
  }

  Future<void> _vote(int stars) async {
    if (_busy) return;
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) return;
    // Toggle-off: repulsar la nota actual la quita.
    final target = stars * 2 == _rating ? 0 : stars * 2;
    final previous = _rating;
    setState(() {
      _busy = true;
      _rating = target;
    });
    try {
      await repo.setUserRating(widget.game.id, target);
      ref.invalidate(rommGameProvider(widget.game.id));
    } catch (_) {
      if (mounted) setState(() => _rating = previous);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      unawaited(
        EasyLoading.showError(
          l10n.gameRatingError,
          dismissOnTap: true,
          maskType: EasyLoadingMaskType.none,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.gameRatingYours,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 5; i++)
              IconButton(
                tooltip: '${i + 1}/5',
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(),
                focusColor: Colors.white.withValues(alpha: 0.08),
                highlightColor: Colors.white.withValues(alpha: 0.06),
                onPressed: _busy ? null : () => unawaited(_vote(i + 1)),
                icon: GameInvaderIcon(
                  fill: ((_rating - i * 2) / 2).clamp(0, 1).toDouble(),
                  size: 20,
                ),
              ),
            if (_busy) ...[
              const SizedBox(width: 6),
              const AppLoader(size: 14, color: Colors.white54),
            ],
          ],
        ),
        if (_rating == 0 && !_busy)
          Text(
            l10n.gameRatingUnrated,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
      ],
    );
  }
}

/// Marcianito invader con relleno parcial por columnas ([fill] 0–1).
class GameInvaderIcon extends StatelessWidget {
  const GameInvaderIcon({
    super.key,
    required this.fill,
    this.size = 20,
    this.color = _invaderAccent,
    this.emptyColor = const Color(0x33FFFFFF),
  });

  final double fill;
  final double size;
  final Color color;
  final Color emptyColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 8 / 11,
      child: CustomPaint(
        painter: _InvaderPainter(
          fill: fill.clamp(0, 1),
          color: color,
          emptyColor: emptyColor,
        ),
      ),
    );
  }
}

class _InvaderPainter extends CustomPainter {
  const _InvaderPainter({
    required this.fill,
    required this.color,
    required this.emptyColor,
  });

  final double fill;
  final Color color;
  final Color emptyColor;

  @override
  void paint(Canvas canvas, Size size) {
    final px = size.width / 11 < size.height / 8
        ? size.width / 11
        : size.height / 8;
    final ox = (size.width - px * 11) / 2;
    final oy = (size.height - px * 8) / 2;
    final threshold = fill * 11;
    for (var r = 0; r < 8; r++) {
      final row = _invaderMatrix[r];
      for (var c = 0; c < 11; c++) {
        if (row[c] != 'X') continue;
        canvas.drawRect(
          Rect.fromLTWH(ox + c * px, oy + r * px, px, px),
          Paint()..color = c < threshold ? color : emptyColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _InvaderPainter old) {
    return old.fill != fill || old.color != color || old.emptyColor != emptyColor;
  }
}
