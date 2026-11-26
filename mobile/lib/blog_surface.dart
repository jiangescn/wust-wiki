import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'archive_motion.dart';
import 'wiki_motion.dart';
import 'wiki_sticker_flight.dart';

// blog-v3 color.scss: primary hue 220°, accent hue 180°.
Color blogTint(BuildContext context, double hue) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (hue == 220)
    return dark ? const Color(0xff6699ff) : const Color(0xff1a66ff);
  // Colored text uses a deeper tone on paper; fills mix this tint into the surface.
  return HSLColor.fromAHSL(1, hue, .70, dark ? .72 : .34).toColor();
}

class BlogPanel extends StatelessWidget {
  const BlogPanel(
    this.child, {
    this.hue = 220,
    this.padding = const EdgeInsets.all(16),
    this.quiet = false,
    super.key,
  });
  final Widget child;
  final double hue;
  final EdgeInsetsGeometry padding;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final accent = blogTint(context, hue);
    final paper = Theme.of(context).colorScheme.surface;
    Color wash(double alpha) =>
        Color.alphaBlend(accent.withValues(alpha: alpha), paper);
    final corners = BorderRadius.circular(16);
    return Material(
      color: paper,
      shape: RoundedRectangleBorder(
        borderRadius: corners,
        side: BorderSide(
          color: quiet
              ? Theme.of(context).colorScheme.outlineVariant
              : wash(.26),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: corners,
          gradient: quiet
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [wash(.14), wash(.045), paper],
                ),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class BlogIcon extends StatelessWidget {
  const BlogIcon(this.icon, {this.hue = 220, super.key});
  final IconData icon;
  final double hue;
  @override
  Widget build(BuildContext context) {
    final tint = blogTint(context, hue);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: tint, size: 22),
      ),
    );
  }
}

class WikiMenuTile extends StatelessWidget {
  const WikiMenuTile({
    required this.leading,
    required this.label,
    required this.onTap,
    this.detail,
    super.key,
  });

  final Widget leading;
  final String label;
  final Widget? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: leading,
    title: Text(label),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?detail,
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right_rounded),
      ],
    ),
    onTap: onTap,
  );
}

class WikiPageMark extends StatelessWidget {
  const WikiPageMark(
    this.path,
    this.icon, {
    this.hue = 220,
    this.face,
    this.inTitle = false,
    super.key,
  });
  final String path;
  final IconData icon;
  final double hue;
  final Widget? face;
  final bool inTitle;

  @override
  Widget build(BuildContext context) {
    final mark = BlogIcon(icon, hue: hue);
    final child = face ?? mark;
    return WikiMotion.reduced(context)
        ? child
        : Hero(
            tag: ('wiki-page', path),
            transitionOnUserGestures: true,
            createRectTween: (begin, end) => PaperCoverRectTween.toHero(
              context: context,
              begin: begin,
              end: end,
              returning: !inTitle,
            ),
            flightShuttleBuilder: (context, animation, direction, from, to) {
              final pushing = direction == HeroFlightDirection.push;
              final source = pushing ? from : to;
              final destination = pushing ? to : from;
              final route = ModalRoute.of(destination)?.animation;
              final clock = route ?? animation;
              final progress = pushing ? clock : ReverseAnimation(clock);
              final sourceFace = (source.widget as Hero).child;
              final targetFace = (destination.widget as Hero).child;
              final beginPlane = PaperCoverPlane.fromHero(source);
              final endPlane = PaperCoverPlane.fromHero(destination);
              final box = destination.findRenderObject();
              final faceSize =
                  box is RenderBox && box.hasSize && !box.size.isEmpty
                  ? box.size
                  : const Size.square(38);
              Widget paper(Widget face) => PaperCoverFlight(
                animation: clock,
                faceSize: faceSize,
                beginPlane: beginPlane,
                endPlane: endPlane,
                child: FittedBox(fit: BoxFit.fill, child: face),
              );

              final sameFace =
                  sourceFace is BlogIcon &&
                  targetFace is BlogIcon &&
                  sourceFace.icon == targetFace.icon &&
                  sourceFace.hue == targetFace.hue;
              final swap = clock.drive(
                CurveTween(
                  curve: const Interval(.88, .98, curve: Curves.easeInOut),
                ),
              );
              // Capture both faces even before either has faded into view.
              final visible = Tween<double>(begin: 1 / 255, end: 1);
              return WikiStickerRipple(
                progress: progress,
                color: blogTint(context, hue),
                child: sameFace
                    ? paper(sourceFace)
                    : Stack(
                        clipBehavior: Clip.none,
                        fit: StackFit.expand,
                        children: [
                          FadeTransition(
                            opacity: ReverseAnimation(swap).drive(visible),
                            child: paper(sourceFace),
                          ),
                          FadeTransition(
                            opacity: swap.drive(visible),
                            child: paper(targetFace),
                          ),
                        ],
                      ),
              );
            },
            child: child,
          );
  }
}

class WikiStickerRipple extends StatelessWidget {
  const WikiStickerRipple({
    required this.progress,
    required this.color,
    required this.child,
    super.key,
  });

  final Animation<double> progress;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => WikiMotion.reduced(context)
      ? child
      : RepaintBoundary(
          child: CustomPaint(
            foregroundPainter: StickerRipplePainter(progress, color),
            child: child,
          ),
        );
}

class StickerRipplePainter extends CustomPainter {
  StickerRipplePainter(this.progress, this.color) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final t = ((progress.value - .72) / .28).clamp(0.0, 1.0);
    if (size.isEmpty || t == 0 || t == 1) return;
    final bounds = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(12)),
    );
    for (final lag in [0.0, .20]) {
      final phase = ((t - lag) / (1 - lag)).clamp(0.0, 1.0);
      final alpha = math.sin(math.pi * phase);
      if (alpha <= 0) continue;
      final radius =
          size.shortestSide * (.12 + .64 * WikiMotion.ease.transform(phase));
      canvas.drawCircle(
        bounds.center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = color.withValues(alpha: alpha * .50),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(StickerRipplePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class WikiPageTitle extends StatelessWidget {
  const WikiPageTitle(this.title, {this.mark, super.key});
  final String title;
  final WikiPageMark? mark;

  @override
  Widget build(BuildContext context) {
    final text = ContentReveal(
      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      revision: title,
      axis: ArchiveRevealAxis.horizontal,
    );
    if (mark == null) return text;
    return Row(
      children: [
        ExcludeSemantics(
          child: WikiPageMark(
            mark!.path,
            mark!.icon,
            hue: mark!.hue,
            inTitle: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: text),
      ],
    );
  }
}

// Same paint-only reveal used by Wenku8; restart on a content change without
// replacing descendants (e.g. a focused field or the scroll position).
class ContentReveal extends StatefulWidget {
  const ContentReveal(
    this.child, {
    this.revision,
    this.axis = ArchiveRevealAxis.vertical,
    super.key,
  }) : grouped = false,
       lift = false;
  const ContentReveal.grouped(this.child, {this.revision, super.key})
    : axis = ArchiveRevealAxis.vertical,
      grouped = true,
      lift = true;
  const ContentReveal.sequence(this.child, {this.revision, super.key})
    : axis = ArchiveRevealAxis.vertical,
      grouped = true,
      lift = false;
  final Widget child;
  final Object? revision;
  final ArchiveRevealAxis axis;
  final bool grouped;
  final bool lift;
  @override
  State<ContentReveal> createState() => _ContentRevealState();
}

class _ContentRevealState extends State<ContentReveal>
    with SingleTickerProviderStateMixin {
  late final clock = AnimationController(
    vsync: this,
    duration: WikiMotion.enter,
  );
  late final rise = clock.drive(CurveTween(curve: WikiMotion.ease));
  bool? reduced;
  Animation<double>? arrival;

  void startOnArrival(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final route = arrival;
    route?.removeStatusListener(startOnArrival);
    arrival = null;
    clock.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = MediaQuery.disableAnimationsOf(context);
    if (next) {
      arrival?.removeStatusListener(startOnArrival);
      arrival = null;
      clock.value = 1;
    } else if (reduced == null) {
      final route = ModalRoute.of(context)?.animation;
      arrival = route;
      if (route == null) {
        startOnArrival(AnimationStatus.completed);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || arrival != route) return;
          route.addStatusListener(startOnArrival);
          startOnArrival(route.status);
        });
      }
    }
    reduced = next;
  }

  @override
  void didUpdateWidget(ContentReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision &&
        reduced == false &&
        arrival == null) {
      clock.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (reduced == true) return widget.child;
    if (widget.grouped) {
      final parts = ArchiveMotionScope(animation: clock, child: widget.child);
      if (!widget.lift) return parts;
      return AnimatedBuilder(
        animation: rise,
        child: RepaintBoundary(child: parts),
        builder: (_, child) => Transform.translate(
          offset: Offset(0, 10 * (1 - rise.value)),
          child: Opacity(opacity: .68 + .32 * rise.value, child: child),
        ),
      );
    }
    return ArchiveReveal(
      animation: clock,
      axis: widget.axis,
      travel: widget.axis == ArchiveRevealAxis.horizontal
          ? const Offset(-10, 0)
          : const Offset(0, 8),
      child: widget.child,
    );
  }

  @override
  void dispose() {
    arrival?.removeStatusListener(startOnArrival);
    clock.dispose();
    super.dispose();
  }
}

// Adapted from the press/cancel handling in Wenku8's app_ui.dart.
class WikiPress extends StatefulWidget {
  const WikiPress({required this.onTap, required this.child, super.key});
  final VoidCallback onTap;
  final Widget child;
  @override
  State<WikiPress> createState() => _WikiPressState();
}

class _WikiPressState extends State<WikiPress> {
  bool pressed = false, cancelled = false;
  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: pressed && !MediaQuery.disableAnimationsOf(context) ? .97 : 1,
    curve: WikiMotion.settle,
    duration: MediaQuery.disableAnimationsOf(context) || cancelled
        ? Duration.zero
        : (pressed ? WikiMotion.contact : WikiMotion.enter),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      splashFactory: WikiMotion.reduced(context)
          ? NoSplash.splashFactory
          : InkRipple.splashFactory,
      splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: .20),
      onTap: widget.onTap,
      onTapCancel: () => cancelled = true,
      onHighlightChanged: (value) => setState(() {
        pressed = value;
        if (value) cancelled = false;
      }),
      child: widget.child,
    ),
  );
}
