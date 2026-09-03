import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../skin/skin.dart';

/// Cabecera genérica para páginas de grilla/biblioteca.
///
/// Muestra el título de donde viene la navegación (ej. "Colecciones",
/// "Películas", "Series") y un botón de volver. Pensado para usarse en
/// [LibraryViewScreen] y cualquier otra página con grid que necesite un
/// título dinámico.
///
/// El título lo resuelve quien navega (ej. `view.name` de Jellyfin), este
/// widget solo lo presenta con el estilo unificado.
class LibraryPageHeader extends StatelessWidget {
  const LibraryPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.showBack = true,
  });

  /// Título principal (ej. Colecciones, Películas).
  final String title;

  /// Subtítulo opcional bajo el título (ej. conteo).
  final String? subtitle;

  /// Acción personalizada al pulsar volver. Por defecto hace pop o va a /home.
  final VoidCallback? onBack;

  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final effectiveTitle = title.trim().isEmpty ? l10n.library : title.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 24, 4),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              tooltip: l10n.back,
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed:
                  onBack ??
                  () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  effectiveTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Calcula el offset superior necesario para que el contenido con grid
/// no quede debajo de la barra superior (anclada o flotante).
///
/// - Si `skin.sidebarPosition == top` (isla flotante o barra Prime anclada)
///   la barra está superpuesta con `Stack` en [HomeShell], por lo que el
///   contenido necesita `MediaQuery.padding.top + altura de barra`.
/// - Para barras laterales (left/right/bottom) solo respeta el safe area.
///
/// Usar como `SizedBox(height: libraryPageTopPadding(context, skin))`
/// al inicio de la columna antes del [LibraryPageHeader].
double libraryPageTopPadding(BuildContext context, Skin? skin) {
  final mqTop = MediaQuery.of(context).padding.top;
  final isTop = skin?.sidebarPosition == SidebarPosition.top;
  if (isTop) {
    // Barra superior: 60px de altura + 16px aprox de márgenes + safe area.
    // Coincide con `AllMoviesScreen` (topPadding+70+8) y `HomeShell`.
    final isFloating = skin?.topBarFloating ?? false;
    // Isla flotante y barra anclada comparten altura visual ~60.
    // Usamos 78 (70+8) como base segura para ambas variantes.
    return mqTop + (isFloating ? 78 : 76);
  }
  // Sin barra superior: solo safe area + pequeño respiro.
  return mqTop > 0 ? mqTop + 8 : 8;
}
