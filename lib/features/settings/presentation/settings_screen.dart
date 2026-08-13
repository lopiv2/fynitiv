import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/language_selector.dart';
import '../../../core/widgets/scale_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../household/application/household_provider.dart';
import 'widgets/appearance_panel.dart';

enum SettingsSection { preferences, appearance, home, account, about }

/// Pantalla de ajustes de la app. Adaptativa: menú lateral en pantallas anchas
/// (TV/escritorio) y pestañas superiores en móvil.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  SettingsSection _section = SettingsSection.preferences;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    final useMenu = width >= 700;

    final sections = <(SettingsSection, IconData, String)>[
      (SettingsSection.preferences, Icons.tune, l10n.preferences),
      (SettingsSection.appearance, Icons.palette_outlined, l10n.appearance),
      (SettingsSection.home, Icons.home_outlined, l10n.currentHome),
      (SettingsSection.account, Icons.person_outline, l10n.account),
      (SettingsSection.about, Icons.info_outline, l10n.about),
    ];

    return Scaffold(
      body: DashboardBackground(
        child: useMenu
            ? Row(
                children: [
                  _buildMenu(sections),
                  const VerticalDivider(
                    width: 1,
                    color: Color(0xFF1A2568),
                  ),
                  Expanded(child: _buildPanel()),
                ],
              )
            : Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    onTap: (i) =>
                        setState(() => _section = sections[i].$1),
                    tabs: [
                      for (final s in sections)
                        Tab(
                          icon: Icon(s.$2),
                          text: s.$3,
                        ),
                    ],
                  ),
                  Expanded(child: _buildPanel()),
                ],
              ),
      ),
    );
  }

  Widget _buildMenu(List<(SettingsSection, IconData, String)> sections) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          for (final s in sections)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: ScaleButton(
                selected: _section == s.$1,
                selectedScale: 1.04,
                borderRadius: BorderRadius.circular(10),
                onPressed: () => setState(() => _section = s.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: _section == s.$1
                        ? const Color(0xFF1A2568)
                        : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        s.$2,
                        color: _section == s.$1
                            ? Colors.white
                            : Colors.white60,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        s.$3,
                        style: TextStyle(
                          color: _section == s.$1
                              ? Colors.white
                              : Colors.white70,
                          fontSize: 15,
                          fontWeight: _section == s.$1
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPanel() {
    switch (_section) {
      case SettingsSection.preferences:
        return _PreferencesPanel();
      case SettingsSection.appearance:
        return const AppearancePanel();
      case SettingsSection.home:
        return _HomePanel();
      case SettingsSection.account:
        return _AccountPanel();
      case SettingsSection.about:
        return _AboutPanel();
    }
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _PreferencesPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return _SettingsPanel(
      title: l10n.preferences,
      children: [
        _buildLanguage(context, l10n),
        const SizedBox(height: 24),
        _buildTheme(context, ref, l10n),
      ],
    );
  }

  Widget _buildLanguage(BuildContext context, AppLocalizations l10n) {
    return _SettingsCard(
      title: l10n.language,
      child: const Align(
        alignment: Alignment.centerLeft,
        child: LanguageSelector(),
      ),
    );
  }

  Widget _buildTheme(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final mode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    final setMode = ref.read(themeModeProvider.notifier).setThemeMode;
    final options = <(ThemeMode, String)>[
      (ThemeMode.system, l10n.themeSystem),
      (ThemeMode.light, l10n.themeLight),
      (ThemeMode.dark, l10n.themeDark),
    ];
    return _SettingsCard(
      title: l10n.theme,
      child: Row(
        children: [
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(o.$2),
                selected: mode == o.$1,
                onSelected: (_) => setMode(o.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _HomePanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final household = ref.watch(householdProvider);
    final name = household?.name ?? '—';
    return _SettingsPanel(
      title: l10n.currentHome,
      children: [
        _SettingsCard(
          title: l10n.currentHome,
          subtitle: name,
        ),
        const SizedBox(height: 12),
        ScaleButton(
          selectedScale: 1.03,
          borderRadius: BorderRadius.circular(12),
          onPressed: () => context.push('/setup', extra: household),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF1A2568),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_outlined, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  l10n.manageHome,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final name = auth.user?.name ?? auth.userId ?? '—';
    return _SettingsPanel(
      title: l10n.account,
      children: [
        _SettingsCard(
          title: l10n.currentUser,
          subtitle: name,
          leading: CircleAvatar(
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ScaleButton(
          selectedScale: 1.03,
          borderRadius: BorderRadius.circular(12),
          onPressed: () => controller.logout(),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.red.withValues(alpha: 0.15),
            ),
            child: Row(
              children: [
                Icon(Icons.logout, color: Colors.red.shade300),
                const SizedBox(width: 12),
                Text(
                  l10n.signOut,
                  style: TextStyle(
                    color: Colors.red.shade300,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AboutPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SettingsPanel(
      title: l10n.about,
      children: [
        const Icon(Icons.play_circle_fill, color: Colors.white, size: 56),
        const SizedBox(height: 12),
        Text(
          AppConstants.appName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${l10n.version} ${AppConstants.appVersion}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.aboutDescription,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    this.subtitle,
    this.child,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Widget? child;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null || title.isNotEmpty)
            Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title.isNotEmpty)
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          if (child != null) ...[
            if (title.isNotEmpty || leading != null)
              const SizedBox(height: 12),
            child!,
          ],
        ],
      ),
    );
  }
}
