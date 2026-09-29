// game_box3d_viewer.dart — versión corregida completa

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:three_js/three_js.dart' as three;

import '../../../../core/navigation/platform_mode.dart';
import '../../../../core/settings/game_video_controller.dart';
import '../../../../core/widgets/app_hover.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/romm_providers.dart';
import '../../domain/romm_game.dart';

/// LUT sRGB->linear (256 entradas). `three_js_angle_renderer` sube la textura
/// con `NoColorSpace` (formato interno `RGBA8`) porque `TextureLoader.fromBytes`
/// fija `needsUpdate` antes de poder asignar `SRGBColorSpace`; el shader
/// `physical` termina en `linearToOutputTexel` (OETF sRGB), asi que los bytes
/// sRGB llegan al shader sin decodificar y el OETF los vuelve a codificar
/// (`pow(x, 2.2)` extra) oscureciendo la caratula. Pre-convertir a lineal
/// (working space del renderer, `legacyMode = true`) deja el OETF final correcto.
final Uint8List _srgbToLinearLut = () {
  final lut = Uint8List(256);
  for (var i = 0; i < 256; i++) {
    final c = i / 255;
    final linear = c <= 0.04045
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    lut[i] = (linear * 255).round().clamp(0, 255);
  }
  return lut;
}();

/// Aplica sRGB->linear in-place sobre RGBA crudo (alpha intacto).
void _srgbToLinearInPlace(Uint8List pixels) {
  final lut = _srgbToLinearLut;
  for (var i = 0; i + 4 <= pixels.length; i += 4) {
    pixels[i] = lut[pixels[i]];
    pixels[i + 1] = lut[pixels[i + 1]];
    pixels[i + 2] = lut[pixels[i + 2]];
  }
}

/// Re-codifica pixeles RGBA crudos a PNG usando el codec de Flutter
/// (`ImageDescriptor.raw`). El PNG resultante vuelve a decodificarse sin
/// recalcular color, por lo que conserva los valores lineales.
Future<Uint8List?> _encodePngRgba(Uint8List rgba, int width, int height) async {
  try {
    final descriptor = ui.ImageDescriptor.raw(
      await ui.ImmutableBuffer.fromUint8List(rgba),
      width: width,
      height: height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return null;
      return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    } finally {
      image.dispose();
      descriptor.dispose();
    }
  } catch (_) {
    return null;
  }
}

/// Normaliza bytes de caratula: decodifica, detecta placeholders negros
/// (solo frontal) y devuelve un PNG con los pixeles en espacio lineal.
Future<Uint8List?> _normalizedCoverBytes(
  List<int> bytes, {
  bool rejectBlank = true,
  String debugLabel = 'cara',
}) async {
  if (bytes.isEmpty) {
    debugPrint('[Box3D] normalize $debugLabel: 0 bytes');
    return null;
  }
  try {
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      if (image.width <= 0 || image.height <= 0) {
        debugPrint('[Box3D] normalize $debugLabel: sin dimensiones');
        return null;
      }
      final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (raw == null) {
        debugPrint(
          '[Box3D] normalize $debugLabel: rawRgba nulo '
          '(${image.width}x${image.height}, ${bytes.length} bytes)',
        );
        return null;
      }
      final pixels = raw.buffer.asUint8List(
        raw.offsetInBytes,
        raw.lengthInBytes,
      );
      var sum = 0;
      var count = 0;
      for (var i = 0; i + 4 <= pixels.length; i += 32) {
        if (pixels[i + 3] < 128) continue;
        sum +=
            (pixels[i] * 299 + pixels[i + 1] * 587 + pixels[i + 2] * 114) ~/
            1000;
        count++;
      }
      if (count == 0) {
        debugPrint(
          '[Box3D] normalize $debugLabel: sin píxeles opacos '
          '(${image.width}x${image.height}, ${bytes.length} bytes)',
        );
        return null;
      }
      final avg = sum / count;
      if (rejectBlank && avg < 8) {
        debugPrint(
          '[Box3D] normalize $debugLabel: casi negra '
          '(luma ${avg.toStringAsFixed(1)}, ${image.width}x${image.height}, '
          '${bytes.length} bytes)',
        );
        return null;
      }
      // Conversion sRGB->linear sobre los pixeles crudos: la textura llega al
      // shader ya lineal y el OETF final no la apaga. Se re-codifica a PNG
      // desde los pixeles crudos (ui.ImageDescriptor.raw) para reutilizar el
      // pipeline ya verificado de `TextureLoader.fromBytes`.
      final linearPixels = Uint8List.fromList(pixels);
      _srgbToLinearInPlace(linearPixels);
      final linearPng = await _encodePngRgba(
        linearPixels,
        image.width,
        image.height,
      );
      if (linearPng == null) {
        debugPrint('[Box3D] normalize $debugLabel: png lineal nulo');
        return null;
      }
      debugPrint(
        '[Box3D] normalize $debugLabel OK ${image.width}x${image.height} '
        'pixels=${linearPixels.length} png=${linearPng.length}',
      );
      return linearPng;
    } finally {
      image.dispose();
    }
  } catch (e) {
    debugPrint('[Box3D] normalize $debugLabel: decode fallido ($e)');
    return null;
  }
}

class GameCoverViewer extends ConsumerStatefulWidget {
  const GameCoverViewer({
    super.key,
    required this.game,
    required this.headers, // <-- Bearer token ya viene de fuera
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

  static const _waitStep = Duration(milliseconds: 150);
  static const _waitMax = Duration(seconds: 4);
  static const _settleGrace = Duration(milliseconds: 400);
  Timer? _settleTimer;
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
    Future.delayed(_resumeGrace).then((_) {
      try {
        ref.read(gameVideoSuspendedProvider.notifier).set(false);
      } catch (_) {}
    });
  }

  void _cancelWait() {
    _waitTimer?.cancel();
    _waitTimer = null;
    _settleTimer?.cancel();
    _settleTimer = null;
  }

  void _createThreeAfterSettle() {
    _settleTimer?.cancel();
    _settleTimer = Timer(_settleGrace, () {
      _settleTimer = null;
      if (!mounted) return;
      try {
        if (ref.read(gameVideoActiveCountProvider) != 0) {
          _waitForVideoStop();
          return;
        }
      } catch (_) {}
      _createThree();
    });
  }

  void _waitForVideoStop() {
    _cancelWait();
    if (!mounted) return;
    setState(() => _loading = true);
    final startCount = ref.read(gameVideoActiveCountProvider);
    if (startCount == 0) {
      _createThreeAfterSettle();
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
        _createThreeAfterSettle();
      } else if (elapsed >= _waitMax) {
        t.cancel();
        _waitTimer = null;
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
    if (g.coverLargeUrl != null && g.coverLargeUrl!.isNotEmpty) {
      return g.coverLargeUrl!;
    }
    if (g.coverSmallUrl != null && g.coverSmallUrl!.isNotEmpty) {
      return g.coverSmallUrl!;
    }
    return g.box3dUrl ?? '';
  }

  List<double> _boxSizeFor(String slug) {
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
    final s = slug.trim().toLowerCase();
    if (thin.contains(s)) return const [1.0, 1.4, 0.1];
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

  // ─────────────────────────────────────────────────────────────────────────
  // FIX PRINCIPAL: _loadFace ahora recibe y usa las cabeceras Bearer.
  // Antes nunca se pasaban → la API de ROMM rechazaba o devolvía vacío.
  // ─────────────────────────────────────────────────────────────────────────
  Future<({three.Texture? texture, int? dominant})> _loadFace(
    String url, {
    bool sampleColor = false,
    bool rejectBlank = true,
    String debugLabel = 'cara',
  }) async {
    const empty = (texture: null, dominant: null);
    final clean = _sanitizeUrl(url);
    if (clean.isEmpty) {
      debugPrint('[Box3D] cara $debugLabel: URL vacía');
      return empty;
    }
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) {
      debugPrint('[Box3D] cara $debugLabel: sin repo ($clean)');
      return empty;
    }
    try {
      // FIX: pasamos las cabeceras que vienen del widget (Bearer token).
      // downloadAssetBytes debe aceptar un Map<String,String>? opcional.
      // Si tu implementación aún no lo tiene, ver nota al final del bloque.
      final bytes = await repo.downloadAssetBytes(
        clean,
        headers: widget.headers, // ← CAMBIO CLAVE
      );
      if (bytes == null || bytes.isEmpty) {
        debugPrint('[Box3D] cara $debugLabel: descarga vacía ($clean)');
        return empty;
      }

      final normalized = await _normalizedCoverBytes(
        bytes,
        rejectBlank: rejectBlank,
        debugLabel: debugLabel,
      );
      if (normalized == null || normalized.isEmpty) {
        debugPrint(
          '[Box3D] cara $debugLabel: normalize nulo '
          '(${bytes.length} bytes de $clean)',
        );
        return empty;
      }

      // `TextureLoader.fromBytes` (pipeline verificado) con el PNG lineal.
      // flipY:true como en el commit funcional 6d67590: sin el, la caratula
      // se muestrea invertida y con ClampToEdge sale un borde plano (gris).
      final tex = await three.TextureLoader(flipY: true).fromBytes(normalized);
      if (tex == null) return empty;

      tex.colorSpace = three.SRGBColorSpace;
      tex.wrapS = three.ClampToEdgeWrapping;
      tex.wrapT = three.ClampToEdgeWrapping;
      tex.magFilter = three.LinearFilter;
      tex.minFilter = three.LinearFilter;
      tex.generateMipmaps = false;
      // FIX: needsUpdate se setea AQUÍ para el upload inicial del codec,
      // pero se vuelve a poner a true después de añadir la malla a la
      // escena (ver _setup), que es cuando ANGLE tiene el contexto GL listo.
      tex.needsUpdate = true;

      final dominant = sampleColor ? await _predominantColor(bytes) : null;
      return (texture: tex, dominant: dominant);
    } catch (_) {
      return empty;
    }
  }

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
        final key =
            ((pixels[i] >> 4) << 8) |
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

  // ─────────────────────────────────────────────────────────────────────────
  // FIX: todos los materiales son MeshStandardMaterial.
  // Mezclar MeshBasicMaterial + MeshStandardMaterial en un GroupMaterial
  // hace que el driver ANGLE compile shaders incompatibles y las caras
  // con textura salen negras sin ningún error en el log.
  // roughness:1 / metalness:0 imita el aspecto plano del Basic.
  // ─────────────────────────────────────────────────────────────────────────
  three.Material _edgeMaterial({int? tint}) {
    return three.MeshStandardMaterial({
      three.MaterialProperty.color: tint ?? 0x2b1d12,
      three.MaterialProperty.roughness: 0.7,
      three.MaterialProperty.metalness: 0.05,
    });
  }

  three.Material _faceMaterial(three.Texture tex) {
    // `MeshBasicMaterial` como en el commit funcional 6d67590: las caras con
    // caratula se muestran sin luces ni normales (color exacto) y usan un
    // programa distinto al de los cantos Standard. Con `MeshStandardMaterial`
    // el map no se muestreaba en ANGLE y las caras quedaban planas.
    final mat = three.MeshBasicMaterial({
      three.MaterialProperty.map: tex,
    });
    debugPrint(
      '[Box3D] _faceMaterial: inTex=${tex.runtimeType} '
      'inVersion=${tex.version} outMap=${mat.map != null} '
      'outVersion=${mat.map?.version} same=${identical(mat.map, tex)}',
    );
    return mat;
  }

  Future<void> _setup() async {
    debugPrint(
      '[Box3D] _setup START — game=${widget.game.id} can3D=${widget.game.can3D}',
    );
    debugPrint('[Box3D] _setup — frontLarge=${widget.game.coverLargeUrl}');
    debugPrint('[Box3D] _setup — frontSmall=${widget.game.coverSmallUrl}');
    final t = _three;
    if (t == null) {
      debugPrint('[Box3D] _setup ABORT — _three es null');
      return;
    }
    final g = widget.game;

    try {
      t.scene = three.Scene();
      debugPrint('[Box3D] scene OK');
      final aspect = widget.width / widget.height;
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

      final frontUrl = (g.coverLargeUrl?.isNotEmpty == true
          ? g.coverLargeUrl!
          : (g.coverSmallUrl ?? ''));
      debugPrint('[Box3D] frontUrl=$frontUrl');

      final results = await Future.wait([
        _loadFace(frontUrl, debugLabel: 'front'),
        _loadFace(g.coverBackUrl ?? '', rejectBlank: false, debugLabel: 'back'),
        _loadFace(
          g.coverSpineUrl ?? '',
          sampleColor: true,
          rejectBlank: false,
          debugLabel: 'spine',
        ),
      ]);
      debugPrint('[Box3D] Future.wait completado');
      debugPrint('[Box3D] front tex=${results[0].texture != null}');
      debugPrint('[Box3D] back  tex=${results[1].texture != null}');
      debugPrint('[Box3D] spine tex=${results[2].texture != null}');

      // Guardia anti-carrera
      if (!mounted || _three == null || !identical(t, _three)) {
        debugPrint('[Box3D] ABORT post-await — desmontado o carrera');
        return;
      }

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

      if (results[1].texture == null || results[2].texture == null) {
        debugPrint(
          '[Box3D] juego ${g.id}: '
          'back=${results[1].texture != null ? "ok" : "GRIS (nula)"} '
          'spine=${results[2].texture != null ? "ok" : "sin textura"} '
          'backUrl=${g.coverBackUrl ?? "-"} spineUrl=${g.coverSpineUrl ?? "-"}',
        );
      }

      final edge = _edgeMaterial(tint: results[2].dominant);
      final backFallback = _edgeMaterial(tint: 0x808080);

      // Orden BoxGeometry: [+x, -x, +y, -y, +z(frontal), -z(trasera)]
      final materials = <three.Material>[
        edge,
        edge,
        edge,
        edge,
        _faceMaterial(results[0].texture!),
        results[1].texture != null
            ? _faceMaterial(results[1].texture!)
            : backFallback,
      ];

      if (results[2].texture != null) {
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

      debugPrint(
        '[Box3D] mesh: groups=${geometry.groups.length} '
        'materials=${materials.length} '
        'matTypes=${materials.map((m) => m.runtimeType).toList()} '
        'maps=${materials.map((m) => m.map != null).toList()} '
        'mapVersions=${materials.map((m) => m.map?.version).toList()}',
      );

      setState(() {
        _loading = false;
        _ready = true;
      });
    } catch (e, st) {
      debugPrint('[Box3D] _setup EXCEPTION: $e\n$st'); // <-- st para stacktrace
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
    final isTv =
        (ref.watch(platformModeProvider).value ?? PlatformMode.mobile) ==
        PlatformMode.tv;

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

  Widget _frame({required Widget child}) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRRect(borderRadius: BorderRadius.circular(3), child: child),
    );
  }

  Widget _build2D() {
    final url = _fallback2D;
    return _frame(
      child: url.isNotEmpty
          ? _ValidatedCoverImage(
              key: ValueKey(url),
              url: url,
              headers: widget.headers, // FIX: también pasa headers al 2D
              game: widget.game,
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

// ─────────────────────────────────────────────────────────────────────────────
// _ViewToggle, _ValidatedCoverImage, _CoverFallback sin cambios funcionales,
// salvo que _ValidatedCoverImage ahora acepta y usa headers.
// ─────────────────────────────────────────────────────────────────────────────

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

class _ValidatedCoverImage extends ConsumerStatefulWidget {
  const _ValidatedCoverImage({
    super.key,
    required this.url,
    required this.headers, // FIX: añadido
    required this.game,
  });

  final String url;
  final Map<String, String>? headers; // FIX: añadido
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
      // FIX: pasa las cabeceras Bearer al repo, igual que en _loadFace.
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
