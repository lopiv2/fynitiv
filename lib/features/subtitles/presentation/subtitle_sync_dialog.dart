import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/subtitle_cues.dart';

const double _kItemExtent = 66;

/// Abre el diálogo de sincronía por texto y devuelve el inicio de la línea
/// elegida (o `null` si se cancela).
Future<Duration?> showSubtitleSyncDialog(
  BuildContext context, {
  required List<SubtitleCue> cues,
  required Duration currentPosition,
}) {
  return showDialog<Duration>(
    context: context,
    barrierColor: Colors.black45,
    builder: (_) =>
        SubtitleSyncDialog(cues: cues, currentPosition: currentPosition),
  );
}

/// Diálogo transparente con las líneas del subtítulo para elegir la que suena.
class SubtitleSyncDialog extends StatefulWidget {
  const SubtitleSyncDialog({
    super.key,
    required this.cues,
    required this.currentPosition,
  });

  final List<SubtitleCue> cues;
  final Duration currentPosition;

  @override
  State<SubtitleSyncDialog> createState() => _SubtitleSyncDialogState();
}

class _SubtitleSyncDialogState extends State<SubtitleSyncDialog> {
  late final ScrollController _controller;
  late final SubtitleCue? _currentCue;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _currentCue = _findCurrentCue();
    final index = _currentCue == null
        ? 0
        : widget.cues.indexOf(_currentCue);
    final offset = ((index - 3).clamp(0, widget.cues.length) * _kItemExtent)
        .toDouble();
    _controller = ScrollController(initialScrollOffset: offset);
  }

  SubtitleCue? _findCurrentCue() {
    SubtitleCue? current;
    for (final cue in widget.cues) {
      if (cue.start <= widget.currentPosition) {
        current = cue;
      } else {
        break;
      }
    }
    return current;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<SubtitleCue> get _visible {
    final query = _filter.trim().toLowerCase();
    if (query.isEmpty) return widget.cues;
    return widget.cues
        .where((cue) => cue.text.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visible = _visible;
    return Dialog(
      backgroundColor: const Color(0xE6141414),
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.sync_alt, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.subtitleSyncPickLine,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.cancel,
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text(
                l10n.subtitleSyncHint,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: (value) {
                  setState(() => _filter = value);
                  if (_controller.hasClients) _controller.jumpTo(0);
                },
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.subtitleFilterHint,
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.white54,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: Colors.white24, height: 1),
              Flexible(
                child: visible.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 44),
                        child: Text(
                          l10n.noSubtitles,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.builder(
                        controller: _controller,
                        itemExtent: _kItemExtent,
                        itemCount: visible.length,
                        itemBuilder: (context, i) {
                          final cue = visible[i];
                          final isCurrent = identical(cue, _currentCue);
                          return _CueTile(
                            cue: cue,
                            selected: isCurrent,
                            autofocus: isCurrent,
                            onTap: () =>
                                Navigator.of(context).pop(cue.start),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CueTile extends StatelessWidget {
  const _CueTile({
    required this.cue,
    required this.selected,
    required this.autofocus,
    required this.onTap,
  });

  final SubtitleCue cue;
  final bool selected;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: selected ? const Color(0x33FFFFFF) : Colors.transparent,
      child: InkWell(
        autofocus: autofocus,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  _formatCueTime(cue.start),
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white54,
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cue.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatCueTime(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
