import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/horizontal_scroll_behavior.dart';
import 'poster_card.dart';

/// Fila horizontal de tarjetas con un título (estilo Prime/Disney).
///
/// La rueda del ratón sigue desplazando la página (arriba/abajo); para
/// desplazar la fila en horizontal se muestran flechas al hacer hover y se
/// puede arrastrar con el ratón.
class ContentRow extends StatefulWidget {
  const ContentRow({
    super.key,
    required this.title,
    required this.items,
    required this.serverUrl,
    this.height = 270,
    this.cardWidth = 150,
    this.useBackdrop = false,
    this.cardLogo,
  });

  final String title;
  final List<BaseItemDto> items;
  final String? serverUrl;

  /// Alto de la fila.
  final double height;

  /// Ancho de cada tarjeta (póster vertical).
  final double cardWidth;

  /// Muestra tarjetas horizontales (backdrop 16:9) en lugar de pósteres.
  final bool useBackdrop;

  /// Logotipo superpuesto abajo a la derecha de cada tarjeta (asset o ruta).
  final String? cardLogo;

  @override
  State<ContentRow> createState() => _ContentRowState();
}

class _ContentRowState extends State<ContentRow> {
  final ScrollController _controller = ScrollController();
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    // Actualiza la visibilidad de las flechas al desplazarse (drag o animación).
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (mounted) setState(() {});
  }

  /// Ancho de cada tarjeta. Con backdrop se deriva del alto de la fila para
  /// que la imagen 16:9 + título + progreso quepan sin recortarse.
  double get _cardWidth {
    if (!widget.useBackdrop) return widget.cardWidth;
    final imageHeight = widget.height - 64;
    return imageHeight * 16 / 9;
  }

  /// Separación entre tarjetas.
  double get _spacing => widget.useBackdrop ? 20 : 12;

  bool get _canScrollLeft =>
      _controller.hasClients &&
      _controller.offset > _controller.position.minScrollExtent;

  bool get _canScrollRight =>
      _controller.hasClients &&
      _controller.offset < _controller.position.maxScrollExtent;

  void _scrollBy(double delta) {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final target = (_controller.offset + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  /// Flecha lateral con fade, visible al hacer hover sobre la fila (si queda
  /// contenido por desplazar en esa dirección).
  Widget _buildArrow({
    required IconData icon,
    required bool visible,
    required VoidCallback onTap,
    required Alignment align,
    required EdgeInsets padding,
  }) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: Align(
            alignment: align,
            child: Padding(
              padding: padding,
              child: _RowArrow(icon: icon, onTap: onTap),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final leftArrowVisible = _hovered && _canScrollLeft;
    final rightArrowVisible = _hovered && _canScrollRight;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: widget.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ScrollConfiguration(
                  behavior: const HorizontalScrollBehavior(),
                  child: ListView.separated(
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: widget.items.length,
                    separatorBuilder: (_, _) => SizedBox(width: _spacing),
                    itemBuilder: (context, i) => SizedBox(
                      width: _cardWidth,
                      child: widget.useBackdrop
                          ? BackdropCard(
                              item: widget.items[i],
                              serverUrl: widget.serverUrl,
                              cardLogo: widget.cardLogo,
                            )
                          : PosterCard(
                              item: widget.items[i],
                              serverUrl: widget.serverUrl,
                              cardLogo: widget.cardLogo,
                            ),
                    ),
                  ),
                ),
                _buildArrow(
                  icon: Icons.chevron_left,
                  visible: leftArrowVisible,
                  onTap: () => _scrollBy(-_cardWidth - _spacing),
                  align: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 8),
                ),
                _buildArrow(
                  icon: Icons.chevron_right,
                  visible: rightArrowVisible,
                  onTap: () => _scrollBy(_cardWidth + _spacing),
                  align: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 8),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Flecha lateral de desplazamiento de la fila.
class _RowArrow extends StatelessWidget {
  const _RowArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white38),
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }
}
