import 'package:country_flags/country_flags.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/skin/radio_skin.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/radio_providers.dart';
import '../../data/radio_api.dart';

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
              _countryDropdown(
                hint: l10n.radioCountry,
                value: _country,
                countries: countriesAsync.value ?? const [],
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

  Widget _countryDropdown({
    required String hint,
    required String? value,
    required List<RadioCountry> countries,
    required ValueChanged<String?> onChanged,
  }) {
    final display = countries.take(400).toList();
    final selected = value == null ? null : display.where((e) => e.name == value).firstOrNull;
    Widget flagWidget(String code) {
      if (code.isEmpty || code.length != 2) return const SizedBox.shrink();
      return CountryFlag.fromCountryCode(
        code,
        theme: const ImageTheme(width: 22, height: 16, shape: RoundedRectangle(3)),
      );
    }

    return InkWell(
      onTap: () async {
        final picked = await _showCountryPickerDialog(
          hint: hint,
          countries: display,
          current: value,
          flagBuilder: flagWidget,
        );
        if (picked == _kPickerCancelled) return;
        final newVal = picked == '' ? null : picked;
        onChanged(newVal);
        Future.microtask(_apply);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: widget.skin.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (selected != null && selected.code.isNotEmpty) flagWidget(selected.code),
            if (selected != null && selected.code.isNotEmpty) const SizedBox(width: 6),
            Flexible(
              child: Text(
                selected?.name ?? (value ?? hint),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected != null || value == null ? Colors.white : widget.skin.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_drop_down_rounded, color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }

  static const _kPickerCancelled = '__cancelled__';

  Future<String?> _showCountryPickerDialog({
    required String hint,
    required List<RadioCountry> countries,
    required String? current,
    required Widget Function(String code) flagBuilder,
  }) {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        List<RadioCountry> filtered = countries;
        final ctrl = TextEditingController();
        return StatefulBuilder(
          builder: (context, setStateDlg) {
            void updateFilter(String v) {
              setStateDlg(() {
                final q = v.toLowerCase().trim();
                if (q.isEmpty) {
                  filtered = countries;
                } else {
                  // Prioriza empieza por, luego contiene
                  final starts = <RadioCountry>[];
                  final contains = <RadioCountry>[];
                  for (final c in countries) {
                    final n = c.name.toLowerCase();
                    if (n.startsWith(q)) {
                      starts.add(c);
                    } else if (n.contains(q)) {
                      contains.add(c);
                    }
                  }
                  filtered = [...starts, ...contains];
                }
              });
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              title: Text(hint, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              content: SizedBox(
                width: 380,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      controller: ctrl,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Buscar...',
                        hintStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 18),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      onChanged: updateFilter,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ListView.separated(
                          itemCount: filtered.length + 1,
                          separatorBuilder: (_, _) => const Divider(color: Colors.white10, height: 1),
                          itemBuilder: (context, i) {
                            if (i == 0) {
                              final isSel = current == null;
                              return ListTile(
                                dense: true,
                                visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                                selected: isSel,
                                selectedTileColor: Colors.white.withValues(alpha: 0.08),
                                title: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    AppLocalizations.of(context)!.radioAll,
                                    style: TextStyle(
                                      color: isSel ? widget.skin.accent : Colors.white,
                                      fontSize: 12,
                                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                                    ),
                                  ),
                                ),
                                onTap: () => Navigator.pop(context, ''),
                              );
                            }
                            final c = filtered[i - 1];
                            final isSel = c.name == current;
                            return ListTile(
                              dense: true,
                              visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                              selected: isSel,
                              selectedTileColor: Colors.white.withValues(alpha: 0.08),
                              leading: c.code.isNotEmpty ? flagBuilder(c.code) : const SizedBox(width: 22),
                              title: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  c.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isSel ? widget.skin.accent : Colors.white,
                                    fontSize: 12,
                                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                                  ),
                                ),
                              ),
                              onTap: () => Navigator.pop(context, c.name),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, _kPickerCancelled),
                  child: const Text('Cerrar', style: TextStyle(color: Colors.white70)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _dropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final displayItems = items.take(400).toList();
    return InkWell(
      onTap: () async {
        final picked = await _showStringPickerDialog(hint: hint, items: displayItems, current: value);
        if (picked == _kPickerCancelled) return;
        final newVal = picked == '' ? null : picked;
        onChanged(newVal);
        Future.microtask(_apply);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: widget.skin.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                value ?? hint,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: value != null ? Colors.white : widget.skin.textSecondary, fontSize: 12),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_drop_down_rounded, color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }

  Future<String?> _showStringPickerDialog({
    required String hint,
    required List<String> items,
    required String? current,
  }) {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        List<String> filtered = items;
        final ctrl = TextEditingController();
        return StatefulBuilder(
          builder: (context, setStateDlg) {
            void updateFilter(String v) {
              setStateDlg(() {
                final q = v.toLowerCase().trim();
                if (q.isEmpty) {
                  filtered = items;
                } else {
                  final starts = <String>[];
                  final contains = <String>[];
                  for (final it in items) {
                    final n = it.toLowerCase();
                    if (n.startsWith(q)) {
                      starts.add(it);
                    } else if (n.contains(q)) {
                      contains.add(it);
                    }
                  }
                  filtered = [...starts, ...contains];
                }
              });
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              title: Text(hint, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              content: SizedBox(
                width: 380,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      controller: ctrl,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Buscar...',
                        hintStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 18),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      onChanged: updateFilter,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ListView.separated(
                          itemCount: filtered.length + 1,
                          separatorBuilder: (_, _) => const Divider(color: Colors.white10, height: 1),
                          itemBuilder: (context, i) {
                            if (i == 0) {
                              final isSel = current == null;
                              return ListTile(
                                dense: true,
                                visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                                selected: isSel,
                                selectedTileColor: Colors.white.withValues(alpha: 0.08),
                                title: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    AppLocalizations.of(context)!.radioAll,
                                    style: TextStyle(color: isSel ? widget.skin.accent : Colors.white, fontSize: 12, fontWeight: isSel ? FontWeight.w700 : FontWeight.w400),
                                  ),
                                ),
                                onTap: () => Navigator.pop(context, ''),
                              );
                            }
                            final it = filtered[i - 1];
                            final isSel = it == current;
                            return ListTile(
                              dense: true,
                              visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                              selected: isSel,
                              selectedTileColor: Colors.white.withValues(alpha: 0.08),
                              title: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  it,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: isSel ? widget.skin.accent : Colors.white, fontSize: 12, fontWeight: isSel ? FontWeight.w700 : FontWeight.w400),
                                ),
                              ),
                              onTap: () => Navigator.pop(context, it),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, _kPickerCancelled), child: const Text('Cerrar', style: TextStyle(color: Colors.white70))),
              ],
            );
          },
        );
      },
    );
  }
}
