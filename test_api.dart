// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;

void main() async {
  print('Sending GET request to API...');
  try {
    final client = http.Client();
    final response = await client
        .get(Uri.parse('https://roamy-production.up.railway.app/api/v1/places'))
        .timeout(Duration(seconds: 10));
    print('Status Code: ${response.statusCode}');
    print('Body length: ${response.body.length}');
  } catch (e) {
    print('Error: $e');
  }
}
