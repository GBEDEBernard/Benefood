import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/driver/account/driver_verification_screen.dart';
import 'package:beninfood/shared/widgets/food_decor.dart';

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

MockClient _mockBackend() {
  const status = {
    'profile': {
      'id': 'dp1',
      'status': 'active',
      'available': false,
      'vehicle': 'Moto TVN-4521',
      'city': 'Cotonou',
      'area': 'Fidjrossè',
      'rating': 4.7,
    },
    'documents': [
      {
        'id': 'doc1',
        'type': 'vehicle_registration',
        'status': 'valid',
        'created_at': '2026-09-01T10:00:00Z',
      },
      {
        'id': 'doc2',
        'type': 'id_card',
        'status': 'submitted',
        'created_at': '2026-09-02T10:00:00Z',
      },
      {
        'id': 'doc3',
        'type': 'insurance',
        'status': 'invalid',
        'created_at': '2026-09-03T10:00:00Z',
      },
    ],
  };

  return MockClient((request) async {
    final headers = {'content-type': 'application/json'};
    if (request.url.path.endsWith('/driver/me/status')) {
      return http.Response(jsonEncode({'data': status}), 200, headers: headers);
    }
    if (request.url.path.endsWith('/me/stats')) {
      return http.Response(
        jsonEncode({
          'data': {'unread_notifications': 0},
        }),
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
}

Future<void> _pumpVerification(
  WidgetTester tester, {
  MockClient? client,
  String? initialFocus,
}) async {
  final api = ApiClient(
    tokenStore: _NoopTokenStore(),
    httpClient: client ?? _mockBackend(),
    baseUrl: 'http://api.test',
  );
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(disableAnimations: true),
          child: child!,
        );
      },
      home: DriverVerificationScreen(
        marketplace: MarketplaceApi(api),
        initialFocus: initialFocus,
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('affiche le véhicule et les statuts réels des documents', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpVerification(tester);

    expect(find.text('Véhicule & documents'), findsOneWidget);
    expect(find.text('Vérification de votre dossier'), findsOneWidget);
    expect(find.text('Vérifié · Moto TVN-4521'), findsOneWidget);
    expect(find.text('Mon véhicule'), findsOneWidget);
    expect(find.byType(FoodDecorPageBackground), findsOneWidget);
    expect(find.text('Moto TVN-4521'), findsOneWidget);
    expect(find.text('Cotonou · Fidjrossè'), findsOneWidget);
    expect(find.text('Documents et vérification'), findsOneWidget);
    expect(find.text('3 documents dans votre dossier.'), findsOneWidget);

    expect(find.text('Validé'), findsOneWidget);
    expect(find.text('En vérification'), findsOneWidget);
    expect(find.text('Rejeté'), findsOneWidget);
    expect(find.text('Document non transmis'), findsNWidgets(2));
    expect(find.text('Remplacer'), findsNWidgets(3));
    expect(find.text('Ajouter'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('le bouton Ajouter ouvre le choix de la source', (tester) async {
    await _pumpVerification(tester, initialFocus: 'documents');

    await tester.tap(find.text('Ajouter').first);
    await tester.pumpAndSettle();

    expect(find.text('Prendre une photo'), findsOneWidget);
    expect(find.text('Choisir dans la galerie'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
