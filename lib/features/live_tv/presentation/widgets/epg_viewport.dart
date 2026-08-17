import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Estado único que gobierna la EPG: qué se pinta y dónde. No hay
/// ScrollControllers que sincronizar; todo se deriva de aquí.
class EpgViewportController extends ChangeNotifier {
  EpgViewportController({
    this.pixelsPerMinute = 2.6,
    this.channelRowHeight = 52,
    this.leftRailWidth = 150,
    this.headerHeight = 28,
  });

  double pixelsPerMinute;
  double channelRowHeight;
  double leftRailWidth;
  double headerHeight;

  /// Desplazamientos del contenido (px).
  double horizontalOffset = 0;
  double verticalOffset = 0;

  /// Anclaje temporal del inicio de la ventana completa de la guía (UTC).
  late DateTime baseTime = DateTime.now().toUtc().subtract(
    const Duration(hours: 1),
  );

  /// Duración de la ventana completa de la guía.
  static const int windowMinutes = 5 * 60;

  DateTime get endTime => baseTime.add(const Duration(minutes: windowMinutes));

  int channelCount = 0;

  double get totalWidth => windowMinutes * pixelsPerMinute;
  double get totalHeight => channelCount * channelRowHeight;

  /// Tamaño del área visible de la rejilla.
  double viewportWidth = 0;
  double viewportHeight = 0;

  // ── Mapeo ──────────────────────────────────────────────────────────────

  double timeToX(DateTime utc) =>
      utc.difference(baseTime).inMinutes * pixelsPerMinute;

  DateTime xToTime(double x) =>
      baseTime.add(Duration(minutes: (x / pixelsPerMinute).round()));

  double channelToY(int index) => index * channelRowHeight;

  int? channelAtY(double y) {
    if (y < 0) return null;
    final index = (y / channelRowHeight).floor();
    return (index >= 0 && index < channelCount) ? index : null;
  }

  // ── Rangos visibles (solo lo que se pinta + buffer) ────────────────────

  double get _maxX => math.max(0.0, totalWidth - viewportWidth);
  double get _maxY => math.max(0.0, totalHeight - viewportHeight);

  double get visibleLeft => horizontalOffset.clamp(0.0, _maxX);
  double get visibleTop => verticalOffset.clamp(0.0, _maxY);

  int get firstVisibleChannel =>
      (visibleTop / channelRowHeight).floor().clamp(0, channelCount - 1);
  int get lastVisibleChannel =>
      ((visibleTop + viewportHeight) / channelRowHeight)
          .ceil()
          .clamp(0, channelCount - 1);

  DateTime get visibleStart => xToTime(visibleLeft);
  DateTime get visibleEnd => xToTime(visibleLeft + viewportWidth);

  // ── Acciones ───────────────────────────────────────────────────────────

  /// Actualiza el tamaño del área visible. No notifica: se llama durante el
  /// build (LayoutBuilder) y los painters se repintan solos al cambiar de
  /// tamaño.
  void setViewportSize(double width, double height) {
    viewportWidth = width;
    viewportHeight = height;
  }

  void panBy(double dx, double dy) {
    horizontalOffset = (horizontalOffset + dx).clamp(0.0, _maxX);
    verticalOffset = (verticalOffset + dy).clamp(0.0, _maxY);
    notifyListeners();
  }

  /// Zoom manteniendo estable el punto focal (por defecto el centro).
  void zoomBy(double factor, {double? focalX}) {
    if (factor <= 0) return;
    final oldPpm = pixelsPerMinute;
    pixelsPerMinute = (pixelsPerMinute * factor).clamp(1.0, 12.0);
    final fx = focalX ?? viewportWidth / 2;
    final worldX = horizontalOffset + fx;
    horizontalOffset =
        (worldX * (pixelsPerMinute / oldPpm) - fx).clamp(0.0, _maxX);
    notifyListeners();
  }
}
