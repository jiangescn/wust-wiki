import 'package:flutter/material.dart';

import 'archive_motion.dart';

// Timings and spring from Wenku8_Flutter's NovelMotion.
abstract final class WikiMotion {
  static const contact = Duration(milliseconds: 120);
  static const enter = Duration(milliseconds: 420);
  static const exit = Duration(milliseconds: 320);
  static const stickerEnter = Duration(milliseconds: 580);
  static const stickerExit = Duration(milliseconds: 460);
  static const ease = Curves.easeOutCubic;
  static const settle = Cubic(.2, 1.08, .34, 1);
  static const spring = SpringDescription(
    mass: .64,
    stiffness: 270,
    damping: 19,
  );

  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);
}

Future<T?> showWikiSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: WikiMotion.reduced(context)
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: WikiMotion.enter,
              reverseDuration: WikiMotion.exit,
            ),
      builder: (context) => ArchiveMotionScope(
        animation: ModalRoute.of(context)!.animation!,
        enabled: !WikiMotion.reduced(context),
        child: builder(context),
      ),
    );

Future<T?> showWikiDialog<T>(BuildContext context, WidgetBuilder builder) =>
    showDialog<T>(
      context: context,
      builder: builder,
      animationStyle: WikiMotion.reduced(context)
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: WikiMotion.enter,
              curve: WikiMotion.ease,
              reverseCurve: Curves.easeInCubic,
            ),
    );

/// Compact placeholders use the same surface and typography rhythm as the
/// loaded list or article. The loading owner decides when to hand it off.
class WikiSkeleton extends StatelessWidget {
  const WikiSkeleton({super.key, this.article = false});

  final bool article;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: article ? '正在加载正文' : '正在加载',
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: LayoutBuilder(
          builder: (context, bounds) {
            Widget bar(double fraction, double height) => Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                width: (bounds.maxWidth - 40).clamp(0.0, 640.0) * fraction,
                height: height,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            );

            return ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              children: [
                for (var group = 0; group < 3; group++) ...[
                  bar(group == 0 ? .62 : .46, article ? 20 : 17),
                  const SizedBox(height: 14),
                  bar(1, 11),
                  const SizedBox(height: 9),
                  bar(.84, 11),
                  const SizedBox(height: 9),
                  bar(group.isEven ? .72 : .57, 11),
                  const SizedBox(height: 24),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
