import 'package:country_flags/country_flags.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/locale_provider.dart';
import 'scale_button.dart';

/// Selector de idioma con banderas. Cada botón cambia el locale de la app.
class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider).value ?? const Locale('es');
    final setLocale = ref.read(localeProvider.notifier).setLocale;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FlagButton(
          countryCode: 'ES',
          label: 'Español',
          selected: current.languageCode == 'es',
          onTap: () => setLocale(const Locale('es')),
        ),
        const SizedBox(width: 20),
        _FlagButton(
          countryCode: 'US',
          label: 'English',
          selected: current.languageCode == 'en',
          onTap: () => setLocale(const Locale('en')),
        ),
      ],
    );
  }
}

class _FlagButton extends StatelessWidget {
  const _FlagButton({
    required this.countryCode,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String countryCode;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: ScaleButton(
        selected: selected,
        onPressed: onTap,
        selectedScale: 1.15,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? Colors.white : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CountryFlag.fromCountryCode(
              countryCode,
              theme: ImageTheme(
                width: 56,
                height: 38,
                shape: const RoundedRectangle(8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
