import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:three_js/three_js.dart' as three;

import '../../../../core/settings/game_video_controller.dart';
import '../../../../core/widgets/app_hover.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/romm_providers.dart';
import '../../domain/romm_game.dart';

/// Visor de portada con toggle 2D / 3D (render nativo con `three_js`).
///
/// - 3D cuando hay frontal ([RommGame.can3D]). Con trasera/lomo reales se
///   usan en sus caras (el lomo texturiza el lateral; superior e inferior
///   quedan tintados); sin ellas, trasera y cantos usan material sólido
///   teñido del predominante del lomo.
///   Caja `BoxGeometry` con frontal delante, trasera detrás y lomo en
///   Caja `BoxGeometry` con frontal delante, trasera detrás y lomo en
///   los cantos; órbita con ratón/táctil vía `OrbitControls`.
/// - Sin caras suficientes: fallback 2D plano. Prioridad 2D: frontal
///   plana (`coverLargeUrl` > `coverSmallUrl`); el pre-render `box3dUrl`
///   de RomM queda como último recurso. La 3D vive solo en el modo 3D.
/// - Texturas con auth Bearer descargadas en nativo con Dio: nunca salen
///   del proceso y no hay CORS ni cabeceras que inyectar.
class GameCoverViewer extends ConsumerStatefulWidget {
  const GameCoverViewer({
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
  ConsumerState<GameCoverViewer> createState() => _GameCoverViewerState();
}

class _GameCoverViewerState extends ConsumerState<GameCoverViewer> {
  late bool _show3D;
  bool _loading = false;
  bool _ready = false;
  bool _nativeAvailable = true;
  bool _suspendedByMe = false;
  Timer? _waitTimer;
  three.ThreeJS? _three;
  three.OrbitControls? _controls;
  three.Group? _group;
  three.Mesh? _box;
  final FocusNode _focusNode = FocusNode();

  /// Sin vídeos activos se puede crear la superficie GL. Si el fondo tarda
  /// en morir, se cae a 2D antes que arriesgar el abort de ANGLE.
  static const _waitStep = Duration(milliseconds: 150);
  static const _waitMax = Duration(seconds: 4);
  static const _resumeGrace = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _show3D = widget.game.can3D;
    if (_show3D) {
      _suspendVideo();
      _waitForVideoStop();
    }
  }

  @override
  void didUpdateWidget(GameCoverViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.id != widget.game.id) {
      _cancelWait();
      _disposeThree();
      _show3D = widget.game.can3D;
      _ready = false;
      if (_show3D) {
        _suspendVideo();
        _waitForVideoStop();
      } else {
        _resumeVideo();
      }
    }
  }

  @override
  void dispose() {
    _cancelWait();
    _focusNode.dispose();
    _disposeThree();
    _resumeVideo();
    super.dispose();
  }

  void _suspendVideo() {
    if (_suspendedByMe) return;
    _suspendedByMe = true;
    // Riverpod prohíbe mutar providers en initState/didUpdateWidget/dispose
    // mientras el árbol construye: se difiere a post-frame. La espera del
    // vídeo ya sondea por polling, así que un frame de más no importa.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        ref.read(gameVideoSuspendedProvider.notifier).set(true);
      } catch (_) {}
    });
  }

  void _resumeVideo() {
    if (!_suspendedByMe) return;
    _suspendedByMe = false;
    // Gracia para que el teardown GL se aquiete antes de que el fondo
    // recree su superficie ANGLE (orden inverso al de entrada).
    Future.delayed(_resumeGrace).then((_) {
      try {
        ref.read(gameVideoSuspendedProvider.notifier).set(false);
      } catch (_) {}
    });
  }

  void _cancelWait() {
    _waitTimer?.cancel();
    _waitTimer = null;
  }

  void _waitForVideoStop() {
    _cancelWait();
    if (!mounted) return;
    setState(() => _loading = true);
    if (ref.read(gameVideoActiveCountProvider) == 0) {
      _createThree();
      return;
    }
    var elapsed = Duration.zero;
    _waitTimer = Timer.periodic(_waitStep, (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      elapsed += _waitStep;
      if (ref.read(gameVideoActiveCountProvider) == 0) {
        t.cancel();
        _waitTimer = null;
        _createThree();
      } else if (elapsed >= _waitMax) {
        t.cancel();
        _waitTimer = null;
        // El vídeo no murió a tiempo: 2D antes que arriesgar el FATAL.
        setState(() {
          _loading = false;
          _show3D = false;
        });
        final l10n = AppLocalizations.of(context);
        if (l10n != null) {
          unawaited(
            EasyLoading.showToast(
              l10n.gameBoxNoData,
              toastPosition: EasyLoadingToastPosition.bottom,
              maskType: EasyLoadingMaskType.none,
              dismissOnTap: true,
            ),
          );
        }
      }
    });
  }

  void _disposeThree() {
    try {
      _controls?.dispose();
    } catch (_) {}
    _controls = null;
    try {
      _three?.dispose();
    } catch (_) {}
    _three = null;
    _group = null;
    _box = null;
  }

  void _createThree() {
    if (!mounted || _three != null) return;
    try {
      _three = three.ThreeJS(
        settings: three.Settings(alpha: true, clearAlpha: 0, antialias: true),
        onSetupComplete: () {
          if (mounted) setState(() {});
        },
        setup: _setup,
        rendererUpdate: () => _controls?.update(),
        loadingWidget: const Center(child: AppLoader()),
      );
    } catch (_) {
      // Sin contexto GL en el dispositivo: cae a 2D sin romper el detalle.
      _three = null;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _show3D = false;
        _nativeAvailable = false;
      });
    }
    if (mounted) setState(() {});
  }

  /// 2D = frontal plana por defecto; el pre-render 3D de RomM solo se
  /// usa si no hay frontal. La caja 3D vive en el modo 3D.
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

  /// Grosor de caja por familia de plataforma (SNES/cartucho grueso vs CD fino).
  List<double> _boxSizeFor(String slug) {
    const thick = {
      'nes', 'snes', 'n64', 'gb', 'gbc', 'gba', 'genesis', 'megadrive',
      'mastersystem', 'gamegear', 'lynx', 'ngp', 'ngpc', 'nds', 'n3ds', 'vb',
    };
    const thin = {
      'ps', 'psx', 'ps1', 'ps2', 'saturn', 'dreamcast', 'psp', 'psvita',
      'segacd', 'sega-cd', '3do', 'cdi', 'pcengine', 'turbografx16', 'neogeocd',
    };
    final s = slug.trim().toLowerCase();
    if (thin.contains(s)) return const [1.0, 1.4, 0.1];
    if (thick.contains(s)) return const [1.0, 1.4, 0.24];
    return const [1.0, 1.4, 0.18];
  }

  /// Sanea una URL de asset (la `ts` de RomM trae espacios sin codificar).
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

  /// Carga una cara y, si se pide (`sampleColor`), su color predominante
  /// (para teñir las caras que queden sin textura). Solo se muestrea el
  /// lomo: es barato y evita trabajo inútil en frontal/trasera.
  Future<({three.Texture? texture, int? dominant})> _loadFace(
    String url, {
    bool sampleColor = false,
  }) async {
    const empty = (texture: null, dominant: null);
    final clean = _sanitizeUrl(url);
    if (clean.isEmpty) return empty;
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) return empty;
    try {
      final bytes = await repo.downloadAssetBytes(clean);
      if (bytes == null || bytes.isEmpty) return empty;
      final tex = await three.TextureLoader(flipY: true)
          .fromBytes(Uint8List.fromList(bytes));
      if (tex == null) return empty;
      tex.colorSpace = three.SRGBColorSpace;
      // Las carátulas de RomM son NPOT (p.ej. 517x680): con mipmaps la
      // textura queda incompleta en ANGLE/D3D11 y la cara sale negra.
      // three.js hace lo mismo con NPOT en WebGL1.
      tex.generateMipmaps = false;
      tex.minFilter = three.LinearFilter;
      tex.needsUpdate = true;
      final dominant =
          sampleColor ? await _predominantColor(bytes) : null;
      return (texture: tex, dominant: dominant);
    } catch (_) {
      return empty;
    }
  }

  /// Color predominante de una carátula como `0xFFRRGGBB` (histograma con
  /// 4 bits por canal sobre miniatura, transparentes ignorados). Para teñir
  /// las caras del modelo que no tengan textura del color del lomo.
  Future<int?> _predominantColor(List<int> bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        Uint8List.fromList(bytes),
        targetWidth: 48,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (data == null) return null;
      final pixels = data.buffer.asUint8List();
      final counts = <int, int>{};
      for (var i = 0; i + 4 <= pixels.length; i += 4) {
        if (pixels[i + 3] < 128) continue;
        final key = ((pixels[i] >> 4) << 8) |
            ((pixels[i + 1] >> 4) << 4) |
            (pixels[i + 2] >> 4);
        counts[key] = (counts[key] ?? 0) + 1;
      }
      if (counts.isEmpty) return null;
      var best = counts.entries.first;
      for (final e in counts.entries) {
        if (e.value > best.value) best = e;
      }
      final r = ((best.key >> 8) & 0xF) * 16 + 8;
      final g = ((best.key >> 4) & 0xF) * 16 + 8;
      final b = (best.key & 0xF) * 16 + 8;
      return (0xFF << 24) | (r << 16) | (g << 8) | b;
    } catch (_) {
      return null;
    }
  }

  /// Cantos/caras sin textura. Con `tint` (predominante del lomo) se tiñen
  /// de ese color; sin él, marrón sólido corporativo.
  three.Material _edgeMaterial({int? tint}) {
    return three.MeshStandardMaterial({
      three.MaterialProperty.color: tint ?? 0x2b1d12,
      three.MaterialProperty.roughness: 0.7,
      three.MaterialProperty.metalness: 0.05,
    });
  }

  /// Caras con carátula: `MeshBasicMaterial` a propósito (sin luces ni
  /// normales): los colores salen exactos como en el 2D y usa un programa
  /// distinto al de los cantos Standard. Los cantos siguen con Standard
  /// para conservar el sombreado del grosor de la caja.
  three.Material _faceMaterial(three.Texture tex) {
    return three.MeshBasicMaterial({
      three.MaterialProperty.map: tex,
    });
  }

  Future<void> _setup() async {
    final t = _three;
    if (t == null) return;
    final g = widget.game;

    try {
      t.scene = three.Scene();
      final aspect = widget.width / widget.height;
      // Encuadre inicial con presencia: cámara más cerca y FOV estrecho
      // para que la caja se vea grande nada más cargar. Se conserva el
      // ángulo 3/4 (proporción x/y/z) y el `minDistance` (2.4) para no
      // tocar el zoom manual.
      final camera = three.PerspectiveCamera(27, aspect, 0.1, 100);
      camera.position.setValues(1.25, 0.3, 3.2);
      t.camera = camera;

      t.scene.add(three.HemisphereLight(0xffffff, 0x223344, 0.95));
      final key = three.DirectionalLight(0xffffff, 0.85);
      key.position.setValues(2.5, 3, 4);
      t.scene.add(key);
      final fill = three.DirectionalLight(0x88aaff, 0.3);
      fill.position.setValues(-3, -1, 2);
      t.scene.add(fill);

      _controls = three.OrbitControls(camera, t.globalKey);
      _controls!.enableDamping = true;
      _controls!.dampingFactor = 0.08;
      _controls!.enablePan = false;
      _controls!.enableZoom = true;
      _controls!.minDistance = 2.4;
      _controls!.maxDistance = 7;
      _controls!.minPolarAngle = 0.6;
      _controls!.maxPolarAngle = 2.5;
      _controls!.autoRotate = widget.autoRotate;
      _controls!.autoRotateSpeed = 3.0;
      _controls!.update();

      // Caras primero: la malla se crea UNA vez con los materiales finales.
      // (Mutar GroupMaterial.children tras el primer render no llega al
      // puente nativo ANGLE y la carátula nunca aparecía.)
      final frontUrl = (g.coverLargeUrl?.isNotEmpty == true
          ? g.coverLargeUrl!
          : (g.coverSmallUrl ?? ''));
      final results = await Future.wait([
        _loadFace(frontUrl),
        _loadFace(g.coverBackUrl ?? ''),
        _loadFace(g.coverSpineUrl ?? '', sampleColor: true),
      ]);
      if (!mounted || _three == null) return;
      if (results[0].texture == null) {
        setState(() {
          _loading = false;
          _show3D = false;
        });
        final l10n = AppLocalizations.of(context);
        if (l10n != null) {
          unawaited(
            EasyLoading.showToast(
              l10n.gameBoxNoData,
              toastPosition: EasyLoadingToastPosition.bottom,
              maskType: EasyLoadingMaskType.none,
              dismissOnTap: true,
            ),
          );
        }
        return;
      }
      // Orden BoxGeometry: [+x, -x, +y, -y, +z(frontal), -z(trasera)].
      // Las caras sin textura se tiñen del predominante del lomo; sin
      // lomo, marrón sólido.
      final edge = _edgeMaterial(tint: results[2].dominant);
      final materials = <three.Material>[
        edge,
        edge,
        edge,
        edge,
        _faceMaterial(results[0].texture!),
        results[1].texture != null ? _faceMaterial(results[1].texture!) : edge,
      ];
      if (results[2].texture != null) {
        // Solo el lateral lleva el lomo texturizado (+x/-x). Superior e
        // inferior (+y/-y) quedan tintados con el predominante del lomo.
        final spine = _faceMaterial(results[2].texture!);
        materials[0] = spine;
        materials[1] = spine;
      }
      final size = _boxSizeFor(g.platformSlug);
      final geometry = three.BoxGeometry(size[0], size[1], size[2]);
      final groupMat = three.GroupMaterial(materials);
      _box = three.Mesh(geometry, groupMat);
      _group = three.Group();
      _group!.add(_box!);
      t.scene.add(_group!);

      setState(() {
        _loading = false;
        _ready = true;
      });
    } catch (_) {
      if (!mounted) return;
      _disposeThree();
      setState(() {
        _loading = false;
        _show3D = false;
      });
    }
  }

  void _onToggle(bool to3D) {
    if (to3D == _show3D) return;
    if (!to3D) {
      // A 2D: libera la superficie GL (el vídeo sigue suspendido).
      _cancelWait();
      _disposeThree();
      setState(() {
        _show3D = false;
        _loading = false;
        _ready = false;
      });
      return;
    }
    if (!_nativeAvailable) return;
    setState(() => _show3D = true);
    if (_three == null) {
      _ready = false;
      _suspendVideo();
      _waitForVideoStop();
    }
  }

  void _nudge(double dx) {
    final grp = _group;
    if (grp == null) return;
    grp.rotation.y += dx;
    _controls?.update();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final can3D = widget.game.can3D;

    Widget viewer;
    if (_show3D && can3D && _nativeAvailable && _three != null) {
      viewer = _build3D(l10n);
    } else {
      viewer = _build2D();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        viewer,
        if (can3D) ...[
          const SizedBox(height: 10),
          _ViewToggle(
            show3D: _show3D,
            label2D: l10n.gameView2D,
            label3D: l10n.gameView3D,
            onChanged: _onToggle,
          ),
        ],
      ],
    );
  }

  Widget _frame({required Widget child}) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: child,
      ),
    );
  }

  Widget _build2D() {
    final url = _fallback2D;
    return _frame(
      child: url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              headers: widget.headers,
              errorBuilder: (_, _, _) => _CoverFallback(game: widget.game),
            )
          : _CoverFallback(game: widget.game),
    );
  }

  Widget _build3D(AppLocalizations l10n) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        const step = 0.25;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _nudge(step);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _nudge(-step);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: _frame(
        child: Stack(
          fit: StackFit.expand,
          children: [
            SizedBox(
              width: widget.width,
              height: widget.height,
              child: _three!.build(),
            ),
            if (_loading || !_ready)
              Container(
                color: const Color(0xFF0B1220),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppLoader(),
                      const SizedBox(height: 8),
                      Text(
                        l10n.gameBoxLoading,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.show3D,
    required this.label2D,
    required this.label3D,
    required this.onChanged,
  });

  final bool show3D;
  final String label2D;
  final String label3D;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool active, VoidCallback onTap) {
      return AppHover(
        effect: AppHoverEffect.highlightWithScale,
        config: AppHoverConfig(
          borderRadius: BorderRadius.circular(8),
          highlightNormal: active ? Colors.white : Colors.transparent,
          highlightHovered: active ? const Color(0xFFE6E6E6) : Colors.white10,
          scale: 1.04,
        ),
        onTap: onTap,
        playSoundOnHover: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.black : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg(label2D, !show3D, () => onChanged(false)),
          const SizedBox(width: 4),
          seg(label3D, show3D, () => onChanged(true)),
        ],
      ),
    );
  }
}

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
