import 'dart:convert';
import '../../lib/foundation/slider.dart';

void _require(bool value, String message) {
  if (!value) throw StateError(message);
}

void main() {
  for (var offset = 1; offset <= 350; offset++) {
    final move = offset * 280 / 420;
    final body = SliderSolution(offset, .9, 280, move).payload();
    final points = body['tracks'] as List;
    _require(
      points.last['a'] == body['moveLength'],
      'The final coordinate must equal the submitted displacement exactly',
    );
    _require(points.first['a'] == 0 && points.first['c'] == 0, 'Origin');
    _require(
      points.every((p) => (p['a'] as num) >= 0 && (p['a'] as num) + 40 <= 280),
      'Widget bounds',
    );
    _require(
      points.skip(1).every((p) => p['c'] is int && p['c'] > 0),
      'Elapsed intervals',
    );
    _require(
      points.fold<int>(0, (sum, p) => sum + (p['c'] as int)) >= 1800,
      'Short-distance drags must retain the measured minimum movement budget',
    );
  }
  const solution = SliderSolution(210, .9, 280, 140);
  final variants = List.generate(6, (_) => solution.payload());
  _require(
    variants.map(jsonEncode).toSet().length == variants.length,
    'Fresh movements must vary instead of replaying one fixed trajectory',
  );
  final points = variants.first['tracks'] as List;
  final velocities = <double>[
    for (var i = 1; i < points.length; i++)
      ((points[i]['a'] as num) - (points[i - 1]['a'] as num)) /
          (points[i]['c'] as num),
  ];
  final distinct = velocities.map((v) => v.toStringAsFixed(3)).toSet();
  _require(distinct.length >= 5, 'Acceleration and small motion variation');
  _require(
    points.every((p) => (p['b'] as num).abs() <= 5),
    'Small bounded vertical variation',
  );
  print(
    'Motion invariants passed: exact endpoint, fresh variation, speed variation, bounds',
  );
}
