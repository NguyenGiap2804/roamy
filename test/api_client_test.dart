import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roamy/core/network/api_client.dart';

void main() {
  test('ApiClient keeps error details from backend responses', () async {
    final client = ApiClient(
      baseUrl: 'https://example.com',
      client: MockClient((request) async {
        return http.Response(
          '''
{"status":409,"message":"Duplicate place","data":{"duplicatePlaceId":"place-1","duplicateReason":"maps-url"}}
''',
          409,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    try {
      await client.post('/places', {'name': 'The Cofftea'});
      fail('Expected ApiException');
    } on ApiException catch (error) {
      expect(error.statusCode, 409);
      expect(error.message, 'Duplicate place');
      expect(error.details, {
        'duplicatePlaceId': 'place-1',
        'duplicateReason': 'maps-url',
      });
    }
  });
}
