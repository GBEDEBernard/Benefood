import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';

class _NoopTokenStore implements TokenStore {
  @override
  Future<String?> readToken() async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> write(Map<String, dynamic> authPayload) async {}

  @override
  Future<void> clear() async {}
}

const _trackingPayload = {
  'active': true,
  'status': 'in_delivery',
  'points': {
    'client': {
      'role': 'client',
      'latitude': 6.35,
      'longitude': 2.42,
      'label': 'Cotonou',
    },
    'driver': {
      'role': 'driver',
      'latitude': 6.36,
      'longitude': 2.43,
    },
  },
  'distances': {
    'straight_km': {'client_driver': 1.4},
    'road_m': 2100,
    'road_provider': 'osrm',
    'road_duration_s': 480,
  },
  'eta': {
    'seconds': 480,
    'minutes': 8,
    'source': 'road',
    'available': true,
  },
  'legacy_position': {
    'latitude': 6.36,
    'longitude': 2.43,
    'accuracy_m': 25,
  },
};

void main() {
  testWidgets('geo API : pays, géocodage inversé et suivi léger', (tester) async {
    final calls = <String>[];
    final client = MockClient((request) async {
      final headers = {'content-type': 'application/json'};
      final path = request.url.path;
      calls.add('${request.method} $path');

      if (path.endsWith('/geo/countries')) {
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'geo-country-bj',
                'code': 'bj',
                'name': 'Bénin',
                'hierarchy': [
                  {'slug': 'department', 'label': 'Département'},
                  {'slug': 'commune', 'label': 'Commune'},
                  {'slug': 'arrondissement', 'label': 'Arrondissement'},
                ],
                'locality_label': 'Village / quartier',
                'source': 'IGN',
              },
            ],
          }),
          200,
          headers: headers,
        );
      }
      if (path.endsWith('/geo/reverse')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['latitude'], 6.36);
        expect(body['longitude'], 2.43);
        expect(body['country'], 'BJ');
        return http.Response(
          jsonEncode({
            'data': {
              'kind': 'locality',
              'id': 'geo-locality-1',
              'name': 'Fidjrossè',
              'label': 'Fidjrossè · Cotonou',
              'locality_kind': 'quartier',
              'code': 'BJ-COTO-FID',
              'path': ['Bénin', 'Littoral', 'Cotonou', 'Fidjrossè'],
              'latitude': 6.36,
              'longitude': 2.43,
              'components': {
                'country': 'Bénin',
                'department': 'Littoral',
                'commune': 'Cotonou',
              },
              'source': 'IGN',
              'provider': 'reference',
            },
          }),
          200,
          headers: headers,
        );
      }
      if (path.endsWith('/orders/ord_1/tracking') ||
          path.endsWith('/parcels/p1/tracking')) {
        return http.Response(
          jsonEncode({'data': _trackingPayload}),
          200,
          headers: headers,
        );
      }
      return http.Response(
        jsonEncode({'message': 'Not found'}),
        404,
        headers: headers,
      );
    });

    final api = MarketplaceApi(
      ApiClient(
        tokenStore: _NoopTokenStore(),
        httpClient: client,
        baseUrl: 'http://api.test',
      ),
    );

    final countries = await api.geoCountries();
    expect(calls, contains('GET /geo/countries'));
    expect(countries, hasLength(1));
    expect(countries.first.code, 'BJ');
    expect(countries.first.hierarchy.map((level) => level.slug), [
      'department',
      'commune',
      'arrondissement',
    ]);

    final place = await api.geoReverse(6.36, 2.43, country: 'BJ');
    expect(calls, contains('POST /geo/reverse'));
    expect(place, isNotNull);
    expect(place!.isLocality, isTrue);
    expect(place.name, 'Fidjrossè');
    expect(place.code, 'BJ-COTO-FID');
    expect(place.components['commune'], 'Cotonou');
    final selection = place.toSelection('BJ', source: 'gps');
    expect(selection?.countryCode, 'BJ');
    expect(selection?.localityId, 'geo-locality-1');
    expect(selection?.source, 'gps');

    final orderTracking = await api.orderTracking('ord_1');
    final parcelTracking = await api.parcelTracking('p1');
    expect(calls, contains('GET /orders/ord_1/tracking'));
    expect(calls, contains('GET /parcels/p1/tracking'));
    expect(orderTracking['status'], 'in_delivery');
    expect(parcelTracking['distances']['road_m'], 2100);
  });

  test('geoReverse : 404 signifie absence de rattachement officiel', () async {
    final client = MockClient((request) async => http.Response(
          jsonEncode({
            'errors': [
              {
                'code': 'geo.not_found',
                'message': 'Aucune localité officielle pour ce point.',
              },
            ],
          }),
          404,
          headers: {'content-type': 'application/json'},
        ));
    final api = MarketplaceApi(
      ApiClient(
        tokenStore: _NoopTokenStore(),
        httpClient: client,
        baseUrl: 'http://api.test',
      ),
    );

    expect(await api.geoReverse(6.4, 2.4), isNull);
  });
}
