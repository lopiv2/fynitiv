import 'package:material_ui/material_ui.dart';

/// Recuadro de edad recomendada del contenido, coloreado según el rango. Es el
/// mismo elemento que usa el slider de novedades y se reutiliza donde haga
/// falta (p. ej. en la hovercard de las tarjetas al hacer hover).
class AgeRatingBadge extends StatelessWidget {
  const AgeRatingBadge({super.key, required this.rating});

  final String rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ageRatingColor(rating),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        rating,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Color del recuadro según la edad recomendada del contenido.
Color ageRatingColor(String rating) {
  final r = rating.trim().toUpperCase();
  final numMatch = RegExp(r'(\d+)').firstMatch(r);
  if (numMatch != null) {
    final age = int.parse(numMatch.group(1)!);
    if (age >= 18) return const Color(0xFFE53935); // rojo
    if (age >= 16) return const Color(0xFFFB8C00); // naranja
    if (age >= 12) return const Color(0xFFFDD835); // amarillo
    if (age >= 7) return const Color(0xFF43A047); // verde
    return const Color(0xFF43A047);
  }
  if (r.contains('MA') ||
      r.contains('NC-17') ||
      r.contains('NC17') ||
      r == 'R' ||
      r.contains('18')) {
    return const Color(0xFFE53935);
  }
  if (r.contains('14') || r.contains('PG-13') || r.contains('PG13')) {
    return const Color(0xFFFB8C00);
  }
  if (r.contains('PG') || r.contains('12') || r.contains('16')) {
    return const Color(0xFFFDD835);
  }
  if (r.contains('G') || r.contains('TV-Y') || r.contains('EC')) {
    return const Color(0xFF43A047);
  }
  return const Color(0xFF546E7A); // azul grisáceo por defecto
}
