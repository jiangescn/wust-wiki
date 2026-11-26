import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:wust_wiki/foundation/auth.dart';
import 'package:wust_wiki/foundation/client.dart';
import 'package:wust_wiki/foundation/transport.dart';
import 'auth_test.dart' show MemoryPlatform;

class _Authentication extends SchoolAuthentication {
  _Authentication(super.platform);
  final businessStarted = Completer<void>();
  final business = Completer<SchoolTransport>();
  final newLogin = Completer<SchoolTransport>();
  bool Function()? oldSettled;
  bool sawSettled = false;
  @override
  Future<SchoolTransport> businessSession(String key) {
    businessStarted.complete();
    return business.future;
  }

  @override
  void cancel() {
    if (businessStarted.isCompleted && !business.isCompleted) {
      business.completeError(
        const FoundationException('cancelled', 'synthetic cancellation'),
      );
    }
    super.cancel();
  }

  @override
  Future<SchoolTransport> login(String username, String password) {
    sawSettled = oldSettled!();
    return newLogin.future;
  }
}

void main() {
  test(
    'Manual login drains cancelled old queries before replacing credentials',
    () async {
      final platform = MemoryPlatform(),
          auth = _Authentication(MemoryPlatform());
      final client = DartFoundationClient(platform, authentication: auth);
      var settled = false;
      auth.oldSettled = () => settled;
      final old = client
          .request({'action': 'query', 'resource': 'library'})
          .whenComplete(() => settled = true);
      final oldFailure = expectLater(
        old,
        throwsA(
          isA<FoundationException>().having((e) => e.code, 'code', 'cancelled'),
        ),
      );
      await auth.businessStarted.future;
      final login = client.request({
        'action': 'login',
        'username': 'synthetic-account',
        'password': 'synthetic-password',
      });
      await oldFailure;
      await Future<void>.delayed(Duration.zero);
      expect(auth.sawSettled, true);
      await expectLater(
        client.request({'action': 'inspect'}),
        throwsA(
          isA<FoundationException>().having(
            (e) => e.code,
            'code',
            'operation_in_progress',
          ),
        ),
      );
      final identity = SchoolTransport();
      auth.newLogin.complete(identity);
      expect((await login)['unifiedVerified'], true);
      expect(client.currentProgress, isNull);
      identity.close();
      client.cancel();
    },
  );
}
