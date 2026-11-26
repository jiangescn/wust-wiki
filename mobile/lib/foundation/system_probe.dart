// Synthetic system-capability fixtures. Only reachable from the debug entry.
import 'dart:convert';
import 'package:flutter/material.dart';
import '../academic.dart';
import '../foundation_service_page.dart';
import 'flutter_platform.dart';

List<int> _pdf() {
  final text = 'BT /F1 18 Tf 40 100 Td (Synthetic PDF acceptance) Tj ET';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 200] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Length ${text.length} >>\nstream\n$text\nendstream',
  ];
  var data = '%PDF-1.4\n';
  final offsets = <int>[0];
  for (final (index, object) in objects.indexed) {
    offsets.add(data.length);
    data += '${index + 1} 0 obj\n$object\nendobj\n';
  }
  final xref = data.length;
  data += 'xref\n0 ${offsets.length}\n0000000000 65535 f \n';
  for (final offset in offsets.skip(1)) {
    data += '${offset.toString().padLeft(10, '0')} 00000 n \n';
  }
  data +=
      'trailer\n<< /Size ${offsets.length} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n';
  return ascii.encode(data);
}

class _SystemStore extends AcademicStore {
  @override
  Future<Json> queryService(String resource, {Json options = const {}}) async {
    const platform = AndroidFoundationPlatform();
    final digest = await platform.invoke('digest', {
      'algorithm': 'MD5',
      'data': base64Encode(ascii.encode('abc')),
    });
    final decoded = await platform.invoke('decodeText', {
      'charset': 'GB18030',
      'data': '1tDOxA==',
    });
    if (base64Encode([
              0x90,
              0x01,
              0x50,
              0x98,
              0x3c,
              0xd2,
              0x4f,
              0xb0,
              0xd6,
              0x96,
              0x3f,
              0x7d,
              0x28,
              0xe1,
              0x7f,
              0x72,
            ]) !=
            digest['data'] ||
        decoded['text'] != '中文') {
      throw const FormatException('System capability mismatch');
    }
    return {
      'title': 'Synthetic system acceptance',
      'rows': [
        {'title': 'MD5 + GB18030 PASS', 'fields': <Json>[]},
      ],
      'files': [
        {
          'name': 'synthetic-acceptance.txt',
          'mime': 'text/plain; charset=utf-8',
          'base64': base64Encode(ascii.encode('Synthetic file acceptance\n')),
        },
        {
          'name': 'synthetic-acceptance.pdf',
          'mime': 'application/pdf',
          'base64': base64Encode(_pdf()),
        },
      ],
    };
  }
}

class FoundationSystemProbe extends StatelessWidget {
  FoundationSystemProbe({super.key});
  final AcademicStore store = _SystemStore();
  @override
  Widget build(BuildContext context) => MaterialApp(
    home: FoundationServicePage(
      store: store,
      resource: 'synthetic',
      title: 'Synthetic system acceptance',
    ),
  );
}
