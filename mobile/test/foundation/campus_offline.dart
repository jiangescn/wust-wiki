import 'dart:io';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart campus_offline.dart <foundation-support-directory> <package_config.json>',
    );
    exitCode = 64;
    return;
  }
  final support = Directory(arguments[0]);
  final packages = File(arguments[1]).absolute.path;
  final tests = File.fromUri(Platform.script).parent;
  final foundation = Directory.fromUri(
    tests.uri.resolve('../../lib/foundation/'),
  );
  final temp = Directory.systemTemp.createTempSync('wust-campus-offline-');
  try {
    final target = Directory('${temp.path}/lib/foundation')
      ..createSync(recursive: true);
    final targetTests = Directory('${temp.path}/test/foundation')
      ..createSync(recursive: true);
    for (final name in ['campus_services.dart', 'campus_parsers.dart']) {
      File('${foundation.path}/$name').copySync('${target.path}/$name');
    }
    for (final name in ['platform.dart', 'transport.dart']) {
      File('${support.path}/$name').copySync('${target.path}/$name');
    }
    for (final name in [
      'campus_services_probe.dart',
      'campus_parsers_probe.dart',
      'campus_fixtures.dart',
    ]) {
      File('${tests.path}/$name').copySync('${targetTests.path}/$name');
    }
    for (final probe in [
      'campus_parsers_probe.dart',
      'campus_services_probe.dart',
    ]) {
      final result = await Process.run(Platform.resolvedExecutable, [
        '--packages=$packages',
        '${targetTests.path}/$probe',
      ]);
      stdout.write(result.stdout);
      stderr.write(result.stderr);
      if (result.exitCode != 0) {
        exitCode = result.exitCode;
        return;
      }
    }
    final analysis = await Process.run(Platform.resolvedExecutable, [
      '--packages=$packages',
      'analyze',
      target.path,
      '${targetTests.path}/campus_services_probe.dart',
    ]);
    stdout.write(analysis.stdout);
    stderr.write(analysis.stderr);
    exitCode = analysis.exitCode;
  } finally {
    temp.deleteSync(recursive: true);
  }
}
