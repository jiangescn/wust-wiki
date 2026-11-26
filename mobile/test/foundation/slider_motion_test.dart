import 'package:flutter_test/flutter_test.dart';
import 'slider_motion_checks.dart' as checks;

void main() {
  test(
    'Slider movement preserves exact endpoints and varies bounded motion',
    checks.main,
  );
}
