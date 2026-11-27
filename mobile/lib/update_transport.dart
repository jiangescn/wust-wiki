import 'dart:io';

const updateNetworkTimeout = Duration(seconds: 20);

Future<HttpClientResponse> openUpdateResponse(
  HttpClient client,
  Uri uri,
) async {
  final response = await _request(client, uri);
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException('HTTP ${response.statusCode}', uri: uri);
  }
  return response;
}

Future<({HttpClientResponse response, int start})> openApkResponse(
  HttpClient client,
  Uri uri, {
  required int offset,
  required int size,
}) async {
  var response = await _request(client, uri, offset: offset);
  if (offset > 0 &&
      response.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
    await response.listen((_) {}).cancel();
    response = await openUpdateResponse(client, uri);
  }

  final start = switch (response.statusCode) {
    HttpStatus.ok => 0,
    HttpStatus.partialContent when offset > 0 => offset,
    _ => throw HttpException('HTTP ${response.statusCode}', uri: uri),
  };
  if (start > 0 &&
      response.headers.value(HttpHeaders.contentRangeHeader)?.toLowerCase() !=
          'bytes $start-${size - 1}/$size') {
    throw const FormatException('APK content range mismatch');
  }
  final encoding = response.headers.value(HttpHeaders.contentEncodingHeader);
  if ((encoding != null && encoding.toLowerCase() != 'identity') ||
      (response.contentLength >= 0 && response.contentLength != size - start)) {
    throw const FormatException('APK response encoding or size mismatch');
  }
  return (response: response, start: start);
}

Future<HttpClientResponse> _request(
  HttpClient client,
  Uri uri, {
  int offset = 0,
}) async {
  final request = await client.getUrl(uri).timeout(updateNetworkTimeout);
  request.followRedirects = false;
  request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
  if (offset > 0) {
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
  }
  return request.close().timeout(updateNetworkTimeout);
}
