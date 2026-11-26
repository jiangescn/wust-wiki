import 'package:flutter_test/flutter_test.dart';

import 'campus_services_probe.dart';

void main() {
  test('校园服务请求与结果合同合成回归', () async {
    expect(await runCampusServiceChecks(), greaterThan(65));
  });
}
