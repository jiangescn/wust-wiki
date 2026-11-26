import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:wust_wiki/foundation/client.dart';

void main() {
  test('全部分发资源均有总索引和分册合同', () {
    final index = File('migration/api.md').readAsStringSync();
    final academic = File('migration/academic-port.md').readAsStringSync();
    final campus = File('migration/campus-port.md').readAsStringSync();
    for (final resource in DartFoundationClient.academicResources) {
      expect(index, contains('`$resource`'));
      expect(academic, contains('### $resource'));
    }
    for (final resource in DartFoundationClient.campusResources) {
      expect(index, contains('`$resource`'));
      expect(campus, contains('`$resource`'));
    }
  });
}
