import 'dart:io';

const updateNetworkTimeout = Duration(seconds: 20);

Future<HttpClientResponse> openUpdateResponse(
  HttpClient client,
  Uri uri,
) async {
  final request = await client.getUrl(uri).timeout(updateNetworkTimeout);
  request.followRedirects = false;
  final response = await request.close().timeout(updateNetworkTimeout);
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException('HTTP ${response.statusCode}', uri: uri);
  }
  return response;
}
