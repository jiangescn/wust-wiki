// Public CAPTCHA diagnosis only: no account/credential access, no production entry.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'auth.dart';
import 'flutter_platform.dart';
import 'platform.dart';
import 'slider.dart';
import 'transport.dart';

const _timingOnly =
    String.fromEnvironment('SLIDER_ISOLATION_KIND') == 'same-payload-later';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: _Isolation()));
}

class _Done implements Exception {}

class _Capture implements FoundationPlatform {
  final inner = const AndroidFoundationPlatform();
  final frames = <SliderRaster>[];
  Map<String, dynamic>? aesArgs, variedPayload;
  Uint8List? prefix;
  @override
  Future<Map<String, dynamic>> invoke(
    String operation, [
    Map<String, dynamic> args = const {},
  ]) async {
    if (operation == 'raster') {
      final result = await inner.invoke(operation, args);
      frames.add(
        SliderRaster(
          result['width'] as int,
          result['height'] as int,
          base64Decode(result['pixels'] as String),
        ),
      );
      return result;
    }
    if (operation != 'aes') throw StateError('Public challenge only');
    final bytes = base64Decode(args['data'] as String);
    final payload =
        jsonDecode(utf8.decode(bytes.sublist(64))) as Map<String, dynamic>;
    if (!payload.containsKey('tracks'))
      throw StateError('Account encryption is forbidden');
    variedPayload = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
    aesArgs = Map.of(args);
    prefix = Uint8List.fromList(bytes.sublist(0, 64));
    if (_timingOnly) return inner.invoke('aes', args);
    final points = payload['tracks'] as List;
    for (var i = 0; i < points.length; i++) {
      final progress = i / (points.length - 1);
      points[i]['a'] = i == points.length - 1
          ? payload['moveLength']
          : (payload['moveLength'] as num) * progress;
      points[i]['b'] = math.sin(progress * math.pi) * 2;
    }
    return inner.invoke('aes', {
      ...args,
      'data': base64Encode([...prefix!, ...utf8.encode(jsonEncode(payload))]),
    });
  }

  Future<String> encryptSecond() async {
    final body = variedPayload!;
    if (_timingOnly) {
      final duration = (body['tracks'] as List).fold<int>(
        0,
        (sum, p) => sum + (p['c'] as int),
      );
      await Future<void>.delayed(Duration(milliseconds: duration));
      final repeated = await inner.invoke('aes', aesArgs!);
      return repeated['data'] as String;
    }
    final watch = Stopwatch()..start();
    var previous = 0;
    for (final point in (body['tracks'] as List).skip(1)) {
      await Future<void>.delayed(Duration(milliseconds: point['c'] as int));
      final now = watch.elapsedMilliseconds;
      point['c'] = now - previous;
      previous = now;
    }
    final result = await inner.invoke('aes', {
      ...aesArgs!,
      'data': base64Encode([...prefix!, ...utf8.encode(jsonEncode(body))]),
    });
    return result['data'] as String;
  }

  @override
  Future<String?> load(String key) => throw StateError('No credential reads');
  @override
  Future<void> save(String key, String value) =>
      throw StateError('No credential writes');
  @override
  Future<void> clear(String key) => throw StateError('No credential changes');
}

class _SameChallenge extends SchoolTransport {
  _SameChallenge(this.capture);
  final _Capture capture;
  final result = <String, dynamic>{};
  int yHeight = 0;
  @override
  Future<SchoolResponse> send(
    Uri uri, {
    String method = 'GET',
    Map<String, String>? form,
    List<MapEntry<String, String>>? formFields,
    Object? jsonBody,
    Map<String, String> headers = const {},
    bool followRedirects = true,
  }) async {
    final cookieBefore = cookies.header(uri);
    final response = await super.send(
      uri,
      method: method,
      form: form,
      formFields: formFields,
      jsonBody: jsonBody,
      headers: headers,
      followRedirects: followRedirects,
    );
    if (uri.path.endsWith('openSliderCaptcha.htl')) {
      capture.frames.clear();
      capture.aesArgs = null;
      capture.variedPayload = null;
      yHeight = (response.json as Map)['yHeight'] as int;
    }
    if (!uri.path.endsWith('verifySliderCaptcha.htl')) return response;
    final first = (response.json as Map)['errorCode'];
    result.addAll({
      'firstCode': first,
      'sameImageAndTarget': true,
      'firstMotion': _timingOnly
          ? 'varied coordinates; actual sample intervals'
          : 'linear coordinates; actual sample intervals',
      'secondMotion': _timingOnly
          ? 'identical ciphertext submitted later'
          : 'varied coordinates; actual sample intervals',
      'cookieUnchangedAfterFirst': cookieBefore == cookies.header(uri),
    });
    if (first == 0 && capture.variedPayload != null) {
      final sign = await capture.encryptSecond();
      result['ciphertextUnchanged'] = sign == form?['sign'];
      final second = await super.send(
        uri,
        method: 'POST',
        form: {'sign': sign},
        headers: headers,
        followRedirects: followRedirects,
      );
      result['secondCode'] = (second.json as Map)['errorCode'];
    }
    throw _Done();
  }
}

Future<ui.Image> _image(SliderRaster frame) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    frame.pixels,
    frame.width,
    frame.height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

class _Isolation extends StatefulWidget {
  const _Isolation();
  @override
  State<_Isolation> createState() => _IsolationState();
}

class _IsolationState extends State<_Isolation> {
  final cases = <Map<String, dynamic>>[];
  ui.Image? background, piece;
  double offset = 0, move = 0, y = 0;
  String status = 'Public CAPTCHA location/trajectory diagnosis';
  bool decisive = false;
  String selected = '';
  @override
  void initState() {
    super.initState();
    unawaited(run());
  }

  Future<void> run() async {
    for (var index = 0; index < 5; index++) {
      final capture = _Capture();
      final http = _SameChallenge(capture);
      Map<String, dynamic>? geometry;
      final auth = SchoolAuthentication(
        capture,
        transportFactory: () => http,
        observer: (event) async {
          if (event['stage'] == 'slider') geometry = Map.of(event);
        },
      );
      try {
        await auth.verifyCaptcha(withService: true);
      } on _Done {
      } catch (error) {
        http.result['error'] = error is FoundationException
            ? error.code
            : error.runtimeType.toString();
      } finally {
        auth.cancel();
      }
      final result = <String, dynamic>{
        'case': index + 1,
        ...http.result,
        if (geometry != null)
          for (final key in ['offset', 'score', 'width', 'height'])
            key: geometry![key],
      };
      cases.add(result);
      final proved = result['firstCode'] == 0 && result['secondCode'] == 1;
      if (capture.frames.length >= 2 &&
          geometry != null &&
          (!decisive || proved)) {
        final bg = await _image(capture.frames.first),
            p = await _image(capture.frames.last);
        background?.dispose();
        piece?.dispose();
        background = bg;
        piece = p;
        offset = (geometry!['offset'] as num).toDouble();
        move = (capture.variedPayload!['moveLength'] as num).toDouble();
        y = (capture.frames.last.height - bg.height).abs() <= 2
            ? 0
            : http.yHeight.toDouble();
        decisive = proved;
        selected =
            'Image case ${index + 1}: ${result['firstCode']} -> ${result['secondCode']}; offset $offset; score ${geometry!['score']}';
      }
      await const AndroidFoundationPlatform().invoke('acceptanceStatus', {
        'mode': _timingOnly
            ? 'slider-timing-isolation'
            : 'slider-location-isolation',
        'state': index == 4 ? 'complete' : 'running',
        'submittedAccountCredentials': false,
        'sameTargetDifferentMotionAccepted': cases.any(
          (c) => c['firstCode'] == 0 && c['secondCode'] == 1,
        ),
        'cases': cases,
      });
      if (mounted)
        setState(
          () => status =
              'Cases ${index + 1}/5; same-target 0 -> 1: ${cases.any((c) => c['firstCode'] == 0 && c['secondCode'] == 1)}',
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Public slider diagnosis')),
    body: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(status),
        Text(selected),
        if (background != null) ...[
          const Text('1. Original background'),
          _pane(0),
          const Text('2. Piece at calculated image offset'),
          _pane(1),
          const Text('3. Official 280px canvas geometry'),
          _pane(2),
        ],
      ],
    ),
  );
  Widget _pane(int mode) => AspectRatio(
    aspectRatio: mode == 2 ? 280 / 155 : background!.width / background!.height,
    child: CustomPaint(
      painter: _Overlay(background!, piece!, offset, move, y, mode),
    ),
  );
}

class _Overlay extends CustomPainter {
  _Overlay(this.bg, this.piece, this.offset, this.move, this.y, this.mode);
  final ui.Image bg, piece;
  final double offset, move, y;
  final int mode;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()..filterQuality = FilterQuality.none;
    if (mode == 2) {
      canvas.scale(size.width / 280, size.height / 155);
      canvas.drawImageRect(
        bg,
        Rect.fromLTWH(0, 0, bg.width.toDouble(), bg.height.toDouble()),
        const Rect.fromLTWH(0, 0, 278, 155),
        paint,
      );
      canvas.drawImageRect(
        piece,
        Rect.fromLTWH(0, 0, piece.width.toDouble(), piece.height.toDouble()),
        Rect.fromLTWH(
          move,
          y * 155 / bg.height,
          piece.width * 280 / bg.width - 2,
          155,
        ),
        paint,
      );
    } else {
      canvas.scale(size.width / bg.width, size.height / bg.height);
      canvas.drawImage(bg, Offset.zero, paint);
      if (mode == 1) canvas.drawImage(piece, Offset(offset, y), paint);
    }
  }

  @override
  bool shouldRepaint(_Overlay old) =>
      old.bg != bg || old.mode != mode || old.offset != offset;
}
