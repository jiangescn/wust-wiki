import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wust_wiki/academic.dart';
import 'package:wust_wiki/dorm.dart';
import 'package:wust_wiki/native_pages.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await nativeData);

  testWidgets('删除第一门课时保留剩余课程输入和加权结果', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: NativePage(
          AcademicStore(),
          '/tools/gpa',
          '绩点计算',
          selectTab: (_) {},
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('添加课程'));
    await t.pumpAndSettle();
    final fields = find.byType(TextFormField);
    for (final entry in ['2', '1', '3', '4'].indexed) {
      await t.enterText(fields.at(entry.$1), entry.$2);
    }
    await t.tap(find.byTooltip('移除课程').first);
    await t.pumpAndSettle();
    expect(fields, findsNWidgets(2));
    expect(
      t.widget<EditableText>(find.byType(EditableText).first).controller.text,
      '3',
    );
    expect(find.textContaining('4.00'), findsOneWidget);
  });

  testWidgets('培养方案可在展开中折返，减少动态效果时首帧到位', (t) async {
    final store = AcademicStore();
    Future<void> show(bool reduced) async {
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: NativePage(
              store,
              '/study/status',
              '培养方案',
              selectTab: (_) {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    await show(false);
    final header = find.byType(ExpansionTile).first;
    double height() => t.getSize(header).height;
    final initial = height();
    await t.tap(header);
    await t.pump();
    await t.pump(const Duration(milliseconds: 120));
    expect(height(), greaterThan(initial));
    await t.tap(find.byType(ListTile).first);
    await t.pumpAndSettle();
    expect(height(), initial);
    await show(true);
    await t.tap(header);
    await t.pump();
    final after = height();
    expect(after, greaterThan(initial));
    await t.pump(const Duration(milliseconds: 420));
    expect(height(), after);
  });
  testWidgets('宿舍输入错误显示在字段旁，修改后解除', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: DormPage())));
    await t.tap(find.text('查询寝室'));
    await t.pumpAndSettle();
    expect(find.text('请输入 3 至 16 位数字寝室号。'), findsOneWidget);
    await t.enterText(find.byType(EditableText).last, '301');
    await t.pumpAndSettle();
    expect(find.text('请输入 3 至 16 位数字寝室号。'), findsNothing);
  });
}
