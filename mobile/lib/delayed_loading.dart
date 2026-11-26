import 'dart:async';

import 'package:flutter/widgets.dart';

class DelayedLoading extends StatefulWidget {
  const DelayedLoading({required this.child, this.startedAt, super.key});

  final DateTime? startedAt;
  final Widget child;

  @override
  State<DelayedLoading> createState() => _DelayedLoadingState();
}

class _DelayedLoadingState extends State<DelayedLoading> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    final remaining =
        const Duration(milliseconds: 500) -
        (widget.startedAt == null
            ? Duration.zero
            : DateTime.now().difference(widget.startedAt!));
    _visible = remaining <= Duration.zero;
    if (!_visible)
      _timer = Timer(remaining, () => setState(() => _visible = true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _visible ? widget.child : const SizedBox.shrink();
}
