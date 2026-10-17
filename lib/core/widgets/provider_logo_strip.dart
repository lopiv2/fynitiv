import 'package:material_ui/material_ui.dart';

/// Logos de proveedores mostrados en la esquina de una tarjeta.
class ProviderLogoStrip extends StatelessWidget {
  const ProviderLogoStrip({super.key, required this.urls, this.height = 36});

  final List<String> urls;

  /// Alto (y ancho) de cada logo.
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final url in urls.take(3))
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                url,
                width: height,
                height: height,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );
  }
}
