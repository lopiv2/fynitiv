import 'dart:io';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// Muestra una imagen de logotipo: asset del bundle (`assets/...`), archivo
/// local o URL, en PNG/WebP/JPG o SVG.
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

  static bool _isSvg(String value) {
    final clean = value.split('?').first.toLowerCase();
    return clean.endsWith('.svg');
  }

  @override
  Widget build(BuildContext context) {
    if (_isSvg(logo)) {
      if (logo.startsWith('assets/')) {
        return SvgPicture.asset(
          logo,
          height: height,
          width: width,
          fit: fit,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
      }
      if (logo.startsWith('http://') || logo.startsWith('https://')) {
        return SvgPicture.network(
          logo,
          height: height,
          width: width,
          fit: fit,
          placeholderBuilder: (_) => const SizedBox.shrink(),
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
      }
      return SvgPicture.file(
        File(logo),
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    if (logo.startsWith('assets/')) {
      return Image.asset(
        logo,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    if (logo.startsWith('http://') || logo.startsWith('https://')) {
      return Image.network(
        logo,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
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
