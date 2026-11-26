import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/foundation/auth.dart';
import '../../lib/foundation/platform.dart';
import '../../lib/foundation/transport.dart';

final _big = base64Encode(List.filled(20, 7));
final _small = base64Encode([
  ...List.filled(20, 9),
  ...ascii.encode('1234567890ABCDEF'),
]);

class _Frames implements FoundationPlatform {
  _Frames() {
    final rng = Random(91);
    background = Uint8List(280 * 160 * 4);
    piece = Uint8List(56 * 160 * 4);
    for (var i = 0; i < 280 * 160; i++) {
      final value = 30 + rng.nextInt(200);
      for (var c = 0; c < 3; c++) {
        background[i * 4 + c] = value;
      }
      background[i * 4 + 3] = 255;
    }
    for (var y = 48; y < 104; y++) {
      for (var x = 4; x < 52; x++) {
        final src = (y * 280 + 110 + x) * 4, dst = (y * 56 + x) * 4;
        for (var c = 0; c < 3; c++) {
          piece[dst + c] = background[src + c];
          background[src + c] = (background[src + c] * .55).round();
        }
        piece[dst + 3] = 255;
      }
    }
  }
  late Uint8List background, piece;
  Map<String, dynamic>? submitted;
  @override
  Future<Map<String, dynamic>> invoke(
    String operation, [
    Map<String, dynamic> args = const {},
  ]) async {
    if (operation == 'raster') {
      final big = args['data'] == _big;
      return {
        'width': big ? 280 : 56,
        'height': 160,
        'pixels': base64Encode(big ? background : piece),
      };
    }
    if (operation == 'aes') {
      submitted =
          jsonDecode(
                utf8.decode(base64Decode(args['data'] as String).sublist(64)),
              )
              as Map<String, dynamic>;
      return {'data': 'synthetic-sign'};
    }
    throw StateError('Public challenge must not access credentials');
  }

  @override
  Future<String?> load(String key) => throw StateError('No credential reads');
  @override
  Future<void> save(String key, String value) =>
      throw StateError('No credential writes');
  @override
  Future<void> clear(String key) => throw StateError('No credential changes');
}

class _Protocol extends SchoolTransport {
  int verifications = 0;
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
    Object data = '';
    if (uri.path.endsWith('openSliderCaptcha.htl')) {
      data = {
        'bigImage': _big,
        'smallImage': _small,
        'tagWidth': 56,
        'yHeight': 48,
      };
    }
    if (uri.path.endsWith('verifySliderCaptcha.htl')) {
      verifications++;
      expect(method, 'POST');
      expect(form, {'sign': 'synthetic-sign'});
      data = {'errorCode': 1};
    }
    return SchoolResponse(
      status: 200,
      uri: uri,
      bytes: Uint8List.fromList(
        utf8.encode(data is String ? data : jsonEncode(data)),
      ),
    );
  }
}

void main() {
  test(
    'Challenge verification waits for movement and submits actual elapsed intervals',
    () async {
      final platform = _Frames(), http = _Protocol();
      int? observed;
      final auth = SchoolAuthentication(
        platform,
        transportFactory: () => http,
        observer: (event) async {
          if (event['stage'] == 'slider-movement')
            observed = event['elapsedMs'] as int;
        },
      );
      final clock = Stopwatch()..start();
      try {
        await auth.verifyCaptcha();
        final body = platform.submitted!;
        final points = body['tracks'] as List;
        final elapsed = points.fold<int>(0, (sum, p) => sum + (p['c'] as int));
        expect(elapsed, greaterThan(1700));
        expect(clock.elapsedMilliseconds, greaterThanOrEqualTo(elapsed));
        expect(observed, elapsed);
        expect(points.last['a'], body['moveLength']);
        expect(http.verifications, 1);
      } finally {
        auth.cancel();
      }
    },
  );
  test('Cancellation before movement never submits the challenge', () async {
    final platform = _Frames(), http = _Protocol();
    late SchoolAuthentication auth;
    auth = SchoolAuthentication(
      platform,
      transportFactory: () => http,
      observer: (event) async {
        if (event['stage'] == 'slider') auth.cancel();
      },
    );
    await expectLater(
      auth.verifyCaptcha(),
      throwsA(
        isA<FoundationException>().having((e) => e.code, 'code', 'cancelled'),
      ),
    );
    expect(http.verifications, 0);
    expect(platform.submitted, isNull);
    auth.cancel();
  });
}
