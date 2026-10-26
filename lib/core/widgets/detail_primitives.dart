import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';

/// Primitivas compartidas de las páginas de detalle (Prime).
///
/// Extraídas byte-idénticas de `ItemDetailScreen` y `BookDetailScreen` para
/// no duplicarlas. Fase 1 del detalle modular: solo presentación, sin lógica.
class DetailInfoCard extends StatelessWidget {
  const DetailInfoCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xE611151B),
        border: Border.all(color: Colors.white38),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Fila de crédito `Etiqueta  valor` (p. ej. `Director  Nolan`).
class DetailCreditRow extends StatelessWidget {
  const DetailCreditRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 16),
        children: [
          TextSpan(
            text: '$label  ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.white70,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloque de idioma/pista con enlace "más" (audio, subtítulos).
class DetailLanguageInfo extends StatelessWidget {
  const DetailLanguageInfo({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 22),
        const SizedBox(height: 10),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 16,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AppLocalizations.of(context)!.more,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            decoration: TextDecoration.underline,
          ),
        ),
      ],
    );
  }
}

/// Texto subrayado en negrita (géneros y enlaces).
class DetailLinkText extends StatelessWidget {
  const DetailLinkText({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        decoration: TextDecoration.underline,
      ),
    );
  }
}

/// Valor de metadato (año, duración, nota...).
class DetailInfoValue extends StatelessWidget {
  const DetailInfoValue({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white60,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Etiqueta pequeña (HD, etc.).
class DetailTag extends StatelessWidget {
  const DetailTag({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF454A51),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Nombres de personas filtrados por tipo (`Director`, `Producer`...).
String detailPeopleByType(List<BaseItemPerson> people, String type) {
  return people
      .where((person) => person.type?.name.toLowerCase() == type.toLowerCase())
      .map((person) => person.name ?? '')
      .where((name) => name.isNotEmpty)
      .join(', ');
}

/// Todos los nombres de personas (máx. 20), en orden.
String detailPeopleNames(List<BaseItemPerson> people) {
  return people
      .map((person) => person.name ?? '')
      .where((name) => name.isNotEmpty)
      .take(20)
      .join(', ');
}

/// Nombre de fichero seguro para descargas.
String detailDownloadFilename(String name) {
  final safeName = name
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return '${safeName.isEmpty ? 'video' : safeName}.mkv';
}
