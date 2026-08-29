import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';

import '../../../l10n/app_localizations.dart';
import '../application/deezer_providers.dart';

class DeezerPreviewPlayerScreen extends ConsumerStatefulWidget {
  const DeezerPreviewPlayerScreen({super.key, required this.track});
  final DeezerTrack track;

  @override
  ConsumerState<DeezerPreviewPlayerScreen> createState() => _DeezerPreviewPlayerScreenState();
}

class _DeezerPreviewPlayerScreenState extends ConsumerState<DeezerPreviewPlayerScreen> {
  late final Player _player;
  bool _playing = false;
  double _volume = 40; // volumen inicial más bajo: el preview sonaba muy alto a 100
  double _previousVolume = 40;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<double>? _volumeSub;

  IconData _iconFor(double v) {
    if (v <= 0) return Icons.volume_off_rounded;
    if (v < 50) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  @override
  void initState() {
    super.initState();
    _player = Player();
    // Baja el volumen antes de reproducir para que no suene alto al entrar
    _player.setVolume(_volume);
    _playingSub = _player.stream.playing.listen((v) {
      if (mounted) setState(() => _playing = v);
    });
    _volumeSub = _player.stream.volume.listen((v) {
      if (mounted) setState(() => _volume = v);
    });
    _player.open(Media(widget.track.preview));
    _player.play();
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    _volumeSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _setVolume(double v) {
    final clamped = v.clamp(0, 100).toDouble();
    setState(() {
      _volume = clamped;
      if (clamped > 0) _previousVolume = clamped;
    });
    _player.setVolume(clamped);
  }

  void _toggleMute() {
    if (_volume > 0) {
      _previousVolume = _volume;
      _setVolume(0);
    } else {
      _setVolume(_previousVolume > 0 ? _previousVolume : 40);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.track;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop())),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 280,
                  height: 280,
                  child: t.cover.isNotEmpty ? Image.network(t.cover, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: Colors.white12)) : Container(color: Colors.white12),
                ),
              ),
              const SizedBox(height: 24),
              Text(t.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
              Text(t.artistName, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 24),
              IconButton(
                iconSize: 64,
                icon: Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white),
                onPressed: () => _playing ? _player.pause() : _player.play(),
              ),
              const SizedBox(height: 8),
              // Control de volumen
              Container(
                constraints: const BoxConstraints(maxWidth: 360),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l10n.volume,
                      icon: Icon(_iconFor(_volume), color: Colors.white),
                      onPressed: _toggleMute,
                    ),
                    Expanded(
                      child: Slider(
                        value: _volume.clamp(0, 100).toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label: '${_volume.round()}%',
                        activeColor: Colors.white,
                        inactiveColor: Colors.white24,
                        thumbColor: Colors.white,
                        onChanged: _setVolume,
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${_volume.round()}%',
                        textAlign: TextAlign.end,
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Preview 30s • Deezer', style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 12),
              // Logo abajo a la derecha indicativo
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/logo_deezer.png', height: 18, errorBuilder: (_, _, _) => const Text('Deezer', style: TextStyle(color: Colors.white38, fontSize: 10))),
                  const SizedBox(width: 6),
                  const Text('Deezer', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
