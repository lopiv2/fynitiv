import 'package:material_ui/material_ui.dart';

import '../constants/ui_constants.dart';

/// Línea "Etiqueta: valor" para fichas (nacimiento, fallecimiento...).
/// Compartida por la pantalla de persona y la de artista.
class MetaLine extends StatelessWidget {
  const MetaLine({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white70, fontSize: 18),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

/// Bloque de texto de ficha: título opcional + cuerpo + líneas de datos.
/// Lo usan el tab Sobre del artista y la biografía de la persona.
class InfoBody extends StatelessWidget {
  const InfoBody({
    super.key,
    this.title,
    required this.body,
    this.footnotes = const [],
    this.fontSize = kBioFontSize,
  });

  final String? title;
  final String body;
  final List<String> footnotes;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null && title!.isNotEmpty) ...[
          Text(
            title!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextSelectionTheme(
          data: const TextSelectionThemeData(
            selectionColor: Color(0xFF2B7FFF),
            selectionHandleColor: Colors.white,
            cursorColor: Colors.white,
          ),
          child: SelectableText(
            body,
            style: TextStyle(
              color: Colors.white70,
              fontSize: fontSize,
              height: 1.55,
            ),
          ),
        ),
        if (footnotes.isNotEmpty) ...[
          const SizedBox(height: 20),
          for (int i = 0; i < footnotes.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == footnotes.length - 1 ? 0 : 6,
              ),
              child: Text(
                footnotes[i],
                style: const TextStyle(color: Colors.white54, fontSize: 18),
              ),
            ),
        ],
      ],
    );
  }
}
