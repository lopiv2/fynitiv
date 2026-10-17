import 'dart:async';

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/skin/layout_section.dart';
import '../../../core/skin/skin_controller.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_tab_bar.dart';
import '../../../core/widgets/library_page_header.dart';
import '../../../l10n/app_localizations.dart';
import '../application/seerr_controller.dart';
import '../application/seerr_providers.dart';
import '../data/seerr_api.dart';

import '../domain/seerr_models.dart';
import 'widgets/seerr_content_row.dart';
import 'widgets/seerr_media_row.dart';
import 'widgets/seerr_poster_grid.dart';
import 'widgets/seerr_request_status_badge.dart';

/// Seerr: descubrimiento y peticiones de contenido (TMDB vía Seerr).
class SeerrScreen extends ConsumerStatefulWidget {
  const SeerrScreen({super.key});

  @override
  ConsumerState<SeerrScreen> createState() => _SeerrScreenState();
}

enum _SeerrTab { upcoming, search, requests }

class _SeerrScreenState extends ConsumerState<SeerrScreen> {
  _SeerrTab _tab = _SeerrTab.upcoming;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _query = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final skin = ref.watch(skinControllerProvider).value;
    final connected = ref.watch(seerrConnectedProvider);

    return Scaffold(
      body: DashboardBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: libraryPageTopPadding(context, skin)),
            //LibraryPageHeader(title: l10n.seerr, showBack: false),
            Expanded(
              child: connected ? _buildContent(l10n) : const _SetupPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppLocalizations l10n) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: AppTabBar(
            index: _tab.index,
            onChanged: (i) {
              setState(() => _tab = _SeerrTab.values[i]);
              // La lista de peticiones puede haber cambiado fuera de la app
              // (web de Seerr, aprobación…): se refresca al abrir la pestaña.
              if (_tab == _SeerrTab.requests) {
                ref.invalidate(seerrRequestsProvider);
              }
            },
            items: [
              AppTabItem(
                label: l10n.seerrUpcomingTab,
                iconBuilder: (selected) => Icon(
                  Icons.event_available_outlined,
                  size: 22,
                  color: selected ? Colors.black : Colors.white70,
                ),
              ),
              AppTabItem(
                label: l10n.seerrSearchTab,
                iconBuilder: (selected) => Icon(
                  Icons.search,
                  size: 22,
                  color: selected ? Colors.black : Colors.white70,
                ),
              ),
              AppTabItem(
                label: l10n.seerrRequestsTab,
                iconBuilder: (selected) => Icon(
                  Icons.download_done_outlined,
                  size: 22,
                  color: selected ? Colors.black : Colors.white70,
                ),
              ),
            ],
          ),
        ),
        if (_tab == _SeerrTab.search)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        Expanded(child: _buildTab(l10n)),
      ],
    );
  }

  Widget _buildTab(AppLocalizations l10n) {
    switch (_tab) {
      case _SeerrTab.upcoming:
        return const _UpcomingTab();
      case _SeerrTab.search:
        if (_query.trim().isEmpty) {
          return _centerHint(l10n.seerrSearchTab);
        }
        return _SearchTab(query: _query);
      case _SeerrTab.requests:
        return const _RequestsTab();
    }
  }

  Widget _centerHint(String text) =>
      Center(child: Text(text, style: const TextStyle(color: Colors.white54)));
}

// ---------------------------------------------------------------------------
// Descubrir / Buscar / Peticiones
// ---------------------------------------------------------------------------

/// Orden por defecto de secciones de descubrimiento si el skin no define
/// `seerrLayout`.
const List<LayoutSection> _kDefaultSeerrLayout = [
  LayoutSection.seerrDiscover(SeerrDiscoverCategory.trending),
  LayoutSection.seerrDiscover(SeerrDiscoverCategory.popularMovies),
  LayoutSection.seerrDiscover(SeerrDiscoverCategory.upcomingMovies),
  LayoutSection.seerrDiscover(SeerrDiscoverCategory.popularTv),
  LayoutSection.seerrDiscover(SeerrDiscoverCategory.upcomingTv),
];

class _UpcomingTab extends ConsumerWidget {
  const _UpcomingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(skinControllerProvider).value;
    final layout = (skin?.seerrLayout.isNotEmpty ?? false)
        ? skin!.seerrLayout
        : _kDefaultSeerrLayout;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        for (final section in layout)
          if (section.type == LayoutSectionType.seerrDiscover &&
              section.seerrCategory != null)
            SeerrMediaRow(
              category: section.seerrCategory!,
              scroll: section.scroll,
            ),
      ],
    );
  }
}

class _SearchTab extends ConsumerWidget {
  const _SearchTab({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final result = ref.watch(seerrSearchProvider(query));
    return result.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Text(
              l10n.noResults,
              style: const TextStyle(color: Colors.white54),
            ),
          );
        }
        return _MediaGrid(items: items);
      },
      loading: () => const Center(child: AppLoader()),
      error: (_, _) => Center(
        child: Text(
          l10n.noResults,
          style: const TextStyle(color: Colors.white54),
        ),
      ),
    );
  }
}

class _MediaGrid extends ConsumerWidget {
  const _MediaGrid({required this.items});

  final List<SeerrMedia> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final skin = ref.watch(skinControllerProvider).value;
    final entries = <SeerrPosterGridEntry>[];
    for (final m in items) {
      final metadata = ref
          .watch(
            seerrCardMetadataProvider(
              (mediaType: m.mediaType, tmdbId: m.tmdbId, title: m.title),
            ),
          )
          .value;
      final providerLogos = <String>[
        for (final logo in (metadata?.providers ?? const [])
            .map((provider) => provider.logoUrl())
            .whereType<String>())
          logo,
      ];
      entries.add(
        SeerrPosterGridEntry(
          item: seerrMediaToBaseItem(m),
          imageUrl: m.posterUrl(),
          hoverActionLabel: l10n.seerrRequest,
          cardLogo: providerLogos.isEmpty &&
                  metadata?.libraryStatus == SeerrLibraryStatus.available
              ? skin?.cardLogo ?? 'assets/images/jellyfin.png'
              : null,
          cornerLogos: providerLogos,
          onTap: () => context.push('/seerr/${m.mediaType.value}/${m.tmdbId}'),
        ),
      );
    }
    return SeerrPosterGrid(entries: entries);
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final skin = ref.watch(skinControllerProvider).value;
    final requests = ref.watch(seerrRequestsProvider);
    return requests.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Text(
              l10n.noResults,
              style: const TextStyle(color: Colors.white54),
            ),
          );
        }
        // La lista de /request no trae carátula fiable: se enriquece cada
        // petición con su ficha de TMDB y, mientras llega, se muestra lo que
        // la propia petición aporta.
        final cards = <_RequestCard>[];
        final useBackdrop = seerrUseBackdrop(skin);
        for (final r in items) {
          final detail = ref
              .watch(
                seerrDetailProvider((mediaType: r.mediaType, tmdbId: r.tmdbId)),
              )
              .value;
          final media = detail ?? seerrRequestToMedia(r);
          final metadata = ref
              .watch(
                seerrCardMetadataProvider((
                  mediaType: media.mediaType,
                  tmdbId: media.tmdbId,
                  title: media.title,
                )),
              )
              .value;
          final providerLogos = <String>[
            for (final logo in (metadata?.providers ?? const [])
                .map((provider) => provider.logoUrl())
                .whereType<String>())
              logo,
          ];
          // El título ya está en la biblioteca: la petición está cumplida.
          final inLibrary =
              metadata?.libraryStatus == SeerrLibraryStatus.available;
          cards.add(
            _RequestCard(
              request: r,
              media: media,
              item: seerrRequestToBaseItem(r, media: media),
              imageUrl: useBackdrop ? media.backdropUrl() : media.posterUrl(),
              inLibrary: inLibrary,
              providerLogos: providerLogos,
              cardLogo: providerLogos.isEmpty && inLibrary
                  ? skin?.cardLogo ?? 'assets/images/jellyfin.png'
                  : null,
            ),
          );
        }
        final byId = {for (final c in cards) c.item.id ?? '': c};
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            SeerrContentRow(
              title: l10n.seerrRequestsTab,
              items: [for (final c in cards) c.item],
              hoverActionLabel: l10n.details,
              onItemTap: (it) {
                final c = byId[it.id];
                if (c == null) return;
                context.push(
                  '/seerr/${c.media.mediaType.value}/${c.media.tmdbId}',
                );
              },
              imageUrlFor: (it) => byId[it.id]?.imageUrl,
              cardLogoFor: (it) => byId[it.id]?.cardLogo,
              cornerLogosFor: (it) => byId[it.id]?.providerLogos ?? const [],
              cornerBadgeFor: (it) {
                final c = byId[it.id];
                if (c == null) return null;
                return SeerrRequestStatusBadge(
                  label: c.inLibrary
                      ? l10n.seerrStatusAvailable
                      : _requestStatusLabel(l10n, c.request.status),
                  status: c.request.status,
                  inLibrary: c.inLibrary,
                );
              },
            ),
          ],
        );
      },
      loading: () => const Center(child: AppLoader()),
      error: (_, _) => Center(
        child: Text(
          l10n.noResults,
          style: const TextStyle(color: Colors.white54),
        ),
      ),
    );
  }
}

/// Petición + ficha de TMDB (o respaldo) + datos de tarjeta ya resueltos.
class _RequestCard {
  const _RequestCard({
    required this.request,
    required this.media,
    required this.item,
    required this.providerLogos,
    this.imageUrl,
    this.cardLogo,
    this.inLibrary = false,
  });

  final SeerrRequest request;
  final SeerrMedia media;
  final BaseItemDto item;

  /// Imagen de la tarjeta (póster o backdrop de TMDB, según el skin).
  final String? imageUrl;

  /// Logos de plataformas (TMDB) del título.
  final List<String> providerLogos;

  /// Logo de "En tu biblioteca", si el título ya está en Jellyfin.
  final String? cardLogo;

  /// El título ya está disponible en la biblioteca Jellyfin.
  final bool inLibrary;
}

String _requestStatusLabel(AppLocalizations l10n, int status) {
  switch (status) {
    case 1:
      return l10n.seerrStatusPending;
    case 2:
      return l10n.seerrStatusApproved;
    case 3:
      return l10n.seerrStatusDeclined;
    default:
      return '';
  }
}

// ---------------------------------------------------------------------------
// Configuración / conexión
// ---------------------------------------------------------------------------

class _SetupPanel extends ConsumerStatefulWidget {
  const _SetupPanel();

  @override
  ConsumerState<_SetupPanel> createState() => _SetupPanelState();
}

class _SetupPanelState extends ConsumerState<_SetupPanel> {
  late final TextEditingController _urlController;
  final TextEditingController _apiKeyController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final conn = ref.read(seerrConnectionProvider).value;
    _urlController = TextEditingController(text: conn?.baseUrl ?? '');
  }

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  String? _validUrl() {
    final url = _urlController.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      setState(() => _error = AppLocalizations.of(context)!.seerrInvalidUrl);
      return null;
    }
    return url;
  }

  Future<void> _quickConnect() async {
    final url = _validUrl();
    if (url == null) return;
    setState(() => _error = null);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QuickConnectDialog(
        baseUrl: url,
        onConnected: (cookie) {
          ref
              .read(seerrConnectionProvider.notifier)
              .save(baseUrl: url, credential: cookie, isApiKey: false);
        },
      ),
    );
  }

  Future<void> _saveApiKey() async {
    final url = _validUrl();
    if (url == null) return;
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = AppLocalizations.of(context)!.seerrApiKeyRequired);
      return;
    }
    setState(() => _error = null);
    await ref
        .read(seerrConnectionProvider.notifier)
        .save(baseUrl: url, credential: key, isApiKey: true);
    if (!mounted) return;
    unawaited(
      EasyLoading.showSuccess(
        AppLocalizations.of(context)!.save,
        maskType: EasyLoadingMaskType.none,
        dismissOnTap: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // `FilledButton`/`OutlinedButton` derivan su color de `colorScheme.primary`
    // (sobrescrito con `skin.primary`). Con skins de primario oscuro (p. ej.
    // Disney+) el texto queda invisible; se fija el color explícitamente.
    final accent =
        ref.watch(skinControllerProvider).value?.accent ??
        Theme.of(context).colorScheme.primary;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.seerrNotConfigured,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: l10n.seerrServerUrl,
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'http://192.168.1.10:5055',
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.dns_outlined, color: Colors.white70),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _quickConnect,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.qr_code_2),
                label: Text(l10n.seerrQuickConnect),
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white24),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: l10n.seerrApiKey,
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(
                    Icons.vpn_key_outlined,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: _saveApiKey,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: Text(l10n.seerrUseApiKey),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickConnectDialog extends ConsumerStatefulWidget {
  const _QuickConnectDialog({required this.baseUrl, required this.onConnected});

  final String baseUrl;
  final void Function(String cookie) onConnected;

  @override
  ConsumerState<_QuickConnectDialog> createState() =>
      _QuickConnectDialogState();
}

class _QuickConnectDialogState extends ConsumerState<_QuickConnectDialog> {
  SeerrQuickConnect? _qc;
  String? _error;
  Timer? _poll;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    // `_start` usa `AppLocalizations.of(context)`, que no puede llamarse en
    // `initState`; se difiere al primer frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final api = SeerrApi(baseUrl: widget.baseUrl);
      final qc = await api.initiateQuickConnect();
      if (!mounted) return;
      setState(() => _qc = qc);
      _poll = Timer.periodic(const Duration(seconds: 2), (_) => _check());
    } on SeerrException catch (e) {
      if (mounted) setState(() => _error = _seerrErrorText(l10n, e));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  String _seerrErrorText(AppLocalizations l10n, SeerrException e) {
    switch (e.kind) {
      case SeerrErrorKind.certificate:
        return l10n.seerrCertError;
      case SeerrErrorKind.network:
        return l10n.seerrNetworkError;
      case SeerrErrorKind.unauthorized:
        return l10n.seerrUnauthorized;
      case SeerrErrorKind.notFound:
        return l10n.seerrNotFound;
      case SeerrErrorKind.forbidden:
      case SeerrErrorKind.duplicate:
      case SeerrErrorKind.noSeasons:
      case SeerrErrorKind.csrf:
      case SeerrErrorKind.http:
      case SeerrErrorKind.response:
      case SeerrErrorKind.unknown:
        return e.message;
    }
  }

  Future<void> _check() async {
    final qc = _qc;
    if (qc == null || _finishing) return;
    try {
      final api = SeerrApi(baseUrl: widget.baseUrl);
      final authorized = await api.checkQuickConnect(qc.secret);
      if (!authorized || !mounted) return;
      _finishing = true;
      _poll?.cancel();
      final cookie = await api.authenticateQuickConnect(qc.secret);
      if (cookie == null) {
        if (mounted) {
          setState(() {
            _error = AppLocalizations.of(context)!.seerrQuickConnectFailed;
            _finishing = false;
          });
        }
        return;
      }
      widget.onConnected(cookie);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      _finishing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // `Dialog` (no `AlertDialog`): este último mide por intrínsecos y el
    // contenido (loader/QR) usa `LayoutBuilder`, que no soporta intrínsecos.
    return Dialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.seerrQuickConnect,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              else if (_qc == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: AppLoader(),
                  ),
                )
              else ...[
                Text(
                  l10n.seerrQuickConnectHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.white,
                    child: QrImageView(
                      data: _qc!.code,
                      version: QrVersions.auto,
                      size: 200,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  _qc!.code,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.seerrQuickConnectWaiting,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
