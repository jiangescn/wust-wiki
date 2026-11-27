import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/academic.dart';
import '../lib/foundation/academic_parsers.dart';
import '../lib/foundation_service_page.dart';
import 'foundation/academic_fixtures.dart';

class _Store extends AcademicStore {
  final calls = <(String, Json)>[];
  int cancellations = 0;
  Future<Json> Function(String, Json)? respond;

  @override
  Future<Json> queryService(String resource, {Json options = const {}}) async {
    calls.add((resource, Map.of(options)));
    return await respond?.call(resource, options) ?? {'rows': <Json>[]};
  }

  @override
  void cancelLocal() => cancellations++;
}

Json _row(String title, String value, {Json? action}) => {
  'title': title,
  'fields': [
    {'name': '字段', 'value': value},
  ],
  if (action != null) 'action': action,
};
Json _text(String key, String value, {String type = 'text'}) => {
  'key': key,
  'label': key,
  'type': type,
  'value': value,
};
Json _action(String label, String resource, [Json options = const {}]) => {
  'label': label,
  'resource': resource,
  'options': options,
};

Future<void> _mount(
  WidgetTester tester,
  _Store store, {
  String resource = 'training-plan',
  Json options = const {},
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FoundationServicePage(
        store: store,
        resource: resource,
        title: '服务',
        options: options,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('记住洗衣点后也能打开我的订单，订单页只展示可读信息', (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(platform, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(platform, null));
    final store = _Store()
      ..initialized = true
      ..laundryShop = (id: 'shop-fixture', name: '南楼洗衣点', filter: '')
      ..respond = (resource, _) async {
        if (resource == 'laundry-devices') {
          return {
            'rows': <Json>[],
            'title': '南楼洗衣点',
            'availableDevices': <Json>[],
          };
        }
        return {
          'title': '我的洗衣',
          'rows': [
            {
              'title': '南楼 2-1',
              'fields': [
                {'name': '门店', 'value': '南楼洗衣点'},
                {'name': '程序', 'value': '标准洗'},
                {'name': '状态', 'value': '进行中'},
                {'name': 'observedAt', 'value': 'internal-fixture-value'},
              ],
              'action': _action('查看订单', 'laundry-order', {
                'orderId': 'order-fixture',
              }),
            },
          ],
        };
      };
    await _mount(tester, store, resource: 'laundry-shops');
    expect(store.calls.single.$1, 'laundry-devices');
    expect(find.text('我的洗衣'), findsOneWidget);
    await _tap(tester, '我的洗衣');
    expect(store.calls.last.$1, 'laundry-orders');
    expect(find.text('南楼 2-1'), findsOneWidget);
    expect(find.text('进行中'), findsWidgets);
    expect(find.textContaining('internal-fixture-value'), findsNothing);
    await _tap(tester, '南楼 2-1');
    expect(store.calls.last.$1, 'laundry-order');
    expect(store.calls.last.$2, {'orderId': 'order-fixture'});
    expect(find.text('洗衣订单详情'), findsOneWidget);
    expect(find.textContaining('internal-fixture-value'), findsNothing);
  });

  testWidgets('订单详情只显示订单信息，不显示内部字段', (tester) async {
    final store = _Store()
      ..respond = (_, _) async => {
        'title': '洗衣订单详情',
        'rows': [
          {
            'title': '合成设备',
            'fields': [
              {'name': '门店', 'value': '南楼洗衣点'},
              {'name': 'observedAt', 'value': 'internal-fixture-value'},
            ],
          },
        ],
      };
    await _mount(
      tester,
      store,
      resource: 'laundry-order',
      options: {'orderId': 'order-fixture'},
    );
    expect(find.textContaining('合成设备'), findsOneWidget);
    expect(find.textContaining('internal-fixture-value'), findsNothing);
    await tester.tap(find.byTooltip('刷新'));
    await tester.pumpAndSettle();
    expect(store.calls.last.$1, 'laundry-order');
    expect(store.calls.last.$2, {'orderId': 'order-fixture', 'refresh': true});
  });

  testWidgets('胖乖登录失效时展示登录表单，登完直接查询洗衣订单', (tester) async {
    var signedIn = false;
    final store = _Store()
      ..respond = (resource, options) async {
        if (resource == 'laundry') {
          return {
            'controls': [_text('phone', ''), _text('smsCode', '')],
          };
        }
        if (resource == 'laundry-login') {
          expect(options, {
            'action': 'login',
            'phone': '10000000000',
            'smsCode': '123456',
          });
          signedIn = true;
          return {'rows': <Json>[]};
        }
        if (!signedIn) {
          throw const AcademicApiException(
            'internal fixture error',
            401,
            code: 'laundry_login_required',
          );
        }
        return {'rows': <Json>[]};
      };
    await _mount(tester, store, resource: 'laundry-orders');
    expect(find.text('胖乖登录'), findsOneWidget);
    expect(find.textContaining('internal fixture error'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('foundation-input-phone')),
      '10000000000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('foundation-input-smsCode')),
      '123456',
    );
    await _tap(tester, '登录');
    expect(store.calls.map((call) => call.$1), [
      'laundry-orders',
      'laundry',
      'laundry-login',
      'laundry-orders',
    ]);
    expect(store.calls.last.$2, isEmpty);
    expect(find.text('我的洗衣'), findsOneWidget);
    expect(find.text('暂无洗衣订单'), findsOneWidget);
  });

  testWidgets('受限通知使用原文登录，公共列表不要求教务账号', (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async => call.method == 'create' ? 0 : null,
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        null,
      ),
    );
    final store = _Store()
      ..respond = (resource, _) async {
        if (resource == 'notice-detail') {
          throw const AcademicApiException(
            '学校服务会话失效',
            502,
            code: 'authentication_required',
          );
        }
        return {
          'rows': [
            _row(
              '受限通知',
              '2026-11-19',
              action: _action('查看通知', 'notice-detail', {
                'url': 'https://www.wust.edu.cn/info/1122/12345.htm',
              }),
            ),
          ],
        };
      };
    await _mount(tester, store, resource: 'notices');
    expect(store.loggedIn, isFalse);
    await _tap(tester, '受限通知');
    expect(find.text('登录查看原文'), findsOneWidget);
    expect(find.text('学校统一认证'), findsNothing);
    await _tap(tester, '登录查看原文');
    final portal = tester.widget<AndroidView>(find.byType(AndroidView));
    expect(portal.viewType, 'wiki/school-service');
    expect(portal.creationParams, {
      'notice': 'https://www.wust.edu.cn/info/1122/12345.htm',
    });
  });

  testWidgets('图书馆首屏展示借阅和应还日期，切换到期列表无需再查询', (tester) async {
    final store = _Store()
      ..respond = (_, _) async => {
        'rows': [_row('账户统计', 'deptRange'), _row('当前借阅', '页码')],
        'actions': [
          _action('账户资料', 'library-profile'),
          _action('即将到期', 'library-loans'),
        ],
        'circulation': {
          'current': {
            'total': 1,
            'items': [
              {
                'title': '合成图书',
                'dueDate': '2026-12-03',
                'barCode': 'hidden-barcode',
              },
            ],
          },
          'dueSoon': {'total': 0, 'items': <Json>[]},
        },
      };
    await _mount(tester, store, resource: 'library');
    expect(find.text('合成图书'), findsOneWidget);
    expect(find.text('应还 2026-12-03'), findsOneWidget);
    expect(find.textContaining('deptRange'), findsNothing);
    expect(find.textContaining('hidden-barcode'), findsNothing);
    expect(find.textContaining('页码'), findsNothing);
    await _tap(tester, '即将到期 0');
    expect(find.text('暂无即将到期的图书'), findsOneWidget);
    expect(store.calls.length, 1);
  });

  testWidgets('点洗衣点整行进入设备页，短标题下显示完整门店和空闲机号', (tester) async {
    const shop = '武汉科技大学黄家湖校区南楼测试洗衣点';
    final preferences = <String, dynamic>{};
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(platform, (call) async {
      if (call.method == 'restore') return preferences;
      if (call.method == 'save') preferences.addAll(Map.from(call.arguments));
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(platform, null));
    final store = _Store()
      ..respond = (resource, options) async => resource == 'laundry-shops'
          ? {
              'rows': [
                _row(
                  shop,
                  'internal-shop-id',
                  action: _action('详情', 'laundry-devices', {
                    'shopId': 'internal-shop-id',
                    'shopName': shop,
                  }),
                ),
              ],
              'shops': [
                {'name': shop, 'freeMachine': 3},
              ],
              'shopQueryArea': '黄家湖校区附近',
              'controls': [
                {
                  'key': 'latitude',
                  'label': '纬度',
                  'type': 'text',
                  'value': '30',
                },
              ],
            }
          : {
              'title': options['shopName'],
              'rows': [_row('南楼1-2', 'internal-device-id')],
              'availableDevices': [
                {'name': '南楼1-2', 'id': 'internal-device-id'},
                {'name': '南楼1-3'},
                {'name': '北楼1-1'},
              ],
              'actions': [_action('刷新设备', 'laundry-devices')],
              'message': '本次仅返回空闲设备明细，不能据此认定全部设备名单。',
            };
    await _mount(tester, store, resource: 'laundry-shops');
    expect(find.text('空闲 3 台'), findsOneWidget);
    expect(find.text('纬度'), findsNothing);
    await _tap(tester, shop);
    expect(find.text('空闲洗衣机'), findsOneWidget);
    expect(find.text(shop), findsOneWidget);
    expect(find.text('3 台空闲'), findsOneWidget);
    expect(find.text('南楼1-2'), findsOneWidget);
    expect(find.textContaining('internal-device-id'), findsNothing);
    expect(find.text('刷新设备'), findsNothing);
    expect(find.textContaining('不能据此'), findsNothing);
    expect(store.calls.last.$2['shopId'], 'internal-shop-id');
    expect(preferences['laundryShopId'], 'internal-shop-id');
    await _tap(tester, '南楼');
    expect(find.text('2 台空闲'), findsOneWidget);
    expect(find.text('北楼1-1'), findsNothing);
    await tester.enterText(find.byType(TextField), '南楼1-2');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('1 台空闲'), findsOneWidget);
    expect(find.text('南楼1-3'), findsNothing);
    expect(preferences['laundryShopFilter'], '南楼1-2');

    await tester.pumpWidget(const SizedBox());
    final restarted = _Store()..respond = store.respond;
    await _mount(tester, restarted, resource: 'laundry-shops');
    expect(restarted.calls.single.$1, 'laundry-devices');
    expect(find.text(shop), findsOneWidget);
    expect(find.text('1 台空闲'), findsOneWidget);
    expect(find.text('南楼1-3'), findsNothing);

    await _tap(tester, '更换地点');
    expect(restarted.calls.last.$1, 'laundry-shops');
    expect(find.text('空闲 3 台'), findsOneWidget);
  });

  testWidgets('主修进度从完成概览打开分类明细，并复用同一次教务查询', (tester) async {
    final store = _Store()
      ..respond = (_, _) async =>
          parseAcademicCredits(academicCreditsFixture());
    await _mount(tester, store, resource: 'credits');
    expect(find.text('0.3 分'), findsOneWidget);
    expect(find.text('完成概览'), findsOneWidget);
    expect(find.text('合成必修'), findsNothing);

    await _tap(tester, '毕业学分完成情况');
    expect(find.text('合成必修'), findsOneWidget);
    expect(find.text('还需 2.2 学分'), findsOneWidget);
    expect(find.text('合成通选'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await _tap(tester, '通识选修类别');
    expect(find.text('合成通选'), findsOneWidget);
    expect(find.text('合成必修'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await _tap(tester, '培养方案课程明细');
    expect(find.text(academicTerm), findsOneWidget);
    expect(find.text('合成课程'), findsOneWidget);
    expect(find.text('必修 · 已修'), findsOneWidget);
    expect(store.calls.single.$1, 'credits');
  });

  testWidgets('第二课堂展示学分进度和剩余要求，隐藏类别编号', (tester) async {
    final store = _Store()
      ..respond = (_, _) async => {
        'rows': [_row('实践活动', 'internal-category-code')],
        'transcript': {
          'earnedCredits': 5,
          'evaluation': '良好',
          'categories': [
            {
              'id': 'internal-category-code',
              'name': '实践活动',
              'requiredCredits': 7,
              'earnedCredits': 5,
              'requirements': [
                {'kind': 'required', 'remainingCredits': 2},
              ],
            },
          ],
        },
      };
    await _mount(tester, store, resource: 'second-class');
    expect(find.text('5 / 7 学分'), findsOneWidget);
    expect(find.text('必修还差 2 学分'), findsOneWidget);
    expect(find.textContaining('internal-category-code'), findsNothing);
  });

  testWidgets(
    'select defaults and changed source clear old notice paging URL',
    (tester) async {
      final store = _Store()
        ..respond = (_, _) async => {
          'rows': <Json>[],
          'controls': [
            {
              'key': 'source',
              'label': '来源',
              'type': 'select',
              'options': [
                {'value': 'campus', 'label': '校园'},
                {'value': 'academicAffairs', 'label': '教务'},
              ],
            },
          ],
          'actions': [
            _action('查询来源首页', 'notices', {'url': ''}),
          ],
        };
      await _mount(
        tester,
        store,
        resource: 'notices',
        options: {
          'url': 'old-page',
          'excludedDates': ['1980-01-01'],
        },
      );
      expect(find.text('校园'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('教务').last);
      await tester.pumpAndSettle();
      expect(find.text('查询来源首页'), findsNothing);
      expect(store.calls.last.$2, {
        'url': '',
        'excludedDates': ['1980-01-01'],
        'source': 'academicAffairs',
      });
    },
  );

  testWidgets(
    'popping an active child cancels its query and keeps parent usable',
    (tester) async {
      final pending = Completer<Json>();
      final store = _Store()
        ..respond = (resource, _) async {
          if (resource == 'notice-detail') return pending.future;
          return {
            'rows': [
              _row(
                '父页通知',
                '保留',
                action: {
                  'resource': 'notice-detail',
                  'options': {'url': 'fixture'},
                },
              ),
            ],
          };
        };
      await _mount(tester, store, resource: 'notices');
      await tester.tap(find.text('父页通知'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(store.cancellations, 0);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(store.cancellations, 1);
      expect(find.text('父页通知'), findsOneWidget);
      pending.complete({
        'rows': [_row('迟到子页', '忽略')],
      });
      await tester.pumpAndSettle();
      expect(find.text('迟到子页'), findsNothing);
      await tester.tap(find.byTooltip('刷新'));
      await tester.pumpAndSettle();
      expect(store.calls.last.$1, 'notices');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('通知翻页后从新一页的首条开始阅读', (tester) async {
    final store = _Store()
      ..respond = (_, options) async {
        final page = options['url'] == 'page-two' ? 2 : 1;
        return {
          'page': {'currentPage': page, 'totalPages': 2},
          'rows': [
            for (var i = 0; i < 20; i++)
              _row(
                '第 $page 页第 $i 条通知',
                '2026-11-25',
                action: _action('详情', 'notice-detail', {
                  'publishedDate': '2026-11-25',
                }),
              ),
          ],
          if (page == 1)
            'actions': [
              _action('下一页', 'notices', {'url': 'page-two'}),
            ],
        };
      };
    await _mount(tester, store, resource: 'notices');
    await tester.scrollUntilVisible(find.text('下一页'), 300);
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一页').hitTestable());
    await tester.pumpAndSettle();
    final first = find.text('第 2 页第 0 条通知');
    expect(first.hitTestable(), findsOneWidget);
  });

  testWidgets(
    'successful sensitive submission never survives into refresh options',
    (tester) async {
      final store = _Store()
        ..respond = (resource, _) async => resource == 'laundry'
            ? {
                'rows': <Json>[],
                'controls': [
                  _text('credential', 'default-secret', type: 'password'),
                ],
                'actions': [
                  _action('提交凭据', 'laundry-login', {'action': 'login'}),
                ],
              }
            : {
                'rows': [_row('查询成功', '已验证')],
              };
      await _mount(tester, store, resource: 'laundry');
      await tester.enterText(
        find.byKey(const ValueKey('foundation-input-credential')),
        'private-fixture',
      );
      await _tap(tester, '提交凭据');
      expect(store.calls.last.$2['credential'], 'private-fixture');
      expect(find.text('查询成功'), findsOneWidget);
      await tester.tap(find.byTooltip('刷新'));
      await tester.pumpAndSettle();
      expect(store.calls.last.$2.containsKey('credential'), isFalse);
      expect(store.calls.last.$2.containsKey('action'), isFalse);
    },
  );

  testWidgets(
    'invalid select defaults fail safely without dropdown assertions',
    (tester) async {
      final store = _Store()
        ..respond = (_, _) async => {
          'rows': <Json>[],
          'controls': [
            {
              'key': 'term',
              'type': 'select',
              'value': 'missing',
              'options': [
                {'value': 'a', 'label': '甲'},
              ],
            },
          ],
        };
      await _mount(tester, store);
      expect(find.text('服务返回的默认选项无效。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'renders fields, default selects, text filters and retained context',
    (tester) async {
      final store = _Store()
        ..respond = (_, options) async => {
          'rows': [_row('合成课程', '0.3')],
          'controls': [
            _text('courseName', '默认名称'),
            {
              'key': 'termID',
              'label': '学期',
              'type': 'select',
              'value': 'b',
              'options': [
                {'value': 'a', 'label': '学期甲'},
                {'value': 'b', 'label': '学期乙'},
              ],
            },
          ],
        };
      await _mount(
        tester,
        store,
        options: {
          'planHref': 'fixture-plan',
          'fields': {'courseName': 'old'},
          'unknown': 7,
        },
      );
      expect(find.text('合成课程'), findsOneWidget);
      expect(find.text('字段：0.3'), findsOneWidget);
      expect(find.text('学期乙'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('foundation-input-courseName')),
        '更新名称',
      );
      await _tap(tester, '查询');
      expect(store.calls.last.$2, containsPair('planHref', 'fixture-plan'));
      expect(store.calls.last.$2, containsPair('unknown', 7));
      expect(store.calls.last.$2['fields'], {'courseName': '更新名称'});
      expect(store.calls.last.$2['termID'], 'b');
    },
  );

  testWidgets('page actions override typed page and retain resource options', (
    tester,
  ) async {
    final store = _Store()
      ..respond = (_, options) async => {
        'rows': [_row('书目', '${options['page'] ?? 1}')],
        'controls': [
          _text('page', '${options['page'] ?? 1}'),
          _text('pageSize', '10'),
        ],
        'actions': [
          _action('下一页', 'library-booklist-books', {'page': 2}),
        ],
        'message': '第 1 / 2 页',
      };
    await _mount(
      tester,
      store,
      resource: 'library-booklist-books',
      options: {'id': 'fixture-booklist'},
    );
    await tester.enterText(
      find.byKey(const ValueKey('foundation-input-page')),
      '99',
    );
    await _tap(tester, '下一页');
    expect(store.calls.last.$1, 'library-booklist-books');
    expect(store.calls.last.$2, {
      'id': 'fixture-booklist',
      'page': 2,
      'pageSize': '10',
    });
    expect(store.cancellations, 0);
  });

  testWidgets(
    'row navigation uses only action options and parent stays intact',
    (tester) async {
      final store = _Store()
        ..respond = (resource, options) async => resource == 'notices'
            ? {
                'rows': [
                  _row(
                    '合成通知',
                    '2026-11-25',
                    action: {
                      'resource': 'notice-detail',
                      'options': {
                        'url': 'fixture-url',
                        'publishedDate': '2026-11-25',
                      },
                    },
                  ),
                ],
                'controls': [_text('source', 'campus')],
              }
            : {
                'title': '通知详情',
                'rows': [_row('正文', '完整正文')],
              };
      await _mount(
        tester,
        store,
        resource: 'notices',
        options: {'url': 'old-page', 'privateContext': 'old'},
      );
      expect(find.text('2026-11-25'), findsOneWidget);
      await _tap(tester, '合成通知');
      expect(store.calls.last.$1, 'notice-detail');
      expect(store.calls.last.$2, {
        'url': 'fixture-url',
        'publishedDate': '2026-11-25',
      });
      expect(find.text('字段：完整正文'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('合成通知'), findsOneWidget);
      expect(store.cancellations, 0);
    },
  );

  testWidgets('校车按真实方向归组并保留班次日期和线路', (tester) async {
    final store = _Store()
      ..respond = (_, _) async => {
        'rows': <Json>[],
        'schedule': {
          'departures': [
            {
              'origin': '青山校区',
              'destination': '黄家湖校区',
              'departureTime': '07:30',
              'operatingDays': '周一至周五',
              'route': '经中转站',
            },
            {
              'origin': '黄家湖校区',
              'destination': '青山校区',
              'departureTime': '08:40',
              'operatingDays': '周六',
            },
            {
              'origin': '青山校区',
              'destination': '黄家湖校区',
              'departureTime': '09:50',
              'operatingDays': '周日',
            },
          ],
        },
      };
    await _mount(tester, store, resource: 'shuttle');
    expect(find.text('青山校区 → 黄家湖校区'), findsOneWidget);
    expect(find.text('黄家湖校区 → 青山校区'), findsOneWidget);
    expect(find.text('07:30'), findsOneWidget);
    expect(find.text('09:50'), findsOneWidget);
    expect(find.text('周一至周五'), findsOneWidget);
    expect(find.text('经中转站'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('09:50')).dy,
      lessThan(tester.getTopLeft(find.text('08:40')).dy),
    );
  });

  testWidgets('缺少 TGT 时在 App 内打开学校图书馆，支持手动转浏览器', (tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    MethodCall? request;
    messenger.setMockMethodCallHandler(platform, (call) async {
      request = call;
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(platform, null));
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async => call.method == 'create' ? 0 : null,
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        null,
      ),
    );
    final store = _Store()
      ..respond = (_, _) async {
        throw const AcademicApiException('缺少 TGT', 502, code: 'tgt_required');
      };
    await _mount(tester, store, resource: 'library');
    expect(find.text('此服务需要学校授权'), findsOneWidget);
    expect(find.text('重试查询'), findsNothing);
    expect(request, isNull);
    await _tap(tester, '打开我的图书馆');
    final view = tester.widget<AndroidView>(find.byType(AndroidView));
    expect(view.viewType, 'wiki/school-service');
    expect(view.creationParams, 'library');
    expect(request, isNull);
    await tester.tap(find.byTooltip('用系统浏览器打开'));
    await tester.pumpAndSettle();
    expect(request?.method, 'external');
    expect(
      request?.arguments,
      'https://libsys.wust.edu.cn/space/reader/readerHome',
    );
  });

  testWidgets(
    'cross-resource top actions use inputs without leaking old context',
    (tester) async {
      final store = _Store()
        ..respond = (resource, _) async => resource == 'library-search'
            ? {
                'rows': <Json>[],
                'controls': [_text('keyword', '合成')],
                'actions': [
                  _action('借阅', 'library-loans', {'kind': 'current'}),
                ],
              }
            : {'rows': <Json>[]};
      await _mount(
        tester,
        store,
        resource: 'library-search',
        options: {'url': 'old', 'planHref': 'old'},
      );
      await _tap(tester, '借阅');
      expect(store.calls.last.$2, {'keyword': '合成', 'kind': 'current'});
    },
  );

  testWidgets('SMS requires explicit confirmation and refresh never resends', (
    tester,
  ) async {
    final store = _Store()
      ..respond = (resource, options) async => {
        'rows': <Json>[],
        'message': options['action'] == 'send' ? '短信请求已提交' : '请填写',
        'controls': [
          _text('phone', '10000000000'),
          _text('smsCode', 'must-not-echo'),
        ],
        'actions': [
          _action('发送登录短信', 'laundry-sms', {'action': 'send'}),
        ],
      };
    await _mount(tester, store, resource: 'laundry');
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('foundation-input-smsCode')),
          )
          .controller!
          .text,
      '',
    );
    await _tap(tester, '发送登录短信');
    expect(store.calls.length, 1);
    await _tap(tester, '取消');
    expect(store.calls.length, 1);
    await _tap(tester, '发送登录短信');
    await _tap(tester, '确认发送');
    expect(store.calls.length, 2);
    expect(store.calls.last.$1, 'laundry-sms');
    expect(store.calls.last.$2['action'], 'send');
    expect(find.text('短信请求已提交'), findsOneWidget);
    await tester.tap(find.byTooltip('刷新'));
    await tester.pumpAndSettle();
    expect(store.calls.length, 3);
    expect(store.calls.last.$2.containsKey('action'), isFalse);
    expect(find.text('发送登录短信？'), findsNothing);
  });

  testWidgets('initial SMS action also waits for confirmation', (tester) async {
    final store = _Store();
    await _mount(
      tester,
      store,
      resource: 'laundry-sms',
      options: {'action': 'send', 'phone': '10000000000'},
    );
    expect(store.calls, isEmpty);
    await _tap(tester, '取消');
    expect(store.calls, isEmpty);
    await tester.tap(find.byTooltip('刷新'));
    await tester.pumpAndSettle();
    expect(store.calls, isEmpty);
    await _tap(tester, '确认发送');
    expect(store.calls.length, 1);
  });

  testWidgets(
    'password and SMS inputs stay obscured, clear on submit, redact errors',
    (tester) async {
      final store = _Store()
        ..respond = (resource, options) async {
          if (resource == 'laundry-login')
            throw FormatException(
              '失败 ${options['smsCode']} ${options['credential']}',
            );
          return {
            'rows': <Json>[],
            'controls': [
              _text('phone', '10000000000'),
              _text('smsCode', 'do-not-echo'),
              _text('credential', 'do-not-echo', type: 'password'),
            ],
            'actions': [
              _action('验证码登录', 'laundry-login', {'action': 'login'}),
            ],
          };
        };
      await _mount(tester, store, resource: 'laundry');
      for (final key in ['smsCode', 'credential']) {
        final field = tester.widget<TextField>(
          find.byKey(ValueKey('foundation-input-$key')),
        );
        expect(field.obscureText, isTrue);
        expect(field.controller!.text, isEmpty);
      }
      await tester.enterText(
        find.byKey(const ValueKey('foundation-input-smsCode')),
        '654321',
      );
      await tester.enterText(
        find.byKey(const ValueKey('foundation-input-credential')),
        'secret-fixture',
      );
      await _tap(tester, '验证码登录');
      expect(store.calls.last.$2['smsCode'], '654321');
      expect(find.textContaining('secret-fixture'), findsNothing);
      expect(find.textContaining('654321'), findsNothing);
      expect(find.text('登录失败，请核对手机号和验证码'), findsOneWidget);
      for (final key in ['smsCode', 'credential']) {
        expect(
          tester
              .widget<TextField>(find.byKey(ValueKey('foundation-input-$key')))
              .controller!
              .text,
          isEmpty,
        );
      }
      await _tap(tester, '重试查询');
      expect(store.calls.last.$2.containsKey('smsCode'), isFalse);
      expect(store.calls.last.$2.containsKey('credential'), isFalse);
    },
  );

  testWidgets('cancellation ignores late results and retry gets new data', (
    tester,
  ) async {
    final pending = Completer<Json>();
    final store = _Store()..respond = (_, _) => pending.future;
    await tester.pumpWidget(
      MaterialApp(
        home: FoundationServicePage(
          store: store,
          resource: 'student',
          title: '学生',
        ),
      ),
    );
    await tester.pump();
    expect(find.text('取消查询'), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 220));
    await tester.tap(find.text('取消查询'));
    await tester.pumpAndSettle();
    expect(store.cancellations, 1);
    pending.complete({
      'rows': [_row('迟到数据', '不能出现')],
    });
    await tester.pumpAndSettle();
    expect(find.text('迟到数据'), findsNothing);
    expect(find.textContaining('已取消'), findsOneWidget);
    expect(find.text('当前没有相关记录。'), findsNothing);
    store.respond = (_, _) async => {
      'rows': [
        {
          'title': '新数据',
          'fields': [
            {'name': '姓名', 'value': '新数据'},
          ],
        },
      ],
    };
    await _tap(tester, '重试查询');
    expect(find.text('新数据'), findsOneWidget);
  });

  testWidgets('dispose cancels only the page-owned active query', (
    tester,
  ) async {
    final pending = Completer<Json>();
    final store = _Store()..respond = (_, _) => pending.future;
    await tester.pumpWidget(
      MaterialApp(
        home: FoundationServicePage(
          store: store,
          resource: 'student',
          title: '学生',
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(store.cancellations, 1);
    pending.complete({'rows': <Json>[]});
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'native file operations use flat params and require explicit success',
    (tester) async {
      final calls = <MethodCall>[];
      Json? reply = {'ok': false, 'cancelled': true};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform, (call) async {
            calls.add(call);
            return reply;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(platform, null),
      );
      final store = _Store()
        ..respond = (_, _) async => {
          'rows': <Json>[],
          'files': [
            {
              'name': 'fixture.pdf',
              'mime': 'application/pdf',
              'base64': 'JVBERi0=',
            },
          ],
        };
      await _mount(tester, store, resource: 'notice-file');
      expect(calls, isEmpty);
      await _tap(tester, '导出文件');
      expect(calls.last.method, 'foundationCapability');
      expect(calls.last.arguments, {
        'operation': 'exportFile',
        'name': 'fixture.pdf',
        'mime': 'application/pdf',
        'base64': 'JVBERi0=',
      });
      expect(find.textContaining('操作已取消'), findsOneWidget);
      expect(find.text('文件已导出。'), findsNothing);
      reply = null;
      await _tap(tester, '打开 PDF');
      expect(calls.last.arguments['operation'], 'openPdf');
      expect(find.text('未确认文件操作完成，请重试。'), findsOneWidget);
      reply = {'ok': true};
      await _tap(tester, '导出文件');
      expect(find.text('文件已导出。'), findsOneWidget);
    },
  );

  testWidgets(
    'body HTML and structured detail are readable without scripts or network',
    (tester) async {
      final store = _Store()
        ..respond = (_, _) async => {
          'rows': <Json>[],
          'body': {
            'html': '<p>通知第一段</p><p>第二段 &amp; 说明</p><script>danger()</script>',
          },
        };
      await _mount(tester, store, resource: 'notice-detail');
      expect(find.text('通知第一段\n\n第二段 & 说明'), findsOneWidget);
      expect(find.textContaining('danger()'), findsNothing);
      store.respond = (_, _) async => {
        'rows': <Json>[],
        'detail': {'text': '模块返回的实际正文'},
      };
      await tester.tap(find.byTooltip('刷新'));
      await tester.pumpAndSettle();
      expect(find.text('模块返回的实际正文'), findsOneWidget);
    },
  );

  testWidgets(
    'bad response is a retryable failure rather than a confirmed empty list',
    (tester) async {
      final store = _Store()..respond = (_, _) async => {'rows': 'bad'};
      await _mount(tester, store);
      expect(find.text('服务返回的数据结构无效。'), findsOneWidget);
      expect(find.text('当前没有相关记录。'), findsNothing);
      store.respond = (_, _) async => {'rows': <Json>[]};
      await _tap(tester, '重试查询');
      expect(find.text('当前没有相关记录。'), findsOneWidget);
    },
  );

  testWidgets('courses and lessons are rendered in a narrow dark viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _Store()
      ..respond = (_, _) async => {
        'courses': [
          {
            'name': '合成成绩',
            'fields': [
              {'name': '成绩', 'value': '85'},
            ],
          },
        ],
      };
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: FoundationServicePage(
          store: store,
          resource: 'grades',
          title: '成绩',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('成绩：85'), findsOneWidget);
    store.respond = (_, _) async => {
      'lessons': [
        {'name': '合成课表', 'weeks': '1,3', 'location': '合成教室'},
      ],
    };
    await tester.tap(find.byTooltip('刷新'));
    await tester.pumpAndSettle();
    expect(find.text('合成课表'), findsOneWidget);
    expect(find.text('weeks：1,3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'A rejected saved password offers account update instead of retrying the same query',
    (tester) async {
      final store = _Store();
      store.respond = (_, _) async => throw const AcademicApiException(
        '账号或密码错误，请检查并修改后重新登录。',
        401,
        code: 'credentials_rejected',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FoundationServicePage(
            store: store,
            resource: 'library',
            title: '图书馆',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('学校统一认证'), findsOneWidget);
      expect(find.text('重试查询'), findsNothing);
      expect(store.calls, hasLength(1));
    },
  );
}
