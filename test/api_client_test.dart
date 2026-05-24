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

  test('ApiClient refreshes once on protected 401 and retries request', () async {
    var calls = 0;
    var token = 'expired-token';
    final client = ApiClient(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => token,
      refreshSession: () async {
        token = 'fresh-token';
        return true;
      },
      client: MockClient((request) async {
        calls += 1;
        if (calls == 1) {
          expect(request.headers['Authorization'], 'Bearer expired-token');
          return http.Response(
            '{"status":401,"message":"Unauthorized","data":null}',
            401,
          );
        }
        expect(request.headers['Authorization'], 'Bearer fresh-token');
        return http.Response(
          '{"status":200,"message":"ok","data":{"ok":true}}',
          200,
        );
      }),
    );

    final response = await client.get('/places');

    expect(response, {'ok': true});
    expect(calls, 2);
  });
}
