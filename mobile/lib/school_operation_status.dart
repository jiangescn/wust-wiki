import 'dart:async';
import 'package:flutter/material.dart';
import 'delayed_loading.dart';
import 'foundation/client.dart';
import 'foundation/progress.dart';
import 'wiki_motion.dart';

class SchoolOperationStatus extends StatelessWidget {
  const SchoolOperationStatus(
    this.api, {
    this.fallback,
    this.cancelLabel = '取消',
    this.onCancel,
    super.key,
  });
  final FoundationApi api;
  final FoundationProgress? fallback;
  final String cancelLabel;
  final VoidCallback? onCancel;
  @override
  Widget build(BuildContext context) {
    if (!TickerMode.valuesOf(context).enabled) return const SizedBox.shrink();
    final events = api is FoundationProgressSource
        ? api as FoundationProgressSource
        : null;
    final reduced = WikiMotion.reduced(context);
    return StreamBuilder<FoundationProgress?>(
      stream: events?.progress,
      initialData: events?.currentProgress,
      builder: (context, snapshot) {
        final live = snapshot.data;
        final progress =
            live != null &&
                (fallback?.resource == null ||
                    live.resource == fallback!.resource)
            ? live
            : fallback;
        return AnimatedSize(
          alignment: Alignment.topCenter,
          duration: reduced ? Duration.zero : const Duration(milliseconds: 210),
          curve: WikiMotion.ease,
          child: progress == null
              ? const SizedBox(width: double.infinity, height: 0)
              : DelayedLoading(
                  key: ValueKey(fallback?.startedAt ?? progress.startedAt),
                  startedAt: fallback?.startedAt ?? progress.startedAt,
                  child: _RunningStatus(
                    progress,
                    cancelLabel: cancelLabel,
                    onCancel: onCancel,
                  ),
                ),
        );
      },
    );
  }
}

class _RunningStatus extends StatefulWidget {
  const _RunningStatus(
    this.progress, {
    required this.cancelLabel,
    this.onCancel,
  });
  final FoundationProgress progress;
  final String cancelLabel;
  final VoidCallback? onCancel;
  @override
  State<_RunningStatus> createState() => _RunningStatusState();
}

class _RunningStatusState extends State<_RunningStatus> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    final seconds = DateTime.now()
        .difference(p.startedAt)
        .inSeconds
        .clamp(0, 9999);
    final colors = Theme.of(context).colorScheme;
    final reduced = WikiMotion.reduced(context);
    final elapsed = seconds < 60
        ? '${seconds} 秒'
        : '${seconds ~/ 60} 分 ${seconds % 60} 秒';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (reduced)
                Icon(
                  Icons.hourglass_top_rounded,
                  color: colors.onPrimaryContainer,
                  size: 18,
                )
              else
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      liveRegion: true,
                      label: p.message,
                      child: ExcludeSemantics(
                        child: AnimatedSwitcher(
                          duration: reduced
                              ? Duration.zero
                              : const Duration(milliseconds: 160),
                          layoutBuilder: (current, previous) => Stack(
                            alignment: AlignmentDirectional.centerStart,
                            children: [...previous, ?current],
                          ),
                          child: Text(
                            p.message,
                            key: ValueKey(p.message),
                            style: TextStyle(
                              color: colors.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    DefaultTextStyle.merge(
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 2,
                        children: [
                          Text('已等待 $elapsed'),
                          if (p.attempt != null) Text('第 ${p.attempt}/5 次尝试'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onCancel != null)
                TextButton(
                  onPressed: widget.onCancel,
                  child: Text(widget.cancelLabel),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
