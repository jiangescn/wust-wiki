import 'dart:io';

import '../lib/update_transport.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln('Usage: dart download-update.dart URL OUTPUT');
    exitCode = 64;
    return;
  }
  final uri = Uri.parse(args.first);
  if (uri.scheme != 'https' ||
      uri.authority != 'download.wust.club' ||
      !uri.path.startsWith('/wiki/')) {
    stderr.writeln('Expected a URL under https://download.wust.club/wiki/');
    exitCode = 64;
    return;
  }

  final client = HttpClient()..connectionTimeout = updateNetworkTimeout;
  try {
    final response = await openUpdateResponse(client, uri);
    await response
        .timeout(updateNetworkTimeout)
        .pipe(File(args.last).openWrite());
  } on Exception catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    client.close(force: true);
  }
}
