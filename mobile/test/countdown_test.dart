import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wust_wiki/academic.dart';
import 'package:wust_wiki/countdown.dart';

void main() {
  testWidgets('无需登录即可添加倒计时，重新打开后可编辑和删除', (t) async {
    final messenger = t.binding.defaultBinaryMessenger;
    var storage = '[]';
    messenger.setMockMethodCallHandler(platform, (call) async {
      if (call.method == 'loadCountdowns') return storage;
      if (call.method == 'saveCountdowns') storage = call.arguments as String;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(platform, null));
    Future<void> mount() async {
      await t.pumpWidget(const MaterialApp(home: CountdownPage()));
      await t.pumpAndSettle();
    }

    Future<void> tap(String text) async {
      await t.tap(find.text(text).last);
      await t.pumpAndSettle();
    }

    await mount();
    await tap('添加倒计时');
    await t.enterText(find.byType(TextFormField).first, '物理');
    await tap('保存');
    expect(find.text('选择考试时间后再保存'), findsOneWidget);
    await tap('选择考试时间');
    await tap('OK');
    await tap('OK');
    await t.enterText(find.byType(TextFormField).last, '教学楼 201');
    await tap('保存');
    expect(find.text('1 门待考'), findsOneWidget);
    expect((jsonDecode(storage) as List).single['name'], '物理');

    await t.pumpWidget(const SizedBox());
    await mount();
    expect(find.text('物理'), findsOneWidget);
    expect(find.text('教学楼 201'), findsOneWidget);
    await tap('物理');
    await t.enterText(find.byType(TextFormField).first, '大学物理');
    await tap('保存');
    expect(find.text('大学物理'), findsOneWidget);
    await t.tap(find.byTooltip('倒计时选项'));
    await t.pumpAndSettle();
    await tap('删除');
    await tap('删除');
    expect(find.text('0 门待考'), findsOneWidget);
    expect(storage, '[]');
    await t.pumpWidget(const SizedBox());
  });
}
