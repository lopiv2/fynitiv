import 'dart:async';

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/app_loader.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/romm_providers.dart';
import '../../domain/game_ost_track.dart';

/// Corazón de favorita de pista OST compartido (detalle de juego y Jukebox).
///
/// Sin `romFileId` válido (`<= 0`) no se muestra nada. Gestiona su propio
/// estado con optimistic update contra `POST`/`DELETE /api/music/favorites`:
/// `AppLoader` mientras la petición DIO vuela y `EasyLoading` al resolver.
class OstFavoriteButton extends ConsumerStatefulWidget {
  const OstFavoriteButton({
    super.key,
    required this.track,
    this.accent = const Color(0xFF8B7CF6),
    this.size = 18,
  });

  final GameOstTrack track;
  final Color accent;
  final double size;

  @override
  ConsumerState<OstFavoriteButton> createState() => _OstFavoriteButtonState();
}

class _OstFavoriteButtonState extends ConsumerState<OstFavoriteButton> {
  late bool _isFav;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _isFav = widget.track.isFavorite;
  }

  @override
  void didUpdateWidget(covariant OstFavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sincroniza el valor del servidor (recarga del provider) sin pisar
    // un toggle en vuelo.
    if (!_busy && widget.track.isFavorite != _isFav) {
      _isFav = widget.track.isFavorite;
    }
  }

  Future<void> _toggle() async {
    final id = widget.track.romFileId;
    if (id <= 0 || _busy) return;
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) return;
    final l10n = AppLocalizations.of(context)!;
    final target = !_isFav;
    setState(() {
      _busy = true;
      _isFav = target;
    });
    try {
      if (target) {
        await repo.addMusicFavorites([id]);
        unawaited(
          EasyLoading.showSuccess(
            l10n.ostFavoriteAdded,
            dismissOnTap: true,
            maskType: EasyLoadingMaskType.none,
          ),
        );
      } else {
        await repo.removeMusicFavorites([id]);
        unawaited(
          EasyLoading.showSuccess(
            l10n.ostFavoriteRemoved,
            dismissOnTap: true,
            maskType: EasyLoadingMaskType.none,
          ),
        );
      }
    } catch (_) {
      // Revierte el optimistic update para no mentir en la UI.
      if (mounted) setState(() => _isFav = !target);
      unawaited(
        EasyLoading.showError(
          l10n.ostFavoriteError,
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
    if (widget.track.romFileId <= 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: AppLoader(size: 16, color: Colors.white54),
      );
    }
    return IconButton(
      tooltip: _isFav ? l10n.removeFromFavorites : l10n.addToFavorites,
      focusColor: Colors.white.withValues(alpha: 0.08),
      highlightColor: Colors.white.withValues(alpha: 0.06),
      onPressed: () => unawaited(_toggle()),
      icon: Icon(
        _isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: _isFav ? widget.accent : Colors.white54,
        size: widget.size,
      ),
    );
  }
}
