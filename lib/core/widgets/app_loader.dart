import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:material_ui/material_ui.dart';

/// Loader por defecto de la app (staggeredDotsWave).
///
/// Envuelve [LoadingAnimationWidget.staggeredDotsWave] para tener un único
/// punto donde cambiar la animación de carga en toda la app.
class AppLoader extends StatelessWidget {
  const AppLoader({
    super.key,
    this.color = Colors.white,
    this.size = 48,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return LoadingAnimationWidget.staggeredDotsWave(color: color, size: size);
  }
}
