import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wust_wiki/grade_results.dart';
import 'package:wust_wiki/main.dart';

void main() {
  testWidgets('窄屏深色下可读成绩、按学期筛选并搜索展开课程', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: const WikiApp().theme(Brightness.dark),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: const Scaffold(
            body: GradeResults([
              {
                'term': '2025-2026-2',
                'name': '数据结构与算法实验',
                'code': 'CS01',
                'score': '良好',
                'credit': '2.0',
                'point': '3.5',
                'nature': '必修',
              },
              {
                'term': '2026-2027-1',
                'name': '线性代数',
                'code': 'MA03',
                'score': '92',
              },
            ]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 门课程'), findsOneWidget);
    expect(find.text('良好'), findsOneWidget);
    await tester.tap(find.text('数据结构与算法实验'));
    await tester.pumpAndSettle();
    expect(find.text('CS01 · 必修'), findsOneWidget);

    await tester.tap(find.text('全部学期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026-2027-1').last);
    await tester.pumpAndSettle();
    expect(find.text('数据结构与算法实验'), findsNothing);
    await tester.enterText(find.byType(TextField), 'ma03');
    await tester.pumpAndSettle();
    expect(find.text('线性代数'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'cs01');
    await tester.pumpAndSettle();
    expect(find.text('没有符合条件的成绩'), findsOneWidget);
    await tester.tap(find.byTooltip('清空搜索'));
    await tester.pumpAndSettle();
    expect(find.text('92'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
