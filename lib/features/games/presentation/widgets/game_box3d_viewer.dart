import 'dart:async';

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
/// - 3D solo cuando [RommGame.has3DFaces] (frontal + trasera + lomo).
///   Caja `BoxGeometry` con frontal delante, trasera detrás y lomo en
///   los cantos; órbita con ratón/táctil vía `OrbitControls`.
/// - Sin caras suficientes: fallback 2D plano. Prioridad 2D:
///   `box3dUrl` pre-render de RomM > `coverLargeUrl` > `coverSmallUrl`.
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
    _show3D = widget.game.has3DFaces;
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
      _show3D = widget.game.has3DFaces;
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
    ref.read(gameVideoSuspendedProvider.notifier).set(true);
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

  String get _fallback2D {
    final g = widget.game;
    if (g.box3dUrl != null && g.box3dUrl!.isNotEmpty) return g.box3dUrl!;
    if (g.coverLargeUrl != null && g.coverLargeUrl!.isNotEmpty) {
      return g.coverLargeUrl!;
    }
    return g.coverSmallUrl ?? '';
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

  Future<three.Texture?> _loadFace(String url) async {
    if (url.isEmpty) return null;
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) return null;
    final bytes = await repo.downloadAssetBytes(url);
    if (bytes == null || bytes.isEmpty) return null;
    final tex =
        await three.TextureLoader(flipY: true).fromBytes(Uint8List.fromList(bytes));
    if (tex == null) return null;
    tex.colorSpace = three.SRGBColorSpace;
    tex.anisotropy = 4;
    tex.needsUpdate = true;
    return tex;
  }

  three.Material _edgeMaterial() {
    return three.MeshStandardMaterial({
      three.MaterialProperty.color: 0x2b1d12,
      three.MaterialProperty.roughness: 0.7,
      three.MaterialProperty.metalness: 0.05,
    });
  }

  three.Material _faceMaterial(three.Texture tex) {
    return three.MeshStandardMaterial({
      three.MaterialProperty.map: tex,
      three.MaterialProperty.roughness: 0.5,
      three.MaterialProperty.metalness: 0.05,
    });
  }

  Future<void> _setup() async {
    final t = _three;
    if (t == null) return;
    final g = widget.game;

    t.scene = three.Scene();
    final aspect = widget.width / widget.height;
    final camera = three.PerspectiveCamera(32, aspect, 0.1, 100);
    camera.position.setValues(1.6, 0.35, 4.1);
    t.camera = camera;

    t.scene.add(three.HemisphereLight(0xffffff, 0x223344, 0.95));
    final key = three.DirectionalLight(0xffffff, 0.85);
    key.position.setValues(2.5, 3, 4);
    t.scene.add(key);
    final fill = three.DirectionalLight(0x88aaff, 0.3);
    fill.position.setValues(-3, -1, 2);
    t.scene.add(fill);

    final size = _boxSizeFor(g.platformSlug);
    final geometry = three.BoxGeometry(size[0], size[1], size[2]);
    final edge = _edgeMaterial();
    final groupMat = three.GroupMaterial([edge, edge, edge, edge, edge, edge]);
    _box = three.Mesh(geometry, groupMat);
    _group = three.Group();
    _group!.add(_box!);
    t.scene.add(_group!);

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

    final frontUrl = (g.coverLargeUrl?.isNotEmpty == true
        ? g.coverLargeUrl!
        : (g.coverSmallUrl ?? ''));
    final results = await Future.wait([
      _loadFace(frontUrl),
      _loadFace(g.coverBackUrl ?? ''),
      _loadFace(g.coverSpineUrl ?? ''),
    ]);
    if (!mounted) return;
    if (results[0] == null) {
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
    final children = groupMat.children;
    children[4] = _faceMaterial(results[0]!);
    if (results[1] != null) children[5] = _faceMaterial(results[1]!);
    if (results[2] != null) {
      final spine = _faceMaterial(results[2]!);
      children[0] = spine;
      children[1] = spine;
    }
    for (final m in children) {
      m.needsUpdate = true;
    }
    setState(() {
      _loading = false;
      _ready = true;
    });
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
    final can3D = widget.game.has3DFaces;

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
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
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
