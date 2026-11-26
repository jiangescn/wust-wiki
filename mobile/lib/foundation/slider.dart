import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:isolate';
import 'transport.dart';

class SliderRaster {
  SliderRaster(this.width, this.height, this.pixels) {
    if (width < 8 ||
        width > 2048 ||
        height < 8 ||
        height > 2048 ||
        pixels.length != width * height * 4) {
      throw const FoundationException('invalid_slider_image', '滑块图片无效。');
    }
  }
  final int width, height;
  final Uint8List pixels;
  int alpha(int x, int y) => pixels[(y * width + x) * 4 + 3];
  double gray(int x, int y) {
    final i = (y * width + x) * 4;
    return .299 * pixels[i] + .587 * pixels[i + 1] + .114 * pixels[i + 2];
  }
}

class SliderSolution {
  const SliderSolution(
    this.pixelOffset,
    this.confidence,
    this.canvasLength,
    this.moveLength,
  );
  final int pixelOffset, canvasLength;
  final double confidence, moveLength;
  Map<String, dynamic> payload({math.Random? random}) {
    final rng = random ?? math.Random.secure();
    final steps = (moveLength / 4).ceil().clamp(18, 48);
    final speedBias = .85 + rng.nextDouble() * .3;
    final points = <Map<String, dynamic>>[
      {'a': 0, 'b': 0, 'c': 0},
    ];
    var previousX = 0.0, previousY = 0.0, driftY = 0.0;
    var interval = 120 + rng.nextInt(161);
    for (var step = 1; step <= steps; step++) {
      final progress = step / steps;
      final t = math.pow(progress, speedBias).toDouble();
      final eased = t * t * (3 - 2 * t);
      final noise = (rng.nextDouble() - .5) * .7 * math.sin(progress * math.pi);
      // The final sample must use the submitted displacement itself. A multiply
      // followed by division can differ by one ULP from that value.
      final x = step == steps
          ? moveLength
          : ((moveLength * eased + noise) * 1000).roundToDouble() / 1000;
      final boundedX = x.clamp(0.0, moveLength).toDouble();
      driftY = (driftY + (rng.nextDouble() - .5) * .85).clamp(-3.0, 3.0);
      final y = (driftY * 100).roundToDouble() / 100;
      interval += 24 + rng.nextInt(28);
      if (step > steps ~/ 3 && step < steps * 2 ~/ 3 && rng.nextInt(12) == 0) {
        interval += 25 + rng.nextInt(36);
      }
      final dx = boundedX - previousX, dy = y - previousY;
      // Match the official component's movement sampling: >=20 ms and >=2 px,
      // with the release sample always retained.
      if (step != steps && dx * dx + dy * dy < 4) continue;
      points.add({'a': boundedX, 'b': y, 'c': interval});
      previousX = boundedX;
      previousY = y;
      interval = 0;
    }
    // Short distances previously produced a sub-second gesture. Live checks
    // rejected these submissions even when the very same ciphertext was
    // accepted later. Retain a natural time budget independent of distance.
    final minimumDuration = 1800 + rng.nextInt(501);
    final planned = points.fold<int>(0, (sum, p) => sum + (p['c'] as int));
    if (planned < minimumDuration) {
      var elapsed = 0, previous = 0;
      for (final point in points.skip(1)) {
        elapsed += point['c'] as int;
        final scheduled = (elapsed / planned * minimumDuration).round();
        point['c'] = scheduled - previous;
        previous = scheduled;
      }
    }
    return {
      'canvasLength': canvasLength,
      'moveLength': moveLength,
      'tracks': points,
    };
  }
}

Future<SliderSolution> solveSliderAsync(
  SliderRaster background,
  SliderRaster piece,
  int tagWidth,
  int yHeight,
) => Isolate.run(() => solveSlider(background, piece, tagWidth, yHeight));

SliderSolution solveSlider(
  SliderRaster background,
  SliderRaster piece,
  int tagWidth,
  int yHeight, {
  int canvasLength = 280,
}) {
  if (canvasLength < 100 ||
      canvasLength > 2048 ||
      tagWidth <= 0 ||
      tagWidth != piece.width ||
      piece.width >= background.width ||
      yHeight < 0)
    throw const FoundationException('invalid_slider_geometry', '滑块图片尺寸无效。');
  final fullHeight = (piece.height - background.height).abs() <= 2;
  final originY = fullHeight ? 0 : yHeight;
  if (originY + piece.height > background.height)
    throw const FoundationException('invalid_slider_geometry', '滑块位置无效。');
  final samples = <(int, int, double)>[];
  for (var y = 2; y < piece.height - 2; y += 2) {
    for (var x = 2; x < piece.width - 2; x += 2) {
      if ([
        (x, y),
        (x - 2, y),
        (x + 2, y),
        (x, y - 2),
        (x, y + 2),
      ].every((p) => piece.alpha(p.$1, p.$2) >= 250)) {
        samples.add((x, y + originY, piece.gray(x, y)));
      }
    }
  }
  if (samples.length < 32)
    throw const FoundationException('invalid_slider_image', '有效滑块像素不足。');
  final count = samples.length.toDouble();
  final mean = samples.fold<double>(0, (sum, p) => sum + p.$3) / count;
  final values = samples.map((p) => p.$3 - mean).toList();
  final variance = values.fold<double>(0, (sum, v) => sum + v * v);
  if (variance <= count)
    throw const FoundationException('slider_no_match', '未找到可靠的滑块位置。');
  final scores = <(int, double)>[];
  for (var offset = 0; offset <= background.width - piece.width; offset++) {
    double sum = 0, squares = 0, covariance = 0;
    for (var i = 0; i < samples.length; i++) {
      final sample = samples[i];
      final value = background.gray(offset + sample.$1, sample.$2);
      sum += value;
      squares += value * value;
      covariance += values[i] * value;
    }
    final targetVariance = squares - sum * sum / count;
    scores.add((
      offset,
      targetVariance > count
          ? covariance / math.sqrt(variance * targetVariance)
          : -1,
    ));
  }
  final best = scores.reduce((a, b) => a.$2 > b.$2 ? a : b);
  final alternatives = scores
      .where((p) => (p.$1 - best.$1).abs() > math.max(8, piece.width ~/ 4))
      .map((p) => p.$2);
  final alternative = alternatives.isEmpty ? -1 : alternatives.reduce(math.max);
  if (!best.$2.isFinite || best.$2 < .65 || best.$2 - alternative < .03) {
    throw const FoundationException('slider_no_match', '未找到可靠的滑块位置。');
  }
  final move = best.$1 * canvasLength / background.width;
  if (move <= 0 || move + 40 > canvasLength)
    throw const FoundationException('invalid_slider_geometry', '滑块位移无效。');
  return SliderSolution(best.$1, best.$2, canvasLength, move);
}
