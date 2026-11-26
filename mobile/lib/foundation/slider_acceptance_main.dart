// AOT-only public CAPTCHA measurement entrypoint. Never part of normal main().
import 'dart:async';
import 'package:flutter/material.dart';
import 'auth.dart';
import 'flutter_platform.dart';
import 'transport.dart';
import 'debug_probe.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final route = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  if (route.startsWith('/foundation-auth-probe/')) {
    final mode = route.split('/').last;
    if (['expire', 'warm', 'queries', 'identity', 'campus'].contains(mode)) {
      runApp(FoundationAuthProbe(mode));
      return;
    }
  }
  runApp(const MaterialApp(home: _SliderAcceptance()));
}

class _SliderAcceptance extends StatefulWidget {
  const _SliderAcceptance();
  @override
  State<_SliderAcceptance> createState() => _SliderAcceptanceState();
}

class _SliderAcceptanceState extends State<_SliderAcceptance> {
  String status = 'Running public CAPTCHA measurement';
  final rounds = <Map<String, dynamic>>[];
  static const label = String.fromEnvironment(
    'SLIDER_LABEL',
    defaultValue: 'current-motion',
  );
  static const count = int.fromEnvironment('SLIDER_ROUNDS', defaultValue: 5);
  @override
  void initState() {
    super.initState();
    unawaited(run());
  }

  Future<void> report(String state) async {
    const platform = AndroidFoundationPlatform();
    final attempts = rounds
        .expand((r) => (r['attempts'] as List).cast<Map<String, dynamic>>())
        .toList();
    await platform.invoke('acceptanceStatus', {
      'state': state,
      'mode': 'slider-measurement',
      'label': label,
      'environment': 'Android x86_64 emulator; Flutter AOT profile',
      'submittedAccountCredentials': false,
      'roundCount': rounds.length,
      'successfulRounds': rounds.where((r) => r['verified'] == true).length,
      'challengeCount': attempts.length,
      'successfulChallenges': attempts
          .where((a) => a['serverCode'] == 1)
          .length,
      'rounds': rounds,
    });
  }

  Future<void> run() async {
    if (count < 1 || count > 30) return;
    for (var index = 0; index < count; index++) {
      final attempts = <Map<String, dynamic>>[];
      final round = <String, dynamic>{
        'index': index + 1,
        'verified': false,
        'attempts': attempts,
      };
      rounds.add(round);
      final auth = SchoolAuthentication(
        const AndroidFoundationPlatform(),
        observer: (event) async {
          switch (event['stage']) {
            case 'challenge-session':
              attempts.add({'serverCode': null});
            case 'slider':
              if (attempts.isNotEmpty)
                attempts.last.addAll({
                  for (final key in ['offset', 'score', 'width', 'height'])
                    key: event[key],
                });
            case 'slider-result':
              if (attempts.isNotEmpty)
                attempts.last.addAll({
                  'serverCode': event['code'],
                  'elapsedMs': event['elapsedMs'],
                });
            case 'slider-error':
              if (attempts.isNotEmpty) attempts.last['error'] = event['code'];
          }
          await report('running');
        },
      );
      try {
        await auth.verifyCaptcha(withService: true);
        round['verified'] = true;
      } catch (error) {
        round['error'] = error is FoundationException
            ? error.code
            : error.runtimeType.toString();
      } finally {
        auth.cancel();
      }
      await report(index == count - 1 ? 'complete' : 'running');
      if (mounted)
        setState(
          () => status = 'Completed ${index + 1}/$count public CAPTCHA rounds',
        );
      if (index < count - 1)
        await Future<void>.delayed(const Duration(milliseconds: 600));
    }
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(status)));
}
