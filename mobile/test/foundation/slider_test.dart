import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:wust_wiki/foundation/slider.dart';
import 'package:wust_wiki/foundation/transport.dart';

void main() {
  test('归一化匹配保留暗化区域的正确位移和轨迹', () async {
    const width = 280, height = 160, pieceWidth = 56, offset = 110;
    final random = Random(91);
    final background = Uint8List(width * height * 4);
    for (var i = 0; i < width * height; i++) {
      final value = 30 + random.nextInt(200);
      background[i * 4] = value;
      background[i * 4 + 1] = value;
      background[i * 4 + 2] = value;
      background[i * 4 + 3] = 255;
    }
    final piece = Uint8List(pieceWidth * height * 4);
    for (var y = 48; y < 104; y++) {
      for (var x = 4; x < pieceWidth - 4; x++) {
        final source = (y * width + offset + x) * 4,
            target = (y * pieceWidth + x) * 4;
        for (var c = 0; c < 3; c++) {
          piece[target + c] = background[source + c];
          background[source + c] = (background[source + c] * .55).round();
        }
        piece[target + 3] = 255;
      }
    }
    final solution = await solveSliderAsync(
      SliderRaster(width, height, background),
      SliderRaster(pieceWidth, height, piece),
      pieceWidth,
      48,
    );
    expect(solution.pixelOffset, offset);
    expect(solution.confidence, greaterThan(.99));
    expect(solution.moveLength, 110);
    final payload = solution.payload();
    expect((payload['tracks'] as List).last['a'], 110);
    expect(
      (payload['tracks'] as List).fold<int>(
        0,
        (sum, p) => sum + (p['c'] as int),
      ),
      greaterThan(300),
    );
  });
  test('透明或无纹理滑块不能返回伪造匹配', () {
    expect(
      () => solveSlider(
        SliderRaster(280, 160, Uint8List(280 * 160 * 4)),
        SliderRaster(56, 160, Uint8List(56 * 160 * 4)),
        56,
        0,
      ),
      throwsA(isA<FoundationException>()),
    );
  });
}
