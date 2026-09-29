// game_box3d_scene_viewer.dart — visor 3D alternativo con flutter_scene.
//
// Implementación paralela al visor `three_js` (`game_box3d_viewer.dart`) para
// comparar resultados sin tocar el existente. Construye la caja como 6 planos
// (uno por cara) con `UnlitMaterial`, que reproduce el aspecto plano del 2D.
//
// NO usa el pipeline de assets de flutter_scene: las carátulas llegan de ROMM
// en runtime con Bearer, así que se decodifican a `ui.Image` y se suben con
// `Texture2D.fromImage`.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scene/scene.dart' as scene;
import 'package:material_ui/material_ui.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../../../core/widgets/app_loader.dart';
import '../../application/romm_providers.dart';
import '../../domain/romm_game.dart';

/// Visor de portada 3D con `flutter_scene`. Misma superficie pública que
/// `GameCoverViewer` para poder intercambiarlos desde el detalle.
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

class _GameCoverViewerSceneState extends ConsumerState<GameCoverViewerScene> {
  scene.Scene? _scene;
  bool _loading = true;
  bool _ready = false;
  bool _failed = false;

  /// Ángulo horizontal de la órbita (radianes), arrastrable con el ratón.
  double _yaw = 0.0;
  double _yawStart = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_build());
  }

  @override
  void didUpdateWidget(GameCoverViewerScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.id != widget.game.id) {
      _scene = null;
      _ready = false;
      _failed = false;
      _loading = true;
      setState(() {});
      unawaited(_build());
    }
  }

  List<double> _boxSizeFor(String slug) {
    const thin = {
      'ps',
      'psx',
      'ps1',
      'ps2',
      'saturn',
      'dreamcast',
      'psp',
      'psvita',
      'segacd',
      'sega-cd',
      '3do',
      'cdi',
      'pcengine',
      'turbografx16',
      'neogeocd',
    };
    const thick = {
      'nes',
      'snes',
      'n64',
      'gb',
      'gbc',
      'gba',
      'genesis',
      'megadrive',
      'mastersystem',
      'gamegear',
      'lynx',
      'ngp',
      'ngpc',
      'nds',
      'n3ds',
      'vb',
    };
    final s = slug.trim().toLowerCase();
    if (thin.contains(s)) return const [1.0, 1.4, 0.10];
    if (thick.contains(s)) return const [1.0, 1.4, 0.24];
    return const [1.0, 1.4, 0.18];
  }

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
  Future<scene.Texture2D?> _loadTexture(String url) async {
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
        return await scene.Texture2D.fromImage(image);
      } finally {
        image.dispose();
      }
    } catch (e) {
      debugPrint('[Scene3D] textura falló ($clean): $e');
      return null;
    }
  }

  /// Material plano de color sólido (cantos y caras sin textura).
  scene.UnlitMaterial _solid(int argb) {
    return scene.UnlitMaterial()..baseColorFactor = _linearFromArgb(argb);
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

  Future<void> _build() async {
    final g = widget.game;
    try {
      await scene.Scene.initializeStaticResources();

      final frontUrl = (g.coverLargeUrl?.isNotEmpty == true
          ? g.coverLargeUrl!
          : (g.coverSmallUrl ?? ''));

      final textures = await Future.wait([
        _loadTexture(frontUrl),
        _loadTexture(g.coverBackUrl ?? ''),
        _loadTexture(g.coverSpineUrl ?? ''),
      ]);
      if (!mounted) return;

      final front = textures[0];
      final back = textures[1];
      final spine = textures[2];

      if (front == null) {
        debugPrint('[Scene3D] sin textura frontal (${g.id})');
        setState(() {
          _loading = false;
          _failed = true;
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
      final edge = _solid(0xFF2B1D12);
      final backFallback = _solid(0xFF808080);

      scene.Material faceMat(scene.Texture2D? tex, scene.Material fallback) =>
          tex == null
          ? fallback
          : (scene.UnlitMaterial(colorTexture: tex)..vertexColorWeight = 0);

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
      final sideMat = spine == null
          ? edge
          : (scene.UnlitMaterial(colorTexture: spine)..vertexColorWeight = 0);
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
        _loading = false;
        _ready = true;
      });
    } catch (e, st) {
      debugPrint('[Scene3D] build falló: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _onHorizontalDragStart(DragStartDetails d) {
    _yawStart = _yaw;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    setState(() {
      _yaw = _yawStart + (d.localPosition.dx / widget.width) * math.pi;
    });
  }

  void _nudge(double dx) {
    setState(() => _yaw += dx);
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || _scene == null) {
      return _frame(
        child: Container(
          color: const Color(0xFF0B1220),
          child: _loading
              ? const Center(child: AppLoader())
              : const SizedBox.shrink(),
        ),
      );
    }

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
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          child: Stack(
            fit: StackFit.expand,
            children: [
              scene.SceneView(
                scene3d,
                cameraBuilder: (elapsed) {
                  // Órbita manual (_yaw) + auto-rotación suave si procede.
                  final auto = widget.autoRotate
                      ? elapsed.inMicroseconds / 1e6 * 0.35
                      : 0.0;
                  final a = _yaw + auto;
                  const radius = 3.5;
                  final cam = scene.PerspectiveCamera(
                    position: vm.Vector3(
                      math.sin(a) * radius,
                      0.3,
                      math.cos(a) * radius,
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
