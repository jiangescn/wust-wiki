import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'delayed_loading.dart';
import 'wiki_motion.dart';

class ArticleReader extends StatefulWidget {
  final String path;
  final ValueChanged<String> open;
  const ArticleReader({required this.path, required this.open, super.key});
  @override
  State<ArticleReader> createState() => _ReaderState();
}

class _ReaderState extends State<ArticleReader> {
  Animation<double>? route;
  MethodChannel? channel;
  bool? dark;
  bool ready = false, failed = false, entered = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextDark = Theme.of(context).brightness == Brightness.dark;
    if (ready && WikiMotion.reduced(context)) {
      channel?.invokeMethod('playText', true);
    }
    if (dark != null && dark != nextDark)
      channel?.invokeMethod('theme', nextDark);
    dark = nextDark;
    final next = ModalRoute.of(context)?.animation;
    if (route != next) {
      route?.removeStatusListener(status);
      route = next;
      next?.addStatusListener(status);
    }
    if (next == null || next.isCompleted) entered = true;
  }

  void status(AnimationStatus s) {
    if (mounted && !entered && s == AnimationStatus.completed)
      setState(() => entered = true);
  }

  @override
  void dispose() {
    route?.removeStatusListener(status);
    channel?.setMethodCallHandler(null);
    super.dispose();
  }

  Map<String, bool> get preferences => {
    'dark': dark!,
    'reduce': WikiMotion.reduced(context),
  };

  Future<void> connect(int id) async {
    final ch = MethodChannel('wiki/article/$id');
    channel = ch;
    ch.setMethodCallHandler((call) async {
      if (!mounted) return;
      if (call.method == 'open') {
        widget.open(call.arguments as String);
      } else if (call.method == 'ready' && !failed && !ready) {
        setState(() => ready = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ready) {
            ch.invokeMethod('playText', WikiMotion.reduced(context));
          }
        });
      } else if (call.method == 'error') {
        setState(() {
          failed = true;
          ready = false;
        });
      }
    });
    await ch.invokeMethod('start', preferences);
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (entered)
        IgnorePointer(
          ignoring: !ready,
          child: ExcludeSemantics(
            excluding: !ready,
            child: AndroidView(
              viewType: 'wiki/article',
              creationParamsCodec: const StandardMessageCodec(),
              creationParams: {'path': widget.path, 'dark': dark},
              onPlatformViewCreated: connect,
            ),
          ),
        ),
      if (failed)
        ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(
            child: TextButton(
              onPressed: () {
                setState(() => failed = false);
                channel?.invokeMethod('retry', preferences);
              },
              child: const Text('重新加载正文'),
            ),
          ),
        )
      else if (!ready)
        const DelayedLoading(child: WikiSkeleton(article: true)),
    ],
  );
}
