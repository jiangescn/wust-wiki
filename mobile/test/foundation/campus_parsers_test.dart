import 'package:flutter_test/flutter_test.dart';

import 'campus_parsers_probe.dart';

void main() {
  test('校园服务合成解析回归', () {
    expect(runCampusParserChecks(), greaterThan(60));
  });
}
