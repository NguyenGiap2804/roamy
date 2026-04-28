// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;

void main() async {
  String url = 'https://maps.app.goo.gl/vtyp87TxY2ShPR6v5';
  var finalUrl = url;
  var client = http.Client();
  var request = http.Request('GET', Uri.parse(finalUrl))
    ..followRedirects = false;
  var response = await client.send(request);

  for (var index = 0; index < 10; index++) {
    if (!response.isRedirect) break;
    final location = response.headers['location'];
    if (location != null) {
      finalUrl = Uri.parse(finalUrl).resolve(location).toString();
    }
    request = http.Request('GET', Uri.parse(finalUrl))..followRedirects = false;
    response = await client.send(request);
  }

  print('Final URL: $finalUrl');

  final uri = Uri.parse(finalUrl);
  final pathSegments = uri.pathSegments;

  if (pathSegments.contains('place')) {
    final placeIndex = pathSegments.indexOf('place');
    if (placeIndex + 1 < pathSegments.length) {
      final segmentToDecode = pathSegments[placeIndex + 1];
      print('Segment: $segmentToDecode');
      final decodedName = segmentToDecode.replaceAll('+', ' ');
      print('Name: $decodedName');
    }
  }

  for (final segment in pathSegments) {
    if (segment.startsWith('@')) {
      final parts = segment.substring(1).split(',');
      if (parts.length >= 2) {
        print('Lat: ${double.tryParse(parts[0])}');
        print('Lng: ${double.tryParse(parts[1])}');
      }
    }
  }
}
