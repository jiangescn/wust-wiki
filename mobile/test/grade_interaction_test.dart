import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wust_wiki/academic.dart';
import 'package:wust_wiki/grade_selection.dart';
import 'package:wust_wiki/native_pages.dart';

const records = <Json>[
  {
    'name': '大学英语',
    'code': 'E1',
    'credit': '2',
    'point': '2',
    'score': '70',
    'term': '2025-2026-1',
    'attempt': '初修',
    'nature': '必修',
  },
  {
    'name': '大学英语',
    'code': 'E1',
    'credit': '2',
    'point': '4',
    'score': '90',
    'term': '2025-2026-2',
    'attempt': '重修',
    'nature': '必修',
  },
];

class Fixture extends AcademicStore {
  @override
  bool get loggedIn => true;
  @override
  Future<void> init() async {}
  @override
  Future<Json> api(String action, String bearer, {String? resource}) async => {
    'state': 'complete',
    'result': {'courses': records},
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await nativeData);

  testWidgets('打开绩点计算立即使用教务成绩，底部可从零开始', (t) async {
    final store = Fixture();
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openNative(
                context,
                store,
                '/tools/gpa',
                '绩点计算',
                selectTab: (_) {},
              ),
              child: const Text('打开绩点'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('打开绩点'));
    await t.pumpAndSettle();
    expect(find.textContaining('4.00'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    await t.tap(find.text('从零开始计算'));
    await t.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.textContaining('4.00'), findsNothing);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.textContaining('4.00'), findsOneWidget);
  });

  testWidgets('点重修记录切换整行选中状态，绩点随之更新', (t) async {
    await t.pumpWidget(MaterialApp(home: GradeSelection(records)));
    await t.pumpAndSettle();
    expect(find.textContaining('4.00'), findsOneWidget);
    await t.tap(find.byType(CheckboxListTile).first);
    await t.pumpAndSettle();
    final rows = t
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    expect(rows.map((r) => r.selected), [true, false]);
    expect(rows.map((r) => r.value), [true, false]);
    expect(find.textContaining('2.00'), findsOneWidget);
  });
  testWidgets('深色减少动效下分数和详情可展开、收起', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        builder: (_, child) => MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: child!,
        ),
        home: AcademicQuery(Fixture(), 'grades'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('70'), findsOneWidget);
    await t.tap(find.text('70'));
    await t.pumpAndSettle();
    expect(find.text('E1 · 必修 · 初修'), findsOneWidget);
    await t.tap(find.text('70'));
    await t.pumpAndSettle();
    expect(find.text('E1 · 必修 · 初修'), findsNothing);
  });
}
