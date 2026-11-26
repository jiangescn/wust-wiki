import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// Wenku8 Flutter motion_ui.dart, ebcd7f1891b54a92fc045c372974d70ec829f10a.
// The paper flight excerpt is unchanged. Upstream licenses are in mobile/licenses.

/// A peel front travels from the upper edge to the lower edge. Near the end
/// of the flight a diagonal contact front travels from bottom-left to top-right.
/// Depth is exactly zero at both endpoints; arrival has no continuing ticker.
class PaperFlightPose {
  const PaperFlightPose(this.progress);
  final double progress;

  static double _smooth(double value) {
    final x = value.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  static double travel(double progress) =>
      Curves.easeInOutCubic.transform(((progress - .12) / .46).clamp(0.0, 1.0));

  /// Hero adds fastOutSlowIn itself. Undo that clock before applying our
  /// choreography, otherwise the travel and contact get eased twice.
  static double heroTimeline(double value) {
    if (value <= 0 || value >= 1) return value.clamp(0.0, 1.0);
    var low = 0.0;
    var high = 1.0;
    for (var i = 0; i < 18; i++) {
      final parameter = (low + high) / 2;
      if (_smooth(parameter) < value) {
        low = parameter;
      } else {
        high = parameter;
      }
    }
    final t = (low + high) / 2;
    final remaining = 1 - t;
    // x of Cubic(.4, 0, .2, 1), after solving its y above.
    return 1.2 * remaining * remaining * t + .6 * remaining * t * t + t * t * t;
  }

  double depthAt(double row, {double column = .5}) {
    if (progress <= 0 || progress >= 1) return 0;
    final v = row.clamp(0.0, 1.0);
    final peel = _smooth((progress - .025 - v * .11) / .11);
    final landing = ((progress - .58) / .42).clamp(0.0, 1.0);
    // The lower-left corner settles first, then the contact sweeps across the
    // face. A row-only field would flatten the entire bottom edge at once.
    final contact = (1 - v) * .66 + column.clamp(0.0, 1.0) * .34;
    final floating = 1 - _smooth((landing - contact * .70) / .30);
    final breeze = math.sin((v * 1.3 - progress * 1.6) * math.pi * 2);
    return peel *
        floating *
        (17 +
            7 * math.sin(v * math.pi) +
            3 * breeze * math.sin(progress * math.pi));
  }

  double get lift =>
      18 * _smooth(progress / .18) * (1 - _smooth((progress - .42) / .16));

  double get roll =>
      -.045 *
      math.sin(progress.clamp(0.0, 1.0) * math.pi) *
      (1 - _smooth((progress - .42) / .16));
}

/// The flat Hero bounds remain a valid layout box. Travel waits briefly for
/// the peel, and reaches the target before the diagonal landing finishes.
class PaperCoverRectTween extends RectTween {
  PaperCoverRectTween({
    super.begin,
    super.end,
    required this.returning,
    this.heroCurve = false,
    this.endPaintOffset = Offset.zero,
  });
  final bool returning;
  final bool heroCurve;
  final Offset endPaintOffset;

  /// Hero tracks its destination's local origin on every tick, but initially
  /// measures a transformed bounding rectangle. Those differ on a slanted
  /// cover. Keep the tracked endpoint at the origin, and apply its exact
  /// bounds correction only when painting the flight.
  factory PaperCoverRectTween.toHero({
    required BuildContext context,
    required Rect? begin,
    required Rect? end,
    required bool returning,
  }) {
    final box = context.findRenderObject();
    final route = ModalRoute.of(context)?.subtreeContext?.findRenderObject();
    var offset = Offset.zero;
    if (box is RenderBox && box.hasSize && route != null && end != null) {
      final matrix = box.getTransformTo(route);
      final bounds = MatrixUtils.transformRect(matrix, Offset.zero & box.size);
      final origin = MatrixUtils.transformPoint(matrix, Offset.zero);
      offset = bounds.topLeft - origin;
      end = origin & bounds.size;
    }
    return PaperCoverRectTween(
      begin: begin,
      end: end,
      returning: returning,
      heroCurve: true,
      endPaintOffset: offset,
    );
  }

  @override
  Rect lerp(double t) {
    final target = end!.shift(endPaintOffset);
    if (t <= 0) return begin!;
    if (t >= 1) return target;
    if (heroCurve) t = PaperFlightPose.heroTimeline(t);
    final travel = returning
        ? 1 - PaperFlightPose.travel(1 - t)
        : PaperFlightPose.travel(t);
    if (travel <= 0) return begin!;
    if (travel >= 1) return target;
    final center = Offset.lerp(begin!.center, target.center, travel)!;
    final distance = (target.center - begin!.center).distance;
    final lift =
        math.min(32.0, 12 + distance * .075) * math.sin(travel * math.pi);
    return Rect.fromCenter(
      center: center + Offset(0, -lift),
      width: begin!.width + (target.width - begin!.width) * travel,
      height: begin!.height + (target.height - begin!.height) * travel,
    );
  }
}

/// A Hero's bounding rectangle is not its painted face when the source sits
/// on an oblique archive file. Retain that face's actual affine projection so
/// takeoff and return meet the artwork, not a suddenly flattened rectangle.
@immutable
class PaperCoverPlane {
  const PaperCoverPlane(this.origin, this.horizontal, this.vertical);
  static const flat = PaperCoverPlane(Offset.zero, Offset(1, 0), Offset(0, 1));
  final Offset origin;
  final Offset horizontal;
  final Offset vertical;

  static PaperCoverPlane fromHero(BuildContext context) {
    final box = context.findRenderObject();
    final overlay = Navigator.maybeOf(
      context,
    )?.overlay?.context.findRenderObject();
    if (box is! RenderBox ||
        !box.hasSize ||
        box.size.isEmpty ||
        overlay == null) {
      return flat;
    }
    final matrix = box.getTransformTo(overlay);
    final bounds = MatrixUtils.transformRect(matrix, Offset.zero & box.size);
    if (bounds.isEmpty || !bounds.width.isFinite || !bounds.height.isFinite) {
      return flat;
    }
    Offset point(Offset local) {
      final world = MatrixUtils.transformPoint(matrix, local);
      return Offset(
        (world.dx - bounds.left) / bounds.width,
        (world.dy - bounds.top) / bounds.height,
      );
    }

    final origin = point(Offset.zero);
    return PaperCoverPlane(
      origin,
      point(Offset(box.size.width, 0)) - origin,
      point(Offset(0, box.size.height)) - origin,
    );
  }

  static Path? occlusionFromHero(BuildContext context) {
    final face = context.findRenderObject();
    if (face is! RenderBox || !face.hasSize) return null;
    RenderObject? ancestor = face.parent;
    while (ancestor != null) {
      if (ancestor is PaperCoverOcclusionSource) {
        final path = (ancestor as PaperCoverOcclusionSource).coverOcclusion(
          face,
        );
        final route = ModalRoute.of(
          context,
        )?.subtreeContext?.findRenderObject();
        final overlay = Navigator.maybeOf(
          context,
        )?.overlay?.context.findRenderObject();
        if (path == null || route == null || overlay == null) return path;
        // The covered shelf is still under Cupertino's outgoing parallax at
        // pop start. Retain its final scene mask, not that temporary offset.
        final inverse = Matrix4.tryInvert(route.getTransformTo(null));
        if (inverse == null) return path;
        return path.transform(
          (overlay.getTransformTo(null)..multiply(inverse)).storage,
        );
      }
      ancestor = ancestor.parent;
    }
    return null;
  }

  Offset point(double u, double v) => origin + horizontal * u + vertical * v;

  static PaperCoverPlane lerp(PaperCoverPlane a, PaperCoverPlane b, double t) =>
      PaperCoverPlane(
        Offset.lerp(a.origin, b.origin, t)!,
        Offset.lerp(a.horizontal, b.horizontal, t)!,
        Offset.lerp(a.vertical, b.vertical, t)!,
      );

  Matrix4 matrix(Size size) => Matrix4.identity()
    ..setEntry(0, 0, horizontal.dx)
    ..setEntry(1, 0, horizontal.dy * size.height / size.width)
    ..setEntry(0, 1, vertical.dx * size.width / size.height)
    ..setEntry(1, 1, vertical.dy)
    ..setEntry(0, 3, origin.dx * size.width)
    ..setEntry(1, 3, origin.dy * size.height);
}

/// Source scenes provide physical foreground silhouettes, not page snapshots.
abstract interface class PaperCoverOcclusionSource {
  Path? coverOcclusion(RenderBox face);
}

class PaperCoverFlight extends StatefulWidget {
  const PaperCoverFlight({
    super.key,
    required this.animation,
    required this.child,
    this.imageProvider,
    this.faceSize = const Size(120, 164),
    this.beginPlane = PaperCoverPlane.flat,
    this.endPlane = PaperCoverPlane.flat,
    this.backingColor = const Color(0xFF202020),
    this.beginOcclusion,
    this.endOcclusion,
  });
  final Animation<double> animation;
  final Widget child;
  final ImageProvider? imageProvider;
  final Size faceSize;
  final PaperCoverPlane beginPlane;
  final PaperCoverPlane endPlane;
  final Color backingColor;
  final Path? beginOcclusion;
  final Path? endOcclusion;

  @override
  State<PaperCoverFlight> createState() => _PaperCoverFlightState();
}

class _PaperCoverFlightState extends State<PaperCoverFlight> {
  final _face = GlobalKey();
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _info;
  ui.Image? _fallback;
  bool _snapshotRequested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(PaperCoverFlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider) _resolveImage();
  }

  void _resolveImage() {
    final provider = widget.imageProvider;
    if (provider == null) return;
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    if (_listener != null) _stream?.removeListener(_listener!);
    _stream = stream;
    _listener = ImageStreamListener(
      (info, synchronous) {
        if (!mounted) {
          info.dispose();
          return;
        }
        _info?.dispose();
        _info = info;
        if (!synchronous && mounted) setState(() {});
      },
      onError: (Object error, StackTrace? stack) {
        // The normal cover already handles image failure. Its exact fallback
        // face is captured once, rather than decoded/requested a second time.
      },
    );
    stream.addListener(_listener!);
  }

  void _cacheFallback() {
    if (_snapshotRequested || _info != null || _fallback != null) return;
    _snapshotRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _info != null) return;
      final boundary = _face.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary || boundary.size.isEmpty) return;
      // A small GPU-only cover texture, once per flight. No page readback,
      // screenshot, asynchronous decode or repeated subtree paint per frame.
      final scale =
          MediaQuery.devicePixelRatioOf(context) *
          math.max(
            1.0,
            widget.faceSize.longestSide / boundary.size.longestSide,
          );
      try {
        final image = boundary.toImageSync(pixelRatio: scale.clamp(1.0, 8.0));
        setState(() => _fallback = image);
      } on FlutterError {
        // Keep the original face on renderers without synchronous textures.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    _cacheFallback();
    return RepaintBoundary(
      child: PaperCoverBend(
        key: const ValueKey('paper-cover-transform'),
        animation: widget.animation,
        image: _info?.image ?? _fallback,
        imageIsFitted: _info == null,
        faceSize: widget.faceSize,
        beginPlane: widget.beginPlane,
        endPlane: widget.endPlane,
        backingColor: widget.backingColor,
        beginOcclusion: widget.beginOcclusion,
        endOcclusion: widget.endOcclusion,
        child: _info == null
            ? RepaintBoundary(key: _face, child: widget.child)
            : widget.child,
      ),
    );
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _info?.dispose();
    _fallback?.dispose();
    super.dispose();
  }
}

/// One textured GPU mesh, not 24 paints/clips of the full cover subtree.
/// Animation ticks invalidate only this paint, without rebuilding widgets.
class PaperCoverBend extends SingleChildRenderObjectWidget {
  const PaperCoverBend({
    super.key,
    this.progress = 0,
    this.animation,
    this.image,
    this.imageIsFitted = false,
    this.faceSize = const Size(120, 164),
    this.beginPlane = PaperCoverPlane.flat,
    this.endPlane = PaperCoverPlane.flat,
    this.backingColor = const Color(0xFF202020),
    this.beginOcclusion,
    this.endOcclusion,
    required super.child,
  });
  final double progress;
  final Animation<double>? animation;
  final ui.Image? image;
  final bool imageIsFitted;
  final Size faceSize;
  final PaperCoverPlane beginPlane;
  final PaperCoverPlane endPlane;
  final Color backingColor;
  final Path? beginOcclusion;
  final Path? endOcclusion;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      PaperCoverRender(this);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as PaperCoverRender).update(this);
  }
}

class PaperCoverRender extends RenderProxyBox {
  PaperCoverRender(this.config);
  PaperCoverBend config;
  ui.ImageShader? _shader;
  ui.Image? _shaderImage;
  List<double> _rows = const [];
  Float32List _positions = Float32List(0);
  Float32List _texture = Float32List(0);
  Uint16List _indices = Uint16List(0);
  Int32List _faceColors = Int32List(0);
  final _paint = Paint()..isAntiAlias = true;
  final _fallbackLayer = LayerHandle<TransformLayer>();
  final _fallbackClipLayer = LayerHandle<ClipPathLayer>();
  int debugMeshDraws = 0;
  int debugChildPaints = 0;
  double get progress => config.animation?.value ?? config.progress;

  ({Path path, double alpha})? _occlusion() {
    final departing = config.beginOcclusion;
    final arriving = config.endOcclusion;
    if (departing != null && progress < .12) {
      return (
        path: departing,
        alpha: 1 - Curves.easeInOut.transform((progress / .12).clamp(0.0, 1.0)),
      );
    }
    if (arriving != null && progress > .88) {
      return (
        path: arriving,
        alpha: Curves.easeInOut.transform(
          ((progress - .88) / .12).clamp(0.0, 1.0),
        ),
      );
    }
    return null;
  }

  PaperCoverPlane get debugPlane {
    if (progress <= 0) return config.beginPlane;
    if (progress >= 1) return config.endPlane;
    final depart = Curves.easeInOutCubic.transform(
      ((progress - .02) / .32).clamp(0.0, 1.0),
    );
    final contact = Curves.easeInOutCubic.transform(
      ((progress - .58) / .42).clamp(0.0, 1.0),
    );
    return PaperCoverPlane.lerp(
      PaperCoverPlane.lerp(config.beginPlane, PaperCoverPlane.flat, depart),
      config.endPlane,
      contact,
    );
  }

  void update(PaperCoverBend value) {
    if (config.animation != value.animation) {
      if (attached) config.animation?.removeListener(markNeedsPaint);
      if (attached) value.animation?.addListener(markNeedsPaint);
    }
    if (config.faceSize != value.faceSize) _rows = const [];
    config = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    config.animation?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    config.animation?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  Rect get paintBounds => (Offset.zero & size).inflate(28);

  void _prepareMesh(ui.Image image, PaperFlightPose pose) {
    if (_shaderImage != image) {
      _shader?.dispose();
      _shaderImage = image;
      _shader = ui.ImageShader(
        image,
        TileMode.clamp,
        TileMode.clamp,
        Matrix4.identity().storage,
        filterQuality: FilterQuality.low,
      );
      _paint.shader = _shader;
    }
    final face = config.faceSize;
    final radiusY = (8 / face.height).clamp(0.0, .5);
    final radiusX = (8 / face.width).clamp(0.0, .5);
    if (_rows.isEmpty) {
      final rows = <double>{for (var i = 0; i <= 32; i++) i / 32};
      for (var i = 1; i <= 8; i++) {
        final v = radiusY * (1 - math.cos(i / 8 * math.pi / 2));
        rows.add(v);
        rows.add(1 - v);
      }
      _rows = rows.toList()..sort();
      const columns = 17;
      _positions = Float32List(_rows.length * columns * 2);
      _texture = Float32List(_positions.length);
      _indices = Uint16List((_rows.length - 1) * (columns - 1) * 6);
      var triangle = 0;
      for (var row = 0; row < _rows.length - 1; row++) {
        for (var column = 0; column < columns - 1; column++) {
          final topLeft = row * columns + column;
          final bottomLeft = topLeft + columns;
          for (final index in [
            topLeft,
            bottomLeft,
            topLeft + 1,
            topLeft + 1,
            bottomLeft,
            bottomLeft + 1,
          ]) {
            _indices[triangle++] = index;
          }
        }
      }
      _faceColors = Int32List(_positions.length ~/ 2);
    }
    // Transparent artwork keeps the same milk-white substrate during flight.
    _faceColors.fillRange(
      0,
      _faceColors.length,
      config.backingColor.toARGB32(),
    );
    final input = Size(image.width.toDouble(), image.height.toDouble());
    final source = config.imageIsFitted
        ? Offset.zero & input
        : Alignment.center.inscribe(
            applyBoxFit(BoxFit.cover, input, face).source,
            Offset.zero & input,
          );
    final plane = debugPlane;
    for (var index = 0; index < _rows.length; index++) {
      final v = _rows[index];
      final corner = math.min(v, 1 - v) / radiusY;
      final inset = corner >= 1
          ? 0.0
          : radiusX *
                (1 - math.sqrt(math.max(0, 1 - (1 - corner) * (1 - corner))));
      const columns = 17;
      for (var column = 0; column < columns; column++) {
        final u = inset + (1 - 2 * inset) * column / (columns - 1);
        final scale = 300 / (300 - pose.depthAt(v, column: u));
        final base = (index * columns + column) * 2;
        final projected = plane.point(
          .5 + (u - .5) * scale,
          .5 + (v - .5) * scale,
        );
        _positions[base] = size.width * projected.dx;
        _positions[base + 1] = size.height * projected.dy;
        _texture[base] = source.left + source.width * u;
        _texture[base + 1] = source.top + source.height * v;
      }
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty || child == null) return;
    final pose = PaperFlightPose(progress);
    final image = config.image;
    final occlusion = _occlusion();
    final mask = occlusion?.path.transform(
      Matrix4.inverted(getTransformTo(null)).storage,
    );
    if (image == null) {
      // Only the first frame (or an unsupported renderer) uses the original
      // face. It is never replayed in bands, even for a composited fallback.
      debugChildPaints++;
      final matrix = Matrix4.identity()
        ..translateByDouble(size.width / 2, size.height / 2 - pose.lift, 0, 1)
        ..rotateZ(pose.roll)
        ..translateByDouble(-size.width / 2, -size.height / 2, 0, 1)
        ..multiply(debugPlane.matrix(size));
      void paintFace(PaintingContext context, Offset offset) {
        _fallbackLayer.layer = context.pushTransform(
          needsCompositing,
          offset,
          matrix,
          (context, offset) => super.paint(context, offset),
          oldLayer: _fallbackLayer.layer,
        );
      }

      if (mask == null) {
        _fallbackClipLayer.layer = null;
        paintFace(context, offset);
      } else {
        _fallbackClipLayer.layer = context.pushClipPath(
          needsCompositing,
          offset,
          paintBounds,
          Path.combine(
            PathOperation.difference,
            Path()..addRect(paintBounds),
            mask,
          ),
          paintFace,
          oldLayer: _fallbackClipLayer.layer,
        );
      }
      return;
    }
    _fallbackLayer.layer = null;
    _fallbackClipLayer.layer = null;
    _prepareMesh(image, pose);
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      _positions,
      textureCoordinates: _texture,
      colors: config.imageIsFitted ? null : _faceColors,
      indices: _indices,
    );
    final canvas = context.canvas;
    if (mask != null) canvas.saveLayer(paintBounds.shift(offset), Paint());
    canvas.save();
    canvas.translate(
      offset.dx + size.width / 2,
      offset.dy + size.height / 2 - pose.lift,
    );
    canvas.rotate(pose.roll);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawVertices(vertices, BlendMode.srcOver, _paint);
    canvas.restore();
    if (mask != null) {
      canvas.drawPath(
        mask.shift(offset),
        Paint()
          ..blendMode = BlendMode.dstOut
          ..color = Colors.black.withValues(alpha: occlusion!.alpha),
      );
      canvas.restore();
    }
    vertices.dispose();
    debugMeshDraws++;
  }

  @override
  void dispose() {
    _fallbackLayer.layer = null;
    _fallbackClipLayer.layer = null;
    _shader?.dispose();
    super.dispose();
  }
}
