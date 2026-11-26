import 'blog_surface.dart';
import 'archive_motion.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DormPage extends StatefulWidget {
  const DormPage({super.key});
  @override
  State<DormPage> createState() => _DormState();
}

class _DormState extends State<DormPage> {
  String area = 'A', room = '', message = '';
  bool active = false;
  bool invalidRoom = false, failed = false;
  Timer? poll;

  void submit() {
    if (active) return;
    if (!RegExp(r'^[0-9]{3,16}$').hasMatch(room)) {
      setState(() {
        invalidRoom = true;
        message = '';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      invalidRoom = false;
      failed = false;
      active = true;
      message = '';
    });
  }

  @override
  void dispose() {
    poll?.cancel();
    super.dispose();
  }

  void connect(int id) {
    final ch = MethodChannel('wiki/dorm/$id');
    int attempts = 0;
    bool busy = false;
    poll?.cancel();
    poll = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (busy) return;
      busy = true;
      try {
        final text = await ch.invokeMethod<String>('status');
        if (!mounted || !active || timer != poll) {
          timer.cancel();
          return;
        }
        if (text != null && text.isNotEmpty) {
          timer.cancel();
          setState(() {
            active = false;
            message = text;
          });
        } else if (++attempts >= 240) {
          timer.cancel();
          setState(() {
            active = false;
            failed = true;
            message = '验证超时，请重新查询。';
          });
        }
      } on PlatformException {
        timer.cancel();
        if (mounted && active && timer == poll)
          setState(() {
            active = false;
            failed = true;
            message = '验证组件不可用，请重试。';
          });
      } finally {
        busy = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      ContentReveal.grouped(
        BlogPanel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ArchivePart.staggered(
                0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '宿舍区域',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final option in ['A', 'B', 'C', 'D'])
                          ChoiceChip(
                            label: Text('$option 区'),
                            selected: area == option,
                            onSelected: active
                                ? null
                                : (_) => setState(() {
                                    area = option;
                                    message = '';
                                  }),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ArchivePart.staggered(
                1,
                child: TextField(
                  enabled: !active,
                  keyboardType: TextInputType.number,
                  maxLength: 16,
                  decoration: InputDecoration(
                    labelText: '完整寝室号',
                    counterText: '',
                    prefixIcon: const Icon(Icons.meeting_room_outlined),
                    errorText: invalidRoom ? '请输入 3 至 16 位数字寝室号。' : null,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => submit(),
                  onChanged: (v) {
                    room = v.trim();
                    if (invalidRoom || message.isNotEmpty)
                      setState(() {
                        invalidRoom = false;
                        message = '';
                      });
                  },
                ),
              ),
              const SizedBox(height: 12),
              ArchivePart.staggered(
                2,
                child: FilledButton.icon(
                  onPressed: active ? null : submit,
                  icon: Icon(
                    active ? Icons.verified_user_outlined : Icons.search,
                  ),
                  label: Text(active ? '等待验证' : '查询寝室'),
                ),
              ),
            ],
          ),
          hue: 178,
          quiet: true,
        ),
      ),
      if (message.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ContentReveal.grouped(
            Semantics(
              liveRegion: true,
              child: BlogPanel(
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BlogIcon(
                      failed
                          ? Icons.info_outline
                          : active
                          ? Icons.verified_user_outlined
                          : Icons.apartment_outlined,
                      hue: failed ? 28 : 178,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ArchivePart(
                        axis: ArchiveRevealAxis.vertical,
                        travel: const Offset(0, 4),
                        child: SelectableText(message),
                      ),
                    ),
                  ],
                ),
                hue: failed ? 28 : 178,
              ),
            ),
            revision: message,
          ),
        ),
      if (active) ...[
        const SizedBox(height: 12),
        SizedBox(
          height: 360,
          child: AndroidView(
            viewType: 'wiki/dorm',
            creationParams: {'area': area, 'room': room},
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: connect,
          ),
        ),
        TextButton(
          onPressed: () {
            poll?.cancel();
            poll = null;
            setState(() {
              active = false;
              message = '';
            });
          },
          child: const Text('取消验证'),
        ),
      ],
    ],
  );
}
