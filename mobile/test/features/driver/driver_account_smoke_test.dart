import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:beninfood/core/auth/session_provider.dart';
import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/core/theme/app_colors.dart';
import 'package:beninfood/core/utils/formatters.dart';
import 'package:beninfood/features/driver/account/driver_account_screen.dart';
import 'package:beninfood/shared/models/user.dart';
import 'package:beninfood/shared/widgets/food_decor.dart';
import 'package:beninfood/shared/widgets/notification_bell.dart';

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

class _TestSession extends SessionProvider {
  _TestSession({required super.api, required this.testUser});

  final User testUser;

  @override
  User? get user => testUser;

  @override
  String? get activeRole => AppContext.driver;
}

const _user = User(
  id: 'u1',
  name: 'Awa Livreuse',
  phone: '+22990000000',
  email: 'awa@example.com',
  roles: [
    UserRole(slug: 'driver-independent', name: 'Livreur', isActive: true),
  ],
);

Map<String, dynamic> _statusPayload({
  String status = 'active',
  bool available = true,
  List<Map<String, dynamic>>? documents,
}) {
  return {
    'profile': {
      'id': 'dp1',
      'user_id': 'u1',
      'status': status,
      'available': available,
      'vehicle': 'Moto TVN-4521',
      'rating': 4.7,
      'city': 'Cotonou',
      'area': 'Fidjrossè',
    },
    'documents':
        documents ??
        [
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
        ],
  };
}

MockClient _mockBackend({
  Map<String, dynamic>? status,
  bool failWallet = false,
}) {
  final statusBody = status ?? _statusPayload();
  const deliveries = [
    {'id': 'd1', 'status': 'delivered', 'fee': 500},
    {'id': 'd2', 'status': 'assigned', 'fee': 300},
  ];
  const parcels = [
    {'id': 'p1', 'reference': 'COL-001', 'status': 'delivered'},
  ];
  const wallet = {
    'pending_balance': 150,
    'available_balance': 700,
    'balance': 850,
    'earnings_total': 1000,
    'withdrawn_total': 0,
    'pending_payout_total': 0,
    'min_payout': 1000,
  };
  const stats = {'unread_notifications': 1};
  const notifications = [
    {
      'id': 'n1',
      'type': 'delivery.assigned',
      'title': 'Nouvelle mission',
      'body': 'Une livraison vous est proposée.',
      'read_at': null,
      'created_at': '2026-10-06T10:00:00Z',
    },
  ];

  return MockClient((request) async {
    final headers = {'content-type': 'application/json'};
    final path = request.url.path;
    if (path.endsWith('/driver/me/status')) {
      return http.Response(
        jsonEncode({'data': statusBody}),
        200,
        headers: headers,
      );
    }
    if (path.endsWith('/driver/me/deliveries')) {
      return http.Response(
        jsonEncode({'data': deliveries}),
        200,
        headers: headers,
      );
    }
    if (path.endsWith('/driver/me/parcels')) {
      return http.Response(
        jsonEncode({'data': parcels}),
        200,
        headers: headers,
      );
    }
    if (path.endsWith('/driver/me/wallet')) {
      if (failWallet) {
        return http.Response(
          jsonEncode({'message': 'Wallet indisponible'}),
          500,
          headers: headers,
        );
      }
      return http.Response(jsonEncode({'data': wallet}), 200, headers: headers);
    }
    if (path.endsWith('/me/stats')) {
      return http.Response(jsonEncode({'data': stats}), 200, headers: headers);
    }
    if (path.endsWith('/me/notifications')) {
      return http.Response(
        jsonEncode({'data': notifications}),
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

late int _selectedTab;

GoRouter _router(SessionProvider session, MarketplaceApi api) {
  const sections = [
    '/driver/profile/edit',
    '/driver/notifications',
    '/driver/security',
    '/driver/complaints',
    '/driver/wallet',
    '/driver/favorite-clients',
    '/driver/stats',
    '/driver/verification',
  ];
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => DriverAccountScreen(
          session: session,
          marketplace: api,
          onSelectTab: (index) => _selectedTab = index,
        ),
      ),
      for (final path in sections)
        GoRoute(
          path: path,
          builder: (context, state) => Scaffold(
            appBar: AppBar(title: const Text('Section')),
            body: Center(child: Text(state.uri.toString())),
          ),
        ),
      GoRoute(
        path: '/landing',
        builder: (context, state) => const Scaffold(body: Text('landing')),
      ),
    ],
  );
}

Future<void> _pumpScreen(WidgetTester tester, {MockClient? client}) async {
  final httpClient = client ?? _mockBackend();
  final apiClient = ApiClient(
    tokenStore: _NoopTokenStore(),
    httpClient: httpClient,
    baseUrl: 'http://api.test',
  );
  final session = _TestSession(api: apiClient, testUser: _user);
  final router = _router(session, MarketplaceApi(apiClient));
  _selectedTab = -1;
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(disableAnimations: true),
          child: child!,
        );
      },
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  final verticalScrollable = find
      .byWidgetPredicate(
        (widget) => widget is Scrollable && widget.axis == Axis.vertical,
        skipOffstage: false,
      )
      .first;
  await tester.scrollUntilVisible(target, 350, scrollable: verticalScrollable);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('affiche les données réelles du compte livreur', (tester) async {
    await _pumpScreen(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(FoodDecorPageBackground), findsOneWidget);

    expect(find.text('Awa Livreuse'), findsOneWidget);
    expect(find.text('Actif'), findsOneWidget);
    expect(find.text('Véhicule vérifié'), findsOneWidget);
    expect(find.text('Cotonou · Fidjrossè'), findsOneWidget);
    expect(find.text('4.7'), findsWidgets);
    expect(find.text('En ligne'), findsOneWidget);

    expect(find.text('Gains cumulés'), findsOneWidget);
    expect(find.text(formatAmount(1000)), findsOneWidget);
    expect(find.text(formatAmount(700)), findsOneWidget);
    expect(find.text(formatAmount(150)), findsOneWidget);

    expect(find.text('Missions'), findsWidgets);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Terminées'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Note moyenne'), findsOneWidget);
    expect(find.text('Taux de réussite'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);

    final bell = tester.widget<NotificationBell>(find.byType(NotificationBell));
    expect(bell.badgeColor, AppColors.orangeVivid);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le QR livreur ne contient que l’identifiant du profil', (
    tester,
  ) async {
    await _pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.qr_code_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Mon QR code livreur'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    final payload = buildDriverQrPayload('dp1');
    expect(find.byKey(ValueKey(payload)), findsOneWidget);
    expect(payload, 'beninfood://driver/profile/dp1');
    expect(payload, isNot(contains('+22990000000')));
    expect(payload, isNot(contains('awa@example.com')));
    expect(payload, isNot(contains('Awa Livreuse')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('les cartes de statistiques ouvrent les onglets dédiés', (
    tester,
  ) async {
    await _pumpScreen(tester);

    await _scrollTo(tester, find.text('Missions'));
    await tester.tap(find.text('Missions').first);
    await tester.pump();
    expect(_selectedTab, 0);

    await _scrollTo(tester, find.text('Terminées'));
    await tester.tap(find.text('Terminées'));
    await tester.pump();
    expect(_selectedTab, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('les menus ouvrent les écrans dédiés', (tester) async {
    await _pumpScreen(tester);

    await _scrollTo(tester, find.text('Documents'));
    await tester.tap(find.text('Documents'));
    await tester.pumpAndSettle();
    expect(find.text('/driver/verification?focus=documents'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Informations personnelles'));
    await tester.tap(find.text('Informations personnelles'));
    await tester.pumpAndSettle();
    expect(
      find.text('/driver/profile/edit?address=Cotonou+%C2%B7+Fidjross%C3%A8'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('un compte en attente ne peut pas passer en ligne', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      client: _mockBackend(
        status: _statusPayload(status: 'pending_validation', available: false),
      ),
    );

    expect(find.text('En attente de validation'), findsOneWidget);
    expect(
      find.text(
        'La disponibilité sera activable dès que votre compte sera validé.',
      ),
      findsOneWidget,
    );
    expect(find.text('En ligne'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le solde indisponible invite à réessayer', (tester) async {
    await _pumpScreen(tester, client: _mockBackend(failWallet: true));

    expect(find.text('…'), findsWidgets);
    expect(find.text('Solde indisponible pour le moment.'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le compte reste sans débordement sur petit écran', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpScreen(tester);
    expect(tester.takeException(), isNull);

    await _scrollTo(tester, find.text('Se déconnecter'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('la déconnexion demande confirmation', (tester) async {
    await _pumpScreen(tester);
    await _scrollTo(tester, find.text('Se déconnecter'));

    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();

    expect(
      find.text('Voulez-vous vraiment vous déconnecter ?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('Voulez-vous vraiment vous déconnecter ?'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
