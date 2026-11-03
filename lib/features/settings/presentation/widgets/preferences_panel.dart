import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/settings/allow_bad_certificates_controller.dart';
import '../../../../core/settings/reader_page_flip_controller.dart';
import '../../../../core/settings/seasonal_suggestions_controller.dart';
import '../../../../core/settings/seasonal_theme_controller.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/language_selector.dart';
import '../../../../l10n/app_localizations.dart';
import 'settings_group.dart';
import 'settings_metrics.dart';
import 'settings_scaffold.dart';

/// Panel de Preferencias: dos grupos semánticos con filas compartidas.
///
/// - “Idioma y tema”: idioma + tema (chips en `Wrap` para no desbordar
///   con traducciones largas).
/// - “Reproducción y contenido”: sugerencias/tema estacional (+ intensidad),
///   animación de página del lector y certificados.
/// - A ≥1600 px los dos grupos van lado a lado.
class PreferencesPanel extends ConsumerWidget {
  const PreferencesPanel({super.key, required this.metrics});

  final SettingsMetrics metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final wide = MediaQuery.sizeOf(context).width >= 1600;

    final languageTheme = SettingsGroup(
      metrics: metrics,
      title: l10n.prefsGroupLanguageTheme,
      children: [
        _FullWidthBlock(
          metrics: metrics,
          title: l10n.language,
          child: const Align(
            alignment: Alignment.centerLeft,
            child: LanguageSelector(),
          ),
        ),
        _FullWidthBlock(
          metrics: metrics,
          title: l10n.theme,
          child: _ThemeChips(metrics: metrics),
        ),
      ],
    );

    final playbackContent = SettingsGroup(
      metrics: metrics,
      title: l10n.prefsGroupPlaybackContent,
      children: [
        _SeasonalSuggestionsRow(metrics: metrics),
        _SeasonalThemeRows(metrics: metrics),
        _ReaderPageFlipRow(metrics: metrics),
        _AllowBadCertificatesRow(metrics: metrics),
      ],
    );

    List<Widget> body;
    if (wide) {
      body = [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: languageTheme),
            SizedBox(width: metrics.groupGap),
            Expanded(child: playbackContent),
          ],
        ),
      ];
    } else {
      body = [
        languageTheme,
        SizedBox(height: metrics.groupGap),
        playbackContent,
      ];
    }

    return SettingsScaffold(
      metrics: metrics,
      title: l10n.preferences,
      children: body,
    );
  }
}

/// Bloque de ancho completo dentro de un grupo (selector de idioma,
/// chips de tema): título arriba y control debajo.
class _FullWidthBlock extends StatelessWidget {
  const _FullWidthBlock({
    required this.metrics,
    required this.title,
    required this.child,
  });

  final SettingsMetrics metrics;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.cardPadding,
        vertical: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: metrics.rowTitleSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ThemeChips extends ConsumerWidget {
  const _ThemeChips({required this.metrics});

  final SettingsMetrics metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final mode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    final setMode = ref.read(themeModeProvider.notifier).setThemeMode;
    final options = <(ThemeMode, String)>[
      (ThemeMode.system, l10n.themeSystem),
      (ThemeMode.light, l10n.themeLight),
      (ThemeMode.dark, l10n.themeDark),
    ];
    // `Wrap` en vez de `Row`: no desborda con traducciones largas.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o.$2),
            selected: mode == o.$1,
            onSelected: (_) => setMode(o.$1),
          ),
      ],
    );
  }
}

class _SeasonalSuggestionsRow extends ConsumerWidget {
  const _SeasonalSuggestionsRow({required this.metrics});

  final SettingsMetrics metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(seasonalSuggestionsEnabledProvider);
    final value = state.value ?? true;
    void toggle(bool v) =>
        ref.read(seasonalSuggestionsEnabledProvider.notifier).setEnabled(v);
    return SettingsRow(
      metrics: metrics,
      title: l10n.seasonalSuggestions,
      subtitle: l10n.seasonalSuggestionsHint,
      onTap: state.isLoading ? null : () => toggle(!value),
      trailing: Switch(
        value: value,
        onChanged: state.isLoading ? null : toggle,
      ),
    );
  }
}

class _SeasonalThemeRows extends ConsumerWidget {
  const _SeasonalThemeRows({required this.metrics});

  final SettingsMetrics metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final enabledState = ref.watch(seasonalThemeEnabledProvider);
    final enabled = enabledState.value ?? true;
    final intensityState = ref.watch(seasonalThemeIntensityProvider);
    final intensity = intensityState.value ?? kSeasonalThemeDefaultIntensity;
    void toggle(bool v) =>
        ref.read(seasonalThemeEnabledProvider.notifier).setEnabled(v);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsRow(
          metrics: metrics,
          title: l10n.seasonalTheme,
          subtitle: l10n.seasonalThemeHint,
          onTap: enabledState.isLoading ? null : () => toggle(!enabled),
          trailing: Switch(
            value: enabled,
            onChanged: enabledState.isLoading ? null : toggle,
          ),
        ),
        if (enabled)
          Padding(
            padding: EdgeInsets.fromLTRB(
              metrics.cardPadding,
              4,
              metrics.cardPadding,
              12,
            ),
            child: Row(
              children: [
                Text(
                  l10n.seasonalThemeIntensity,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: metrics.rowSubtitleSize + 1,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: intensity.clamp(0.0, 1.0),
                    divisions: 20,
                    label: '${(intensity * 100).round()}%',
                    onChanged: intensityState.isLoading
                        ? null
                        : (v) => ref
                              .read(seasonalThemeIntensityProvider.notifier)
                              .setIntensity(v),
                  ),
                ),
                Text(
                  '${(intensity * 100).round()}%',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: metrics.rowSubtitleSize + 1,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReaderPageFlipRow extends ConsumerWidget {
  const _ReaderPageFlipRow({required this.metrics});

  final SettingsMetrics metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(readerPageFlipEnabledProvider);
    final value = state.value ?? true;
    void toggle(bool v) =>
        ref.read(readerPageFlipEnabledProvider.notifier).setEnabled(v);
    return SettingsRow(
      metrics: metrics,
      title: l10n.readerPageFlip,
      subtitle: l10n.readerPageFlipHint,
      onTap: state.isLoading ? null : () => toggle(!value),
      trailing: Switch(
        value: value,
        onChanged: state.isLoading ? null : toggle,
      ),
    );
  }
}

class _AllowBadCertificatesRow extends ConsumerWidget {
  const _AllowBadCertificatesRow({required this.metrics});

  final SettingsMetrics metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(allowBadCertificatesProvider);
    final value = state.value ?? true;
    void toggle(bool v) =>
        ref.read(allowBadCertificatesProvider.notifier).setEnabled(v);
    return SettingsRow(
      metrics: metrics,
      title: l10n.allowBadCertificates,
      subtitle: l10n.allowBadCertificatesHint,
      onTap: state.isLoading ? null : () => toggle(!value),
      trailing: Switch(
        value: value,
        onChanged: state.isLoading ? null : toggle,
      ),
    );
  }
}
