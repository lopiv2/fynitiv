import '../../../../core/seasonal/seasonal_event.dart';
import '../../domain/splash_presentation.dart';
import 'christmas_splash_presentation.dart';
import 'default_splash_presentation.dart';
import 'halloween_splash_presentation.dart';

export '../../domain/splash_presentation.dart';

/// Presentación de splash para la estación [event].
///
/// Sin estación activa devuelve la de por defecto. San Valentín y Pascua
/// reutilizan la de por defecto hasta que tengan arte propio.
SplashPresentation splashPresentationFor(SeasonalEvent? event) =>
    switch (event) {
      null => kDefaultSplashPresentation,
      SeasonalEvent.halloween => kHalloweenSplashPresentation,
      SeasonalEvent.christmas => kChristmasSplashPresentation,
      SeasonalEvent.valentinesDay ||
      SeasonalEvent.easter => kDefaultSplashPresentation,
    };
