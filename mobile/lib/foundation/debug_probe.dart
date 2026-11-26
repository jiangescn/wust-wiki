import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'auth.dart';
import 'auth_response.dart';
import 'flutter_platform.dart';
import 'transport.dart';
import 'client.dart';
import 'package:html/parser.dart' as html;

class FoundationAuthProbe extends StatefulWidget {
  const FoundationAuthProbe(this.mode, {super.key});
  final String mode;
  @override
  State<FoundationAuthProbe> createState() => _ProbeState();
}

class _ProbeState extends State<FoundationAuthProbe> {
  String state = 'Running Dart authentication probe';
  @override
  void initState() {
    super.initState();
    unawaited(run());
  }

  Future<void> run() async {
    const platform = AndroidFoundationPlatform();
    final events = <Map<String, dynamic>>[];
    final auth = SchoolAuthentication(
      platform,
      observer: (event) async {
        events.add(event);
        await platform.invoke('acceptanceStatus', {
          'state': 'running',
          'mode': widget.mode,
          'events': events,
        });
      },
    );
    var phase = 'authentication';
    try {
      await platform.invoke('acceptanceStatus', {
        'state': 'running',
        'mode': widget.mode,
      });
      if (widget.mode.startsWith('slider')) {
        await auth.verifyCaptcha(withService: widget.mode == 'slider-service');
        await platform.invoke('acceptanceStatus', {
          'state': 'complete',
          'mode': widget.mode,
          'sliderVerified': true,
          'events': events,
        });
        if (mounted) setState(() => state = 'PASS Dart slider');
        return;
      }
      if (widget.mode == 'identity') {
        await auth.ensureIdentity();
        final tickets = <String, bool>{};
        final failures = <String, String>{};
        for (final service in schoolServices.entries) {
          try {
            final ticket = await auth.serviceTicket(service.value);
            tickets[service.key] = ticket.startsWith('ST-');
          } on FoundationException catch (error) {
            failures[service.key] = error.code;
          }
        }
        await platform.invoke('acceptanceStatus', {
          'state': 'complete',
          'mode': 'identity',
          'identityVerified': auth.identityVerified,
          'restoredWithPassword': auth.restoredWithPassword,
          'serviceTickets': tickets,
          'serviceErrors': failures,
        });
        return;
      }
      if (widget.mode == 'campus') {
        final client = DartFoundationClient(platform, authentication: auth);
        final checked = <String, bool>{}, errors = <String, String>{};
        for (final resource in ['library', 'shuttle', 'second-class']) {
          try {
            await client.request({'action': 'query', 'resource': resource});
            checked[resource] = true;
          } on FoundationException catch (error) {
            errors[resource] = error.code;
          }
        }
        await platform.invoke('acceptanceStatus', {
          'state': 'complete',
          'mode': 'campus',
          'checked': checked,
          'errors': errors,
        });
        return;
      }
      if (widget.mode == 'expire') {
        final account = await platform.load('active-account');
        if (account == null)
          throw const FoundationException('login_required', 'No saved account');
        for (final prefix in ['union-session:', 'dart-session:', 'session:']) {
          final value = await platform.load('$prefix$account');
          if (value != null) {
            final decoded = jsonDecode(utf8.decode(base64Decode(value)));
            final cookies = decoded is List
                ? decoded
                : (decoded as Map)['cookies'] as List;
            for (final cookie in cookies) {
              cookie['expires'] = prefix == 'session:' ? -1000000000 : 1;
            }
            await platform.save(
              '$prefix$account',
              base64Encode(utf8.encode(jsonEncode(decoded))),
            );
          }
        }
      }
      await auth.ensureSession();
      if (widget.mode == 'expire' && !auth.restoredWithPassword)
        throw const FoundationException(
          'wrong_stage',
          'Expected password restoration',
        );
      if (widget.mode == 'warm' && auth.restoredWithPassword)
        throw const FoundationException(
          'wrong_stage',
          'Expected existing session',
        );
      final checked = <String, bool>{};
      if (widget.mode == 'queries' || widget.mode == 'additional') {
        final client = DartFoundationClient(platform, authentication: auth);
        for (final resource
            in (widget.mode == 'additional'
                ? ['training-plan', 'raw-schedule', 'notices']
                : [
                    'schedule',
                    'grades',
                    'exams',
                    'credits',
                    'calendar',
                    'student',
                  ])) {
          phase = resource;
          await client.request({'action': 'query', 'resource': resource});
          checked[resource] = true;
          await platform.invoke('acceptanceStatus', {
            'state': 'running',
            'mode': widget.mode,
            'phase': phase,
            'checked': checked,
          });
        }
      }
      await platform.invoke('acceptanceStatus', {
        'state': 'complete',
        'mode': widget.mode,
        'identityVerified': true,
        'restoredWithPassword': auth.restoredWithPassword,
        if (checked.isNotEmpty) 'checked': checked,
      });
      if (mounted)
        setState(() => state = 'PASS Dart authentication: ${widget.mode}');
    } catch (error) {
      final code = error is FoundationException
          ? error.code
          : error.runtimeType.toString();
      Map<String, dynamic>? structure;
      if (phase == 'training-plan') {
        structure = await auth.withSession((http) async {
          final response = await http.send(
            Uri.parse('https://bkjx.wust.edu.cn/jsxsd/pyfa/topyfamx'),
          );
          final doc = html.parse(response.text);
          return {
            'bytes': response.bytes.length,
            'bodyTags': doc.body?.children.map((e) => e.localName).toList(),
            'tableCount': doc.querySelectorAll('table').length,
            'curriculumTerms': [
              '培养方案',
              '课程编号',
              '课程名称',
              '学分',
              '开设学期',
              '毕业要求',
              '课程代码',
              '教学计划',
              'MsoNormal',
              'pstyle=',
            ].where((t) => response.text.contains(t)).toList(),
            'frames': doc.querySelectorAll('iframe[src]').map((e) {
              final u = response.uri.resolve(e.attributes['src']!);
              return {
                'scheme': u.scheme,
                'host': u.host,
                'path': u.path,
                'queryKeys': u.queryParameters.keys.toList(),
              };
            }).toList(),
            'planLinks': doc
                .querySelectorAll('a[href]')
                .map((e) => response.uri.resolve(e.attributes['href']!).path)
                .where((p) => p.startsWith('/jsxsd/pyfa/'))
                .toSet()
                .toList(),
            'knownErrorTerms': [
              '无权',
              '未开放',
              '不存在',
              '未维护',
              '未发布',
              '没有',
              '错误',
              '失败',
              '未启用',
            ].where((t) => response.text.contains(t)).toList(),
          };
        });
      }
      await platform.invoke('acceptanceStatus', {
        'state': 'failed',
        if (structure != null) 'structure': structure,
        'mode': widget.mode,
        'code': code,
        if (phase == 'training-plan' &&
            error is FoundationException &&
            error.code == 'parse_error')
          'reason': error.message,
        'events': events,
        'phase': phase,
      });
      if (mounted) setState(() => state = 'FAIL Dart authentication: $code');
    } finally {
      auth.cancel();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(body: Center(child: Text(state))),
  );
}
