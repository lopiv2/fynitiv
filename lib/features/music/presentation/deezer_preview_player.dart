import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';

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

  @override
  void initState() {
    super.initState();
    _player = Player();
    _player.stream.playing.listen((v) { if (mounted) setState(() => _playing = v); });
    _player.open(Media(widget.track.preview));
    _player.play();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.track;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop())),
      body: Center(
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
            const SizedBox(height: 12),
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
    );
  }
}
