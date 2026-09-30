// game_box3d_scene_viewer.dart — visor 3D de portada con flutter_scene.
//
// Construye la caja como 6 planos (uno por cara) con `UnlitMaterial`, que
// reproduce el aspecto plano del 2D. Incluye toggle 2D/3D y fallback 2D
// cuando no hay carátula o falla el visor.
//
// NO usa el pipeline de assets de flutter_scene: las carátulas llegan de ROMM
// en runtime con Bearer, así que se decodifican a `ui.Image` y se suben con
// `Texture2D.fromImage`.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scene/scene.dart' as scene;
import 'package:material_ui/material_ui.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../../../core/navigation/platform_mode.dart';
import '../../../../core/settings/cover3d_material.dart';
import '../../../../core/widgets/app_hover.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/romm_providers.dart';
import '../../domain/box_model.dart';
import '../../domain/romm_game.dart';

/// Visor de portada 2D/3D con `flutter_scene`.
class GameCoverViewerScene extends ConsumerStatefulWidget {
  const GameCoverViewerScene({
    super.key,
    required this.game,
    required this.headers,
    required this.width,
    required this.height,
    this.autoRotate = true,
  });

  final RommGame game;
  final Map<String, String>? headers;
  final double width;
  final double height;
  final bool autoRotate;

  @override
  ConsumerState<GameCoverViewerScene> createState() =>
      _GameCoverViewerSceneState();
}

class _GameCoverViewerSceneState extends ConsumerState<GameCoverViewerScene>
    with SingleTickerProviderStateMixin {
  scene.Scene? _scene;
  /// Material con el que se construyó la escena actual (para reconstruir si
  /// el usuario lo cambia desde Ajustes mientras el detalle sigue vivo).
  Cover3dMaterial? _builtMaterial;
  late bool _show3D;
  bool _loading = true;
  bool _ready = false;
  bool _failed = false;

  /// Ángulo horizontal de la órbita (radianes), arrastrable con el ratón.
  double _yaw = 0.0;
  /// Ángulo vertical de la órbita (radianes). 0 = estado inicial; se
  /// devuelve a 0 animado al soltar el ratón.
  double _pitch = 0.0;
  bool _dragging = false;
  /// Último `elapsed` de `cameraBuilder` para integrar la auto-rotación por
  /// delta (así no salta al parar el arrastre).
  Duration _lastElapsed = Duration.zero;

  /// Animación que devuelve `_pitch` a 0 (estado inicial) al soltar.
  late final AnimationController _settleController;
  double _settleFromPitch = 0.0;

  static const double _maxPitch = 1.5; // ~86°, evita el polo de la cámara

  @override
  void initState() {
    super.initState();
    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..addListener(() {
        final t = Curves.easeOutCubic.transform(_settleController.value);
        setState(() => _pitch = _settleFromPitch * (1 - t));
      });
    _show3D = widget.game.can3D;
    if (_show3D) unawaited(_build(ref.read(cover3dMaterialProvider)));
  }

  @override
  void didUpdateWidget(GameCoverViewerScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.id != widget.game.id) {
      _scene = null;
      _ready = false;
      _failed = false;
      _loading = true;
      _show3D = widget.game.can3D;
      _settleController.stop();
      _pitch = 0;
      _dragging = false;
      setState(() {});
      if (_show3D) unawaited(_build(ref.read(cover3dMaterialProvider)));
    }
  }

  @override
  void dispose() {
    _settleController.dispose();
    super.dispose();
  }

  /// Dimensiones de la caja según el modelo de la plataforma (cartucho, CD,
  /// DVD, caja grande…). Todas comparten altura; cambian ancho y grosor.
  List<double> _boxSizeFor(String slug) => BoxModel.forSlug(slug).size;

  String _sanitizeUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    try {
      final uri = Uri.parse(trimmed);
      if (uri.hasQuery) {
        return uri.replace(queryParameters: uri.queryParameters).toString();
      }
      return trimmed;
    } catch (_) {
      return trimmed.replaceAll(' ', '%20');
    }
  }

  /// Descarga una cara con Bearer y la sube como textura de `flutter_scene`.
  ///
  /// Con [rejectPlaceholder] se descartan imágenes casi planas o monótonas
  /// (p. ej. el placeholder verde que sirve ROMM cuando falta la trasera), de
  /// modo que la cara caiga al color de respaldo.
  Future<scene.Texture2D?> _loadTexture(
    String url, {
    bool rejectPlaceholder = false,
  }) async {
    final clean = _sanitizeUrl(url);
    if (clean.isEmpty) return null;
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) return null;
    try {
      final bytes = await repo.downloadAssetBytes(
        clean,
        headers: widget.headers,
      );
      if (bytes == null || bytes.isEmpty) return null;
      final image = await scene.imageFromBytes(Uint8List.fromList(bytes));
      try {
        if (rejectPlaceholder && await _looksLikePlaceholder(image)) {
          return null;
        }
        return await scene.Texture2D.fromImage(image);
      } finally {
        image.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  /// Heurística de placeholder: imagen casi uniforme (baja desviación) o
  /// claramente dominada por un tono (p. ej. verde plano). Una carátula real
  /// tiene mucha más variación.
  Future<bool> _looksLikePlaceholder(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return false;
    final px = data.buffer.asUint8List();
    if (px.length < 4 * 4) return true;
    var n = 0;
    double sr = 0, sg = 0, sb = 0, sr2 = 0, sg2 = 0, sb2 = 0;
    // 1 de cada 16 píxeles (paso 64 bytes) basta para la estadística.
    for (var i = 0; i + 4 <= px.length; i += 64) {
      final r = px[i].toDouble();
      final g = px[i + 1].toDouble();
      final b = px[i + 2].toDouble();
      sr += r;
      sg += g;
      sb += b;
      sr2 += r * r;
      sg2 += g * g;
      sb2 += b * b;
      n++;
    }
    if (n == 0) return true;
    double dev(double s, double s2, double m) {
      final v = (s2 / n) - m * m;
      return v <= 0 ? 0 : math.sqrt(v);
    }

    final mr = sr / n, mg = sg / n, mb = sb / n;
    final spread = (dev(sr, sr2, mr) + dev(sg, sg2, mg) + dev(sb, sb2, mb)) / 3;
    final greenDominant = mg > mr * 1.15 && mg > mb * 1.15;
    if (spread < 16.0) return true; // casi plana
    if (greenDominant && spread < 70.0) return true; // degradado verde
    return false;
  }

  /// Material de color sólido (cantos y caras sin textura) según el tipo
  /// elegido: plano (`UnlitMaterial`) o PBR con su metallic/roughness.
  scene.Material _solid(int argb, Cover3dMaterial kind) {
    if (kind.isUnlit) {
      return scene.UnlitMaterial()..baseColorFactor = _linearFromArgb(argb);
    }
    return scene.PhysicallyBasedMaterial()
      ..baseColorFactor = _linearFromArgb(argb)
      ..metallicFactor = kind.metallic
      ..roughnessFactor = kind.roughness
      ..vertexColorWeight = 0;
  }

  /// Material texturizado para las caras con carátula/lomo.
  scene.Material _texturedMat(scene.Texture2D tex, Cover3dMaterial kind) {
    if (kind.isUnlit) {
      return scene.UnlitMaterial(colorTexture: tex)..vertexColorWeight = 0;
    }
    return scene.PhysicallyBasedMaterial(baseColorTexture: tex)
      ..metallicFactor = kind.metallic
      ..roughnessFactor = kind.roughness
      ..vertexColorWeight = 0;
  }

  /// Gris neutro plano para la cara trasera sin arte. Sin iluminación para
  /// que nunca coja tinte del entorno (era la causa del tono verdoso).
  scene.Material _backFallbackMat() {
    return scene.UnlitMaterial()..baseColorFactor = _linearFromArgb(0xFF808080);
  }

  static vm.Vector4 _linearFromArgb(int argb) {
    double ch(int v) {
      final c = v / 255;
      return c <= 0.04045
          ? c / 12.92
          : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    final a = (argb >> 24) & 0xFF;
    return vm.Vector4(
      ch((argb >> 16) & 0xFF),
      ch((argb >> 8) & 0xFF),
      ch(argb & 0xFF),
      a == 0 ? 1.0 : a / 255,
    );
  }

  Future<void> _build(Cover3dMaterial kind) async {
    final g = widget.game;
    try {
      await scene.Scene.initializeStaticResources();

      final frontUrl = (g.coverLargeUrl?.isNotEmpty == true
          ? g.coverLargeUrl!
          : (g.coverSmallUrl ?? ''));

      final textures = await Future.wait([
        _loadTexture(frontUrl),
        _loadTexture(g.coverBackUrl ?? '', rejectPlaceholder: true),
        _loadTexture(g.coverSpineUrl ?? '', rejectPlaceholder: true),
      ]);
      if (!mounted) return;

      final front = textures[0];
      final back = textures[1];
      final spine = textures[2];

      if (front == null) {
        setState(() {
          _loading = false;
          _failed = true;
          _show3D = false;
        });
        return;
      }

      final size = _boxSizeFor(g.platformSlug);
      final w = size[0];
      final h = size[1];
      final d = size[2];
      final hw = w / 2;
      final hh = h / 2;
      final hd = d / 2;

      // Color de los cantos: marrón corporativo; el lomo texturizado los cubre.
      final edge = _solid(0xFF2B1D12, kind);
      // Sin carátula trasera: gris neutro y sin reflejos (mate) para que no
      // coja el tinte del entorno; en modo plano, gris plano.
      final backFallback = _backFallbackMat();

      scene.Material faceMat(scene.Texture2D? tex, scene.Material fallback) =>
          tex == null ? fallback : _texturedMat(tex, kind);

      // Cara como quad con UV (0,0)-(1,1) y normal propia. `bl`, `br`, `tr`,
      // `tl` en orden antihorario visto desde fuera. Winding de los triángulos
      // invertido (0,2,1)/(0,3,2): el culling de flutter_scene usa CCW como
      // frente con la convención de winding del engine, no la de pantalla.
      scene.Geometry quad(
        vm.Vector3 bl,
        vm.Vector3 br,
        vm.Vector3 tr,
        vm.Vector3 tl,
        vm.Vector3 n,
      ) {
        return (scene.GeometryBuilder(deduplicate: false)
              ..normal(n)
              ..texCoord(vm.Vector2(0, 0))
              ..addVertex(bl)
              ..texCoord(vm.Vector2(1, 0))
              ..addVertex(br)
              ..texCoord(vm.Vector2(1, 1))
              ..addVertex(tr)
              ..texCoord(vm.Vector2(0, 1))
              ..addVertex(tl)
              ..addTriangle(0, 2, 1)
              ..addTriangle(0, 3, 2))
            .build();
      }

      scene.Node faceNode(String name, scene.Geometry g, scene.Material mat) =>
          scene.Node(name: name, mesh: scene.Mesh(g, mat));

      final s = scene.Scene();
      final box = scene.Node(name: 'box')
        ..localTransform = vm.Matrix4.rotationZ(math.pi);

      // Frontal (+Z): esquinas CCW vistas desde +Z.
      box.add(
        faceNode(
          'front',
          quad(
            vm.Vector3(-hw, -hh, hd),
            vm.Vector3(hw, -hh, hd),
            vm.Vector3(hw, hh, hd),
            vm.Vector3(-hw, hh, hd),
            vm.Vector3(0, 0, 1),
          ),
          faceMat(front, edge),
        ),
      );
      // Trasera (-Z).
      box.add(
        faceNode(
          'back',
          quad(
            vm.Vector3(hw, -hh, -hd),
            vm.Vector3(-hw, -hh, -hd),
            vm.Vector3(-hw, hh, -hd),
            vm.Vector3(hw, hh, -hd),
            vm.Vector3(0, 0, -1),
          ),
          faceMat(back, backFallback),
        ),
      );
      // Laterales (±X) con el lomo si existe.
      final sideMat = spine == null ? edge : _texturedMat(spine, kind);
      box.add(
        faceNode(
          'right',
          quad(
            vm.Vector3(hw, -hh, hd),
            vm.Vector3(hw, -hh, -hd),
            vm.Vector3(hw, hh, -hd),
            vm.Vector3(hw, hh, hd),
            vm.Vector3(1, 0, 0),
          ),
          sideMat,
        ),
      );
      box.add(
        faceNode(
          'left',
          quad(
            vm.Vector3(-hw, -hh, -hd),
            vm.Vector3(-hw, -hh, hd),
            vm.Vector3(-hw, hh, hd),
            vm.Vector3(-hw, hh, -hd),
            vm.Vector3(-1, 0, 0),
          ),
          sideMat,
        ),
      );
      // Superior (+Y) e inferior (-Y) en sólido.
      box.add(
        faceNode(
          'top',
          quad(
            vm.Vector3(-hw, hh, -hd),
            vm.Vector3(-hw, hh, hd),
            vm.Vector3(hw, hh, hd),
            vm.Vector3(hw, hh, -hd),
            vm.Vector3(0, 1, 0),
          ),
          edge,
        ),
      );
      box.add(
        faceNode(
          'bottom',
          quad(
            vm.Vector3(-hw, -hh, hd),
            vm.Vector3(-hw, -hh, -hd),
            vm.Vector3(hw, -hh, -hd),
            vm.Vector3(hw, -hh, hd),
            vm.Vector3(0, -1, 0),
          ),
          edge,
        ),
      );

      s.add(box);

      setState(() {
        _scene = s;
        _builtMaterial = kind;
        _loading = false;
        _ready = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
        _show3D = false;
      });
    }
  }

  String get _fallback2D {
    final g = widget.game;
    if (g.coverLargeUrl != null && g.coverLargeUrl!.isNotEmpty) {
      return g.coverLargeUrl!;
    }
    if (g.coverSmallUrl != null && g.coverSmallUrl!.isNotEmpty) {
      return g.coverSmallUrl!;
    }
    return g.box3dUrl ?? '';
  }

  void _onToggle(bool to3D) {
    if (to3D == _show3D) return;
    if (!to3D) {
      setState(() => _show3D = false);
      return;
    }
    setState(() => _show3D = true);
    if (_scene == null) {
      _failed = false;
      _loading = true;
      unawaited(_build(ref.read(cover3dMaterialProvider)));
    }
  }

  void _onPanStart(DragStartDetails d) {
    _settleController.stop();
    setState(() => _dragging = true);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    // Incremental (delta), no posición absoluta: un clic sin arrastre no
    // mueve la carátula y el gesto sigue el movimiento real del ratón.
    setState(() {
      _yaw += (d.delta.dx / widget.width) * math.pi;
      _pitch = (_pitch + (d.delta.dy / widget.height) * math.pi)
          .clamp(-_maxPitch, _maxPitch);
    });
  }

  void _onPanEnd(DragEndDetails d) {
    _settleFromPitch = _pitch;
    _dragging = false;
    _settleController.forward(from: 0);
  }

  void _nudge(double dx) {
    _settleController.stop();
    setState(() => _yaw += dx);
  }

  void _nudgePitch(double dy) {
    _settleController.stop();
    setState(() {
      _pitch = (_pitch + dy).clamp(-_maxPitch, _maxPitch);
    });
    _settleFromPitch = _pitch;
    _settleController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final can3D = widget.game.can3D;
    final isTv =
        (ref.watch(platformModeProvider).value ?? PlatformMode.mobile) ==
        PlatformMode.tv;
    final material = ref.watch(cover3dMaterialProvider);

    // El usuario cambió el material (Ajustes) con la escena viva: reconstruye.
    if (_show3D && _scene != null && _builtMaterial != material) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _builtMaterial == material) return;
        setState(() {
          _scene = null;
          _ready = false;
          _failed = false;
          _loading = true;
        });
        unawaited(_build(material));
      });
    }

    Widget viewer;
    if (_show3D && !_failed && _scene != null) {
      viewer = _build3D();
    } else if (_show3D && _loading) {
      viewer = _frame(
        child: Container(
          color: const Color(0xFF0B1220),
          child: const Center(child: AppLoader()),
        ),
      );
    } else {
      viewer = _build2D();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        viewer,
        if (can3D) ...[
          SizedBox(height: isTv ? 12 : 10),
          _ViewToggle(
            show3D: _show3D,
            label2D: l10n.gameView2D,
            label3D: l10n.gameView3D,
            onChanged: _onToggle,
            isTv: isTv,
          ),
        ],
      ],
    );
  }

  Widget _build2D() {
    final url = _fallback2D;
    return _frame(
      child: url.isNotEmpty
          ? _ValidatedCoverImage(
              key: ValueKey(url),
              url: url,
              headers: widget.headers,
              game: widget.game,
            )
          : _CoverFallback(game: widget.game),
    );
  }

  Widget _build3D() {
    final scene3d = _scene!;
    return _frame(
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _nudge(0.25);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _nudge(-0.25);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _nudgePitch(0.2);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _nudgePitch(-0.2);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onPanCancel: () {
            if (_dragging) _onPanEnd(DragEndDetails());
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              scene.SceneView(
                scene3d,
                cameraBuilder: (elapsed) {
                  // Auto-rotación por delta (no por tiempo absoluto) para
                  // que continuar tras un arrastre no dé un salto.
                  final dt =
                      (elapsed - _lastElapsed).inMicroseconds / 1e6;
                  _lastElapsed = elapsed;
                  if (widget.autoRotate && !_dragging) {
                    _yaw += dt.clamp(0.0, 0.1) * 0.35;
                  }
                  // Órbita esférica: yaw horizontal + pitch vertical. Con
                  // pitch 0 coincide con el estado inicial (un solo eje).
                  const radius = 3.5;
                  final cp = math.cos(_pitch);
                  final cam = scene.PerspectiveCamera(
                    position: vm.Vector3(
                      math.sin(_yaw) * cp * radius,
                      0.3 + math.sin(_pitch) * radius,
                      math.cos(_yaw) * cp * radius,
                    ),
                    target: vm.Vector3(0, 0.05, 0),
                  )..fovRadiansY = 0.5;
                  return cam;
                },
                loadingBuilder: (context, progress) =>
                    const Center(child: AppLoader()),
              ),
              if (!_ready)
                Container(
                  color: const Color(0xFF0B1220),
                  child: const Center(child: AppLoader()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _frame({required Widget child}) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRRect(borderRadius: BorderRadius.circular(3), child: child),
    );
  }
}

/// Toggle 2D/3D (mismo estilo que el antiguo visor `three_js`).
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.show3D,
    required this.label2D,
    required this.label3D,
    required this.onChanged,
    this.isTv = false,
  });

  final bool show3D;
  final String label2D;
  final String label3D;
  final ValueChanged<bool> onChanged;
  final bool isTv;

  @override
  Widget build(BuildContext context) {
    final segRadius = BorderRadius.circular(isTv ? 10 : 8);
    final hPad = isTv ? 20.0 : 14.0;
    final vPad = isTv ? 12.0 : 7.0;
    final fontSize = isTv ? 15.0 : 12.0;

    Widget seg(String label, bool active, VoidCallback onTap) {
      return AppHover(
        effect: AppHoverEffect.highlightWithScale,
        config: AppHoverConfig(
          borderRadius: segRadius,
          highlightNormal: active ? Colors.white : Colors.transparent,
          highlightHovered: active ? const Color(0xFFE6E6E6) : Colors.white10,
          scale: isTv ? 1.08 : 1.04,
        ),
        onTap: onTap,
        playSoundOnHover: false,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: segRadius,
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.black : Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(isTv ? 12 : 10),
        border: Border.all(color: Colors.white12),
      ),
      padding: EdgeInsets.all(isTv ? 5 : 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg(label2D, !show3D, () => onChanged(false)),
          SizedBox(width: isTv ? 6 : 4),
          seg(label3D, show3D, () => onChanged(true)),
        ],
      ),
    );
  }
}

/// Carátula 2D descargada con Bearer y validada (fallback a `_CoverFallback`).
class _ValidatedCoverImage extends ConsumerStatefulWidget {
  const _ValidatedCoverImage({
    super.key,
    required this.url,
    required this.headers,
    required this.game,
  });

  final String url;
  final Map<String, String>? headers;
  final RommGame game;

  @override
  ConsumerState<_ValidatedCoverImage> createState() =>
      _ValidatedCoverImageState();
}

class _ValidatedCoverImageState extends ConsumerState<_ValidatedCoverImage> {
  late final Future<Uint8List?> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _fetch();
  }

  Future<Uint8List?> _fetch() async {
    try {
      final repo = ref.read(rommRepositoryProvider);
      if (repo == null) return null;
      final bytes = await repo.downloadAssetBytes(
        widget.url,
        headers: widget.headers,
      );
      if (bytes == null || bytes.isEmpty) return null;
      return Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(color: const Color(0xFF0B1220));
        }
        final data = snapshot.data;
        if (data == null || data.isEmpty) {
          return _CoverFallback(game: widget.game);
        }
        return Image.memory(
          data,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _CoverFallback(game: widget.game),
        );
      },
    );
  }
}

/// Placeholder con la inicial del juego cuando no hay carátula usable.
class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.game});
  final RommGame game;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A2568),
      alignment: Alignment.center,
      child: Text(
        game.name.isEmpty ? '?' : game.name.substring(0, 1).toUpperCase(),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

