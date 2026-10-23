import 'package:flutter/widgets.dart';

/// FocusNode global para el botón Inicio de la isla/barra superior en TV.
/// Permite que el slider haga `↑` y vuelva a Inicio de forma determinista.
final tvInicioFocusNode = FocusNode(debugLabel: 'tvInicio');

/// FocusNode global para el primer botón de acción del slider (Ver ahora).
/// Permite que la isla haga `↓` y baje de forma determinista a los botones.
final tvSliderFirstActionFocusNode = FocusNode(debugLabel: 'tvSliderFirstAction');

/// FocusNode global para el banner del slider (nivel intermedio sin dots).
/// Permite que la barra haga `↓` al banner, donde ←/→ cambian de novedad.
final tvSliderBannerFocusNode = FocusNode(debugLabel: 'tvSliderBanner');
