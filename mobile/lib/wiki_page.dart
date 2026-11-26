import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;

import 'wiki_motion.dart';

typedef Entry = ({String label, String path, IconData icon});

enum WikiTab {
  home('首页', Icons.home_outlined),
  schedule('课表', Icons.calendar_month_outlined),
  campus('校园', Icons.newspaper_outlined),
  profile('个人', Icons.person_outline);

  const WikiTab(this.title, this.icon);
  final String title;
  final IconData icon;
}

// Adapted from Wenku8_Flutter's _NovelPageRoute. See licenses/ and README.
class WikiRoute extends CupertinoPageRoute<void> {
  WikiRoute(Widget page, this.reduceMotion, {this.hasSticker = false})
    : super(builder: (_) => RepaintBoundary(child: page));
  final bool reduceMotion;
  final bool hasSticker;
  @override
  Duration get transitionDuration => reduceMotion
      ? Duration.zero
      : hasSticker
      ? WikiMotion.stickerEnter
      : WikiMotion.enter;
  @override
  Duration get reverseTransitionDuration => reduceMotion
      ? Duration.zero
      : hasSticker
      ? WikiMotion.stickerExit
      : WikiMotion.exit;
}
