import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/ui_constants.dart';
import '../../../../core/utils/format_bytes.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/download_task.dart';
import '../application/download_manager_provider.dart';

String _fmt(Duration d) {
  String two(int v) => v.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Altura base de cada fila de descarga (escalada por plataforma como
/// el miniplayer). `home_shell` la usa para elevar el FAB.
const double kDownloadRowHeightBase = 64;

double downloadRowHeight(double s) =>
    (kDownloadRowHeightBase * s).clamp(64, 110).toDouble();

/// Gestor de descargas estilo Steam: barra inferior con una fila por
/// descarga activa (progreso, velocidad, tiempo restante, pausar/
/// reanudar/cancelar). Se apila DEBAJO del [MiniPlayerBar] en el shell.
class DownloadManagerBar extends ConsumerWidget {
  const DownloadManagerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadManagerProvider).values.toList();
    if (tasks.isEmpty) return const SizedBox.shrink();
    final s = ref.watch(miniPlayerScaleProvider);
    final rowH = downloadRowHeight(s);
    return Material(
      color: const Color(0xFF0F0F0F),
      elevation: 8,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final task in tasks)
              SizedBox(
                height: rowH,
                child: _DownloadRow(task: task, scale: s),
              ),
          ],
        ),
      ),
    );
  }
}

class _DownloadRow extends ConsumerWidget {
  const _DownloadRow({required this.task, required this.scale});

  final DownloadTask task;
  final double scale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final manager = ref.read(downloadManagerProvider.notifier);
    final s = scale;
    final padH = 12 * s;
    final gap = 10 * s;
    final iconSize = 22 * s;
    final titleFs = 13 * s;
    final statsFs = 11 * s;

    final (statusText, statusColor) = switch (task.status) {
      DownloadStatus.downloading =>
        ('${(task.progress * 100).toStringAsFixed(0)} %', Colors.white),
      DownloadStatus.queued => (l10n.downloadQueued, Colors.white70),
      DownloadStatus.paused => (l10n.downloadPaused, Colors.orangeAccent),
      DownloadStatus.error => (l10n.downloadFailed, Colors.redAccent),
      DownloadStatus.completed => (l10n.gamesDownloaded, Colors.greenAccent),
    };

    final eta = task.eta;
    final statsParts = <String>[
      if (task.totalBytes > 0)
        l10n.downloadOf(
          formatBytes(task.receivedBytes),
          formatBytes(task.totalBytes),
        )
      else if (task.receivedBytes > 0)
        formatBytes(task.receivedBytes),
      if (task.status == DownloadStatus.downloading && task.speedBps > 0)
        '${formatBytes(task.speedBps.round())}/s',
      if (eta != null && task.status == DownloadStatus.downloading)
        l10n.downloadTimeLeft(_fmt(eta)),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: 6 * s),
      child: Row(
        children: [
          Tooltip(
            message: task.status == DownloadStatus.error
                ? (task.error ?? '')
                : task.fileName,
            child: Icon(
              task.status == DownloadStatus.completed
                  ? Icons.check_circle_outline
                  : task.status == DownloadStatus.error
                      ? Icons.error_outline
                      : Icons.download_rounded,
              size: iconSize,
              color: statusColor,
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.sourceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: titleFs,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: gap),
                    Text(
                      statusText,
                      style: TextStyle(fontSize: statsFs, color: statusColor),
                    ),
                  ],
                ),
                SizedBox(height: 4 * s),
                if (task.status == DownloadStatus.downloading ||
                    task.status == DownloadStatus.paused)
                  LinearProgressIndicator(
                    value: task.totalBytes > 0 ? task.progress : null,
                    minHeight: (4 * s).clamp(3, 6).toDouble(),
                    backgroundColor: const Color(0xFF2A2A2A),
                  )
                else
                  SizedBox(height: (4 * s).clamp(3, 6).toDouble()),
                SizedBox(height: 3 * s),
                Text(
                  statsParts.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: statsFs, color: Colors.white60),
                ),
              ],
            ),
          ),
          SizedBox(width: gap),
          ..._actions(l10n, manager, iconSize),
        ],
      ),
    );
  }

  List<Widget> _actions(
    AppLocalizations l10n,
    DownloadManagerController manager,
    double iconSize,
  ) {
    switch (task.status) {
      case DownloadStatus.downloading:
      case DownloadStatus.queued:
        return [
          IconButton(
            tooltip: l10n.pause,
            iconSize: iconSize,
            onPressed: () => manager.pause(task.id),
            icon: const Icon(Icons.pause_rounded),
          ),
          IconButton(
            tooltip: l10n.downloadCancel,
            iconSize: iconSize,
            onPressed: () => manager.cancel(task.id),
            icon: const Icon(Icons.close_rounded),
          ),
        ];
      case DownloadStatus.paused:
        return [
          IconButton(
            tooltip: l10n.downloadResume,
            iconSize: iconSize,
            onPressed: () => manager.resume(task.id),
            icon: const Icon(Icons.play_arrow_rounded),
          ),
          IconButton(
            tooltip: l10n.downloadCancel,
            iconSize: iconSize,
            onPressed: () => manager.cancel(task.id),
            icon: const Icon(Icons.close_rounded),
          ),
        ];
      case DownloadStatus.error:
        return [
          IconButton(
            tooltip: l10n.retry,
            iconSize: iconSize,
            onPressed: () => manager.resume(task.id),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: l10n.downloadCancel,
            iconSize: iconSize,
            onPressed: () => manager.cancel(task.id),
            icon: const Icon(Icons.close_rounded),
          ),
        ];
      case DownloadStatus.completed:
        return [
          IconButton(
            tooltip: l10n.downloadDismiss,
            iconSize: iconSize,
            onPressed: () => manager.cancel(task.id),
            icon: const Icon(Icons.close_rounded),
          ),
        ];
    }
  }
}
