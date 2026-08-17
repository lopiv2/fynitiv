import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fynitiv/core/skin/skin.dart';
import 'package:fynitiv/core/skin/skin_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('El skin se mantiene tras reiniciar la app', () async {
    SharedPreferences.setMockInitialValues({});

    // Primer arranque: aplicamos el preset Disney+.
    final first = ProviderContainer();
    addTearDown(first.dispose);
    await first.read(skinControllerProvider.future);
    await first.read(skinControllerProvider.notifier).applyPreset('disney_plus');
    expect(first.read(skinControllerProvider).value?.id, 'disney_plus');

    // "Reinicio": un ProviderContainer nuevo lee de nuevo las prefs.
    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    final restored = await restarted.read(skinControllerProvider.future);
    expect(restored.id, 'disney_plus');
    expect(restored.name, 'Disney+');
    expect(restored.showNewReleasesBanner, isTrue);
    expect(restored.bannerBorder, isTrue);
  });

  test('Un preset sin personalizar se rehidrata de la definición actual',
      () async {
    SharedPreferences.setMockInitialValues({});

    final first = ProviderContainer();
    addTearDown(first.dispose);
    await first.read(skinControllerProvider.future);
    await first.read(skinControllerProvider.notifier).applyPreset('amazon_prime');

    // Tras "reiniciar", el preset se re-deriva del código (p. ej. el factor
    // de logo de Amazon, aunque la snapshot antigua no lo tuviera).
    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    final restored = await restarted.read(skinControllerProvider.future);
    expect(restored.id, 'amazon_prime');
    expect(restored.bannerLogoWidthFactor, 0.60);
    expect(restored.bannerDotAlignment, SliderDotAlignment.center);
    expect(restored.bannerShowArrows, isTrue);
    expect(restored.bannerShowIncludedBadge, isTrue);
    expect(restored.bannerShowJellyfinLogo, isTrue);
    expect(restored.bannerHoverReveal, isTrue);
    expect(restored.bannerShowActions, isTrue);
    expect(restored.showTrailerInSlider, isTrue);
    expect(restored.bannerTransition, SliderTransition.fade);
    expect(restored.bannerArrowsOnHover, isTrue);
    expect(restored.sidebarPosition, SidebarPosition.top);
    expect(restored.sidebarSelectedColor, const Color(0xFF6B6B6B));
    expect(restored.bannerShowTitle, isFalse);
    expect(restored.bannerAttachedTop, isTrue);
    expect(restored.bannerShowAgeRating, isTrue);
    expect(restored.bannerContentScale, 1.5);
    expect(restored.bannerHeightFactor, 0.5);
    expect(restored.homeRowHeight, 340);
  });

  test('Un skin personalizado se persiste como snapshot completo', () async {
    SharedPreferences.setMockInitialValues({});

    final first = ProviderContainer();
    addTearDown(first.dispose);
    await first.read(skinControllerProvider.future);
    final base = await first.read(skinControllerProvider.future);
    await first
        .read(skinControllerProvider.notifier)
        .apply(base.copyWith(accent: const Color(0xFF123456)));

    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    final restored = await restarted.read(skinControllerProvider.future);
    expect(restored.accent, const Color(0xFF123456));
  });
}
