import 'dart:io';

import 'package:material_ui/material_ui.dart';

/// Muestra una imagen de logotipo: desde un asset del bundle (`assets/...`) o
/// desde un archivo local (imagen subida por el usuario).
class LogoImage extends StatelessWidget {
  const LogoImage({
    super.key,
    required this.logo,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
  });

  final String logo;
  final double? height;
  final double? width;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (logo.startsWith('assets/')) {
      return Image.asset(logo, height: height, width: width, fit: fit);
    }
    return Image.file(
      File(logo),
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}
