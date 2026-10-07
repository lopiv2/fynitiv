import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/app_loader.dart';
import '../../../l10n/app_localizations.dart';
import '../application/remote_subtitles_provider.dart';
import '../domain/subtitle_language.dart';

/// Abre el diálogo de búsqueda de subtítulos y devuelve el elegido (o `null`).
Future<RemoteSubtitleInfo?> showSubtitleSearchSheet(
  BuildContext context, {
  required String itemId,
  required List<String> languageCodes,
}) {
  return showDialog<RemoteSubtitleInfo>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => SubtitleSearchSheet(
      itemId: itemId,
      languageCodes: languageCodes,
    ),
  );
}

/// Diálogo de búsqueda de subtítulos remotos (plugin del servidor Jellyfin).
class SubtitleSearchSheet extends ConsumerStatefulWidget {
  const SubtitleSearchSheet({
    super.key,
    required this.itemId,
    required this.languageCodes,
  });

  final String itemId;

  /// Códigos de idioma candidatos (ya normalizados). Puede venir vacío.
  final List<String> languageCodes;

  @override
  ConsumerState<SubtitleSearchSheet> createState() =>
      _SubtitleSearchSheetState();
}

class _SubtitleSearchSheetState extends ConsumerState<SubtitleSearchSheet> {
  late String _language;
  late List<SubtitleLanguage> _languages;

  @override
  void initState() {
    super.initState();
    _languages = _buildLanguages(widget.languageCodes);
    _language = _languages.first.code;
  }

  List<SubtitleLanguage> _buildLanguages(List<String> codes) {
    final result = <SubtitleLanguage>[];
    final seen = <String>{};
    for (final code in codes) {
      final normalized = normalizeToIso639_2(code);
      if (normalized.isEmpty || !seen.add(normalized)) continue;
      result.add(SubtitleLanguage(normalized, subtitleLanguageLabel(normalized)));
    }
    if (result.isEmpty) {
      result.addAll(kSubtitleLanguages);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final query = RemoteSubtitleQuery(
      itemId: widget.itemId,
      language: _language,
    );
    final search = ref.watch(remoteSubtitleSearchProvider(query));

    return Dialog(
      backgroundColor: const Color(0xF0141414),
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.closed_caption, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.searchSubtitles,
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
              const SizedBox(height: 4),
              _LanguageSelector(
                value: _language,
                languages: _languages,
                label: l10n.subtitleLanguage,
                onChanged: (code) => setState(() => _language = code),
              ),
              const SizedBox(height: 8),
              const Divider(color: Colors.white24, height: 1),
              Flexible(
                child: search.when(
                  loading: () => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppLoader(size: 44),
                        const SizedBox(height: 16),
                        Text(
                          l10n.searchingSubtitles,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  error: (error, _) => _Message(
                    icon: Icons.error_outline,
                    text: _errorText(error, l10n),
                  ),
                  data: (results) {
                    if (results.isEmpty) {
                      return _Message(
                        icon: Icons.subtitles_off_outlined,
                        text: l10n.noSubtitles,
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: results.length,
                      separatorBuilder: (_, _) =>
                          const Divider(color: Colors.white12, height: 1),
                      itemBuilder: (context, i) => _SubtitleResultTile(
                        result: results[i],
                        l10n: l10n,
                        onTap: () => Navigator.of(context).pop(results[i]),
                      ),
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

  String _errorText(Object error, AppLocalizations l10n) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 403 || status == 404) {
        return l10n.remoteSubtitlesUnavailable;
      }
    }
    return l10n.couldNotLoadSubtitles;
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.value,
    required this.languages,
    required this.label,
    required this.onChanged,
  });

  final String value;
  final List<SubtitleLanguage> languages;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1E1E),
              iconEnabledColor: Colors.white70,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              items: [
                for (final lang in languages)
                  DropdownMenuItem<String>(
                    value: lang.code,
                    child: Text(lang.name),
                  ),
              ],
              onChanged: (code) {
                if (code != null) onChanged(code);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SubtitleResultTile extends StatelessWidget {
  const _SubtitleResultTile({
    required this.result,
    required this.l10n,
    required this.onTap,
  });

  final RemoteSubtitleInfo result;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = (result.name ?? result.comment ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final meta = <String>[
      if (result.providerName != null && result.providerName!.isNotEmpty)
        result.providerName!,
      if (result.author != null && result.author!.isNotEmpty) result.author!,
      if ((result.downloadCount ?? 0) > 0)
        l10n.subtitleDownloadsCount(result.downloadCount!),
      if (result.format != null && result.format!.isNotEmpty)
        result.format!.toUpperCase(),
    ];

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? l10n.subtitle : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      meta.join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (result.isHashMatch == true)
              const _Badge(text: 'HASH', color: Color(0xFF4CAF50)),
            if (result.hearingImpaired == true)
              const _Badge(text: 'HI', color: Color(0xFF42A5F5)),
            if (result.forced == true)
              const _Badge(text: 'FORCED', color: Color(0xFFAB47BC)),
            const Icon(Icons.download_rounded, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white38, size: 40),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
