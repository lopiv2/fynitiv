import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/skin/radio_skin.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/radio_providers.dart';

class RadioFilters extends ConsumerStatefulWidget {
  const RadioFilters({super.key, required this.skin});

  final RadioSkin skin;

  @override
  ConsumerState<RadioFilters> createState() => _RadioFiltersState();
}

class _RadioFiltersState extends ConsumerState<RadioFilters> {
  final _searchCtrl = TextEditingController();
  String? _country;
  String? _language;
  String? _tag;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    ref.read(radioSearchQueryProvider.notifier).set(RadioSearchQuery(
      name: _searchCtrl.text.trim(),
      tag: _tag ?? '',
      country: _country ?? '',
      language: _language ?? '',
    ));
  }

  void _clear() {
    _searchCtrl.clear();
    setState(() {
      _country = null;
      _language = null;
      _tag = null;
    });
    ref.read(radioSearchQueryProvider.notifier).set(const RadioSearchQuery());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final countriesAsync = ref.watch(radioCountriesProvider);
    final languagesAsync = ref.watch(radioLanguagesProvider);
    final tagsAsync = ref.watch(radioTagsProvider);
    final accent = widget.skin.accent;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: l10n.radioSearchHint,
                  hintStyle: TextStyle(color: widget.skin.textSecondary),
                  filled: true,
                  fillColor: widget.skin.cardBackground.withValues(alpha: 0.9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (_) => _apply(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _apply,
              style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
              icon: const Icon(Icons.search_rounded, size: 16),
              label: Text(l10n.radioSearch),
            ),
            const SizedBox(width: 6),
            OutlinedButton(
              onPressed: _clear,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24)),
              child: Text(l10n.radioClear),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _dropdown(
                hint: l10n.radioCountry,
                value: _country,
                items: countriesAsync.value ?? const [],
                onChanged: (v) => setState(() => _country = v),
              ),
              const SizedBox(width: 8),
              _dropdown(
                hint: l10n.radioLanguage,
                value: _language,
                items: languagesAsync.value ?? const [],
                onChanged: (v) => setState(() => _language = v),
              ),
              const SizedBox(width: 8),
              _dropdown(
                hint: l10n.radioTag,
                value: _tag,
                items: tagsAsync.value ?? const [],
                onChanged: (v) => setState(() => _tag = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final displayItems = items.take(200).toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: widget.skin.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child:           DropdownButton<String>(
        value: value,
        hint: Text(hint, style: TextStyle(color: widget.skin.textSecondary, fontSize: 12)),
        underline: const SizedBox.shrink(),
        dropdownColor: const Color(0xFF1E293B),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        items: [
          DropdownMenuItem<String>(value: null, child: Text(AppLocalizations.of(context)!.radioAll, style: TextStyle(color: widget.skin.textSecondary))),
          for (final it in displayItems) DropdownMenuItem<String>(value: it, child: Text(it, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) {
          onChanged(v);
          // Auto-apply on change for UX
          Future.microtask(_apply);
        },
      ),
    );
  }
}
