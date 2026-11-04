import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/navigation/platform_mode.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../settings/presentation/widgets/settings_metrics.dart';
import '../application/nerd_stats_provider.dart';
import '../domain/nerd_stats.dart';

/// Pantalla "Mi espacio": rincón personal del usuario con sus datos de sesión
/// y una sección de estadísticas de nerd calculadas desde Jellyfin y ROMM.
///
/// Es adaptable: usa los tokens de [metricsFor] (ancho + modo TV/móvil/
/// escritorio) para escalar tipografías y espaciados, y decide el número de
/// columnas de las tarjetas según el ancho disponible.
class MySpaceScreen extends ConsumerWidget {
  const MySpaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);
    final mode = ref.watch(platformModeProvider).value ?? PlatformMode.mobile;
    final metrics = metricsFor(
      width: size.width,
      height: size.height,
      mode: mode,
    );
    final scale = metrics.tvScale;
    final stats = ref.watch(nerdStatsProvider);

    return Scaffold(
      body: DashboardBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MySpaceHeader(
                title: l10n.mySpace,
                subtitle: l10n.mySpaceSubtitle,
                metrics: metrics,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: metrics.pagePadding,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: metrics.isTv ? 1200 : 900,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ProfileCard(
                            metrics: metrics,
                            scale: scale,
                            onBack: () => Navigator.of(context).maybePop(),
                          ),
                          SizedBox(height: metrics.groupGap),
                          _SectionTitle(
                            title: l10n.nerdStatsTitle,
                            subtitle: l10n.nerdStatsSubtitle,
                            metrics: metrics,
                          ),
                          SizedBox(height: metrics.groupGap / 2),
                          stats.when(
                            loading: () => Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: 48 * scale,
                              ),
                              child: const Center(child: AppLoader()),
                            ),
                            error: (_, _) => _StatsError(
                              message: l10n.couldNotConnect,
                              retryLabel: l10n.retry,
                              onRetry: () => ref.invalidate(nerdStatsProvider),
                              metrics: metrics,
                            ),
                            data: (data) => _NerdStatsContent(
                              stats: data,
                              metrics: metrics,
                              scale: scale,
                            ),
                          ),
                        ],
                      ),
                    ),
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

/// Cabecera con botón de volver y título/subtítulo.
class _MySpaceHeader extends StatelessWidget {
  const _MySpaceHeader({
    required this.title,
    required this.subtitle,
    required this.metrics,
  });

  final String title;
  final String subtitle;
  final SettingsMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.isTv ? 40 : 8,
        metrics.isTv ? 24 : 8,
        metrics.isTv ? 40 : 16,
        4,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.liveTvClose,
            iconSize: metrics.pageTitleSize + 4,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: metrics.pageTitleSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: metrics.rowSubtitleSize,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de identidad: avatar, nombre, servidor y último acceso.
class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({
    required this.metrics,
    required this.scale,
    required this.onBack,
  });

  final SettingsMetrics metrics;
  final double scale;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final name = auth.user?.name ?? auth.userId ?? '';
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    final serverUrl = auth.serverUrl;
    final userId = auth.userId;
    final tag = auth.user?.primaryImageTag;
    final photoUrl = (serverUrl != null && userId != null && tag != null)
        ? '$serverUrl/Users/$userId/Images/Primary?tag=$tag'
        : null;
    final lastActivity = auth.user?.lastActivityDate;

    return Container(
      padding: EdgeInsets.all(metrics.cardPadding * scale),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(metrics.radius * scale),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.28),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 44 * scale,
            backgroundColor: theme.colorScheme.primary,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            onBackgroundImageError: photoUrl != null ? (_, _) {} : null,
            child: photoUrl == null
                ? Text(
                    initial,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34 * scale,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          SizedBox(width: 20 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: metrics.pageTitleSize * 0.82,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (serverUrl != null) ...[
                  SizedBox(height: 6 * scale),
                  Row(
                    children: [
                      Icon(
                        Icons.dns_outlined,
                        size: 15 * scale,
                        color: Colors.white54,
                      ),
                      SizedBox(width: 6 * scale),
                      Expanded(
                        child: Text(
                          '${l10n.mySpaceServer}: $serverUrl',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: metrics.rowSubtitleSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (lastActivity != null) ...[
                  SizedBox(height: 4 * scale),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: 15 * scale,
                        color: Colors.white54,
                      ),
                      SizedBox(width: 6 * scale),
                      Expanded(
                        child: Text(
                          '${l10n.mySpaceLastSeen}: '
                          '${_formatDate(lastActivity, l10n.localeName)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: metrics.rowSubtitleSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date, String locale) {
    final local = date.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    return '$d/$m/${local.year}';
  }
}

/// Título de sección con subtítulo opcional.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.metrics,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final SettingsMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: metrics.rowTitleSize * 1.35,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: TextStyle(
              color: Colors.white54,
              fontSize: metrics.rowSubtitleSize,
            ),
          ),
        ],
      ],
    );
  }
}

/// Contenido de estadísticas: tarjetas, nivel de nerd y logros.
class _NerdStatsContent extends StatelessWidget {
  const _NerdStatsContent({
    required this.stats,
    required this.metrics,
    required this.scale,
  });

  final NerdStats stats;
  final SettingsMetrics metrics;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final numberFormat = NumberFormat.decimalPattern(l10n.localeName);
    String fmt(int value) => numberFormat.format(value);

    final cards = <_StatCardData>[
      _StatCardData(
        icon: Icons.movie_outlined,
        label: l10n.statMoviesWatched,
        value: fmt(stats.moviesWatched),
      ),
      _StatCardData(
        icon: Icons.live_tv_outlined,
        label: l10n.statEpisodesWatched,
        value: fmt(stats.episodesWatched),
      ),
      _StatCardData(
        icon: Icons.theaters_outlined,
        label: l10n.statSeriesStarted,
        value: fmt(stats.seriesStarted),
      ),
      _StatCardData(
        icon: Icons.timelapse_outlined,
        label: l10n.statHoursVideo,
        value: fmt(stats.videoMinutes ~/ 60),
      ),
      _StatCardData(
        icon: Icons.music_note_outlined,
        label: l10n.statHoursMusic,
        value: fmt(stats.musicMinutes ~/ 60),
      ),
      _StatCardData(
        icon: Icons.queue_music_outlined,
        label: l10n.statSongsPlayed,
        value: fmt(stats.songsPlayed),
      ),
      _StatCardData(
        icon: Icons.menu_book_outlined,
        label: l10n.statBooksRead,
        value: fmt(stats.booksRead),
      ),
      _StatCardData(
        icon: Icons.sports_esports_outlined,
        label: l10n.statGamesOwned,
        value: fmt(stats.gamesOwned),
      ),
      _StatCardData(
        icon: Icons.videogame_asset_outlined,
        label: l10n.statGamesPlayed,
        value: fmt(stats.gamesPlayed),
      ),
      _StatCardData(
        icon: Icons.devices_other_outlined,
        label: l10n.statPlatforms,
        value: fmt(stats.platforms),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 1080
                ? 5
                : width >= 820
                ? 4
                : width >= 560
                ? 3
                : 2;
            final spacing = 12.0 * scale;
            final cardWidth = ((width - spacing * (columns - 1)) / columns)
                .clamp(110.0, double.infinity);
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final card in cards)
                  SizedBox(
                    width: cardWidth,
                    child: _StatCard(
                      data: card,
                      metrics: metrics,
                      scale: scale,
                    ),
                  ),
              ],
            );
          },
        ),
        SizedBox(height: metrics.groupGap),
        _NerdLevelCard(stats: stats, metrics: metrics, scale: scale),
        SizedBox(height: metrics.groupGap),
        _SectionTitle(title: l10n.achievementsTitle, metrics: metrics),
        SizedBox(height: metrics.groupGap / 2),
        _AchievementsGrid(stats: stats, metrics: metrics, scale: scale),
      ],
    );
  }
}

class _StatCardData {
  const _StatCardData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.data,
    required this.metrics,
    required this.scale,
  });

  final _StatCardData data;
  final SettingsMetrics metrics;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.cardPadding * 0.85 * scale,
        vertical: metrics.cardPadding * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(metrics.radius * scale),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 20 * scale, color: theme.colorScheme.primary),
          SizedBox(height: 8 * scale),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              data.value,
              style: TextStyle(
                color: Colors.white,
                fontSize: metrics.rowTitleSize * 1.7,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
          SizedBox(height: 2 * scale),
          Text(
            data.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white60,
              fontSize: metrics.rowSubtitleSize,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Nivel de nerd: puntos, nombre del nivel y progreso al siguiente.
class _NerdLevelCard extends StatelessWidget {
  const _NerdLevelCard({
    required this.stats,
    required this.metrics,
    required this.scale,
  });

  final NerdStats stats;
  final SettingsMetrics metrics;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final format = NumberFormat.decimalPattern(l10n.localeName);
    final levelName = switch (stats.nerdTier) {
      1 => l10n.nerdLevel1,
      2 => l10n.nerdLevel2,
      3 => l10n.nerdLevel3,
      4 => l10n.nerdLevel4,
      _ => l10n.nerdLevel5,
    };
    final theme = Theme.of(context);
    final next = stats.pointsToNextLevel;

    // Tasas de XP visibles: el jugador ve exactamente qué le da experiencia.
    final rules = <(int, String)>[
      (NerdStats.xpPerMovie, l10n.xpLabelMovie),
      (NerdStats.xpPerEpisode, l10n.xpLabelEpisode),
      (NerdStats.xpPerSeries, l10n.xpLabelSeries),
      (NerdStats.xpPerVideoHour, l10n.xpLabelVideoHour),
      (NerdStats.xpPerSong, l10n.xpLabelSong),
      (NerdStats.xpPerMusicHour, l10n.xpLabelMusicHour),
      (NerdStats.xpPerBook, l10n.xpLabelBook),
      (NerdStats.xpPerGamePlayed, l10n.xpLabelGame),
      (NerdStats.xpPerGameOwned, l10n.xpLabelGameOwned),
    ];

    return Container(
      padding: EdgeInsets.all(metrics.cardPadding * scale),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(metrics.radius * scale),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.35),
            theme.colorScheme.tertiary.withValues(alpha: 0.22),
          ],
        ),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.workspace_premium_outlined,
                color: Colors.white,
                size: 22 * scale,
              ),
              SizedBox(width: 8 * scale),
              Expanded(
                child: Text(
                  '${l10n.nerdLevel} ${stats.nerdLevel}/${NerdStats.maxLevel}'
                  ' · $levelName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: metrics.rowTitleSize * 1.15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6 * scale),
          Text(
            l10n.nerdPoints(format.format(stats.xp)),
            style: TextStyle(
              color: Colors.white70,
              fontSize: metrics.rowSubtitleSize,
            ),
          ),
          SizedBox(height: 10 * scale),
          ClipRRect(
            borderRadius: BorderRadius.circular(8 * scale),
            child: LinearProgressIndicator(
              value: stats.levelProgress,
              minHeight: 8 * scale,
              backgroundColor: Colors.black.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),
          SizedBox(height: 6 * scale),
          Text(
            next == null
                ? l10n.nerdMaxLevel
                : l10n.nerdNextLevel(format.format(next)),
            style: TextStyle(
              color: Colors.white54,
              fontSize: metrics.rowSubtitleSize * 0.95,
            ),
          ),
          SizedBox(height: 14 * scale),
          Divider(color: Colors.white.withValues(alpha: 0.15)),
          SizedBox(height: 6 * scale),
          Text(
            l10n.xpRulesTitle,
            style: TextStyle(
              color: Colors.white70,
              fontSize: metrics.rowSubtitleSize * 0.95,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8 * scale),
          Wrap(
            spacing: 8 * scale,
            runSpacing: 8 * scale,
            children: [
              for (final rule in rules)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10 * scale,
                    vertical: 5 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20 * scale),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Text(
                    l10n.xpRule(format.format(rule.$1), rule.$2),
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: metrics.rowSubtitleSize * 0.9,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Rejilla de logros: desbloqueados a color y pendientes atenuados con su
/// condición (el "easter egg" que invita a seguir consumiendo).
class _AchievementsGrid extends StatelessWidget {
  const _AchievementsGrid({
    required this.stats,
    required this.metrics,
    required this.scale,
  });

  final NerdStats stats;
  final SettingsMetrics metrics;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    ({String name, String description, IconData icon}) info(
      NerdAchievement achievement,
    ) => switch (achievement) {
      NerdAchievement.marathon => (
        name: l10n.achMarathon,
        description: l10n.achMarathonDesc,
        icon: Icons.local_fire_department_outlined,
      ),
      NerdAchievement.cinephile => (
        name: l10n.achCinephile,
        description: l10n.achCinephileDesc,
        icon: Icons.movie_filter_outlined,
      ),
      NerdAchievement.binge => (
        name: l10n.achBinge,
        description: l10n.achBingeDesc,
        icon: Icons.auto_awesome_motion_outlined,
      ),
      NerdAchievement.bookworm => (
        name: l10n.achBookworm,
        description: l10n.achBookwormDesc,
        icon: Icons.menu_book_outlined,
      ),
      NerdAchievement.audiophile => (
        name: l10n.achAudiophile,
        description: l10n.achAudiophileDesc,
        icon: Icons.headphones_outlined,
      ),
      NerdAchievement.retro => (
        name: l10n.achRetro,
        description: l10n.achRetroDesc,
        icon: Icons.sports_esports_outlined,
      ),
      NerdAchievement.collector => (
        name: l10n.achCollector,
        description: l10n.achCollectorDesc,
        icon: Icons.inventory_2_outlined,
      ),
      NerdAchievement.century => (
        name: l10n.achCentury,
        description: l10n.achCenturyDesc,
        icon: Icons.hourglass_bottom_outlined,
      ),
      NerdAchievement.jackOfAllTrades => (
        name: l10n.achJackOfAllTrades,
        description: l10n.achJackOfAllTradesDesc,
        icon: Icons.hub_outlined,
      ),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900
            ? 3
            : width >= 600
            ? 2
            : 1;
        final spacing = 12.0 * scale;
        final cardWidth = ((width - spacing * (columns - 1)) / columns).clamp(
          160.0,
          double.infinity,
        );
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final achievement in NerdAchievement.values)
              SizedBox(
                width: cardWidth,
                child: Builder(
                  builder: (context) {
                    final unlocked = achievement.isUnlocked(stats);
                    final details = info(achievement);
                    return Container(
                      padding: EdgeInsets.all(
                        metrics.cardPadding * 0.8 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: unlocked
                            ? theme.colorScheme.primary.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(
                          metrics.radius * scale * 0.9,
                        ),
                        border: Border.all(
                          color: unlocked
                              ? theme.colorScheme.primary.withValues(
                                  alpha: 0.55,
                                )
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            details.icon,
                            size: 24 * scale,
                            color: unlocked
                                ? theme.colorScheme.primary
                                : Colors.white24,
                          ),
                          SizedBox(width: 10 * scale),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  details.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: unlocked
                                        ? Colors.white
                                        : Colors.white38,
                                    fontSize: metrics.rowTitleSize,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  unlocked
                                      ? details.description
                                      : '${details.description} · '
                                            '${l10n.achievementLocked}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: unlocked
                                        ? Colors.white60
                                        : Colors.white24,
                                    fontSize: metrics.rowSubtitleSize * 0.95,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatsError extends StatelessWidget {
  const _StatsError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    required this.metrics,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
  final SettingsMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: metrics.groupGap),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, color: Colors.white54, size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: metrics.rowSubtitleSize,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(retryLabel),
          ),
        ],
      ),
    );
  }
}
