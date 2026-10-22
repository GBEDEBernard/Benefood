import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/vendor/products/products_screen.dart';
import 'package:beninfood/features/vendor/restaurant/restaurant_shell_screen.dart';
import 'package:beninfood/features/vendor/restaurant/screens/activity_screen.dart';
import 'package:beninfood/features/vendor/restaurant/screens/documents_screen.dart';
import 'package:beninfood/features/vendor/restaurant/screens/orders_screen.dart';
import 'package:beninfood/features/vendor/restaurant/screens/revenues_screen.dart';
import 'package:beninfood/features/vendor/restaurant/screens/reviews_screen.dart';
import 'package:beninfood/features/vendor/restaurant/screens/shop_screen.dart';
import 'package:beninfood/features/wallet/widgets/payout_request_sheet.dart';

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

/// Backend de test : statut vendeur ouvert, commandes mixtes et PATCH
/// d'ouverture/fermeture accepté.
MockClient _mockBackend(List<String> log) {
  final vendor = <String, dynamic>{
    'id': 'vnd_1',
    'business_name': 'Le Délice Fast-Food',
    'city': 'Cadjèhoun, Cotonou',
    'address': 'Carrefour des 3 collèges',
    'status': 'active',
    'closed_at': null,
    'is_open': true,
    'hours': [
      {
        'day_of_week': 0,
        'opens_at': '08:00',
        'closes_at': '22:00',
        'is_closed': false,
      },
      {
        'day_of_week': 1,
        'opens_at': '08:00',
        'closes_at': '22:00',
        'is_closed': false,
      },
      {
        'day_of_week': 2,
        'opens_at': '08:00',
        'closes_at': '22:00',
        'is_closed': false,
      },
      {
        'day_of_week': 3,
        'opens_at': '08:00',
        'closes_at': '22:00',
        'is_closed': false,
      },
      {
        'day_of_week': 4,
        'opens_at': '08:00',
        'closes_at': '22:00',
        'is_closed': false,
      },
      {
        'day_of_week': 5,
        'opens_at': null,
        'closes_at': null,
        'is_closed': true,
      },
      {
        'day_of_week': 6,
        'opens_at': null,
        'closes_at': null,
        'is_closed': true,
      },
    ],
  };

  final now = DateTime.now();
  String ago(Duration d) => now.subtract(d).toUtc().toIso8601String();
  final orders = [
    {
      'id': 'ord_1',
      'reference': '#BF1256',
      'status': 'paid',
      'payment_status': 'paid',
      'total': 12000,
      'subtotal': 12000,
      'delivery_fee': 0,
      'items': [
        {
          'id': 'it_1',
          'name': 'Burger poulet',
          'quantity': 2,
          'unit_price': 6000,
          'subtotal': 12000,
        },
      ],
      'created_at': ago(const Duration(minutes: 5)),
    },
    {
      'id': 'ord_2',
      'reference': '#BF1255',
      'status': 'awaiting_payment',
      'payment_status': 'pending',
      'total': 4500,
      'subtotal': 4500,
      'delivery_fee': 0,
      'items': [
        {
          'id': 'it_2',
          'name': 'Frites',
          'quantity': 1,
          'unit_price': 4500,
          'subtotal': 4500,
        },
      ],
      'created_at': ago(const Duration(minutes: 20)),
    },
    {
      'id': 'ord_3',
      'reference': '#BF1254',
      'status': 'preparing',
      'payment_status': 'paid',
      'total': 9000,
      'subtotal': 9000,
      'delivery_fee': 0,
      'items': [
        {
          'id': 'it_3',
          'name': 'Pizza',
          'quantity': 1,
          'unit_price': 9000,
          'subtotal': 9000,
        },
      ],
      'created_at': ago(const Duration(minutes: 50)),
    },
    {
      'id': 'ord_4',
      'reference': '#BF1253',
      'status': 'delivered',
      'payment_status': 'paid',
      'total': 7500,
      'subtotal': 7500,
      'delivery_fee': 0,
      'items': [
        {
          'id': 'it_4',
          'name': 'Wrap',
          'quantity': 1,
          'unit_price': 7500,
          'subtotal': 7500,
        },
      ],
      'created_at': ago(const Duration(hours: 2)),
    },
  ];

  return MockClient((request) async {
    final headers = {'content-type': 'application/json'};
    final path = request.url.path;
    log.add('${request.method} $path');

    if (path.endsWith('/vendors/me/status')) {
      return http.Response(
        jsonEncode({
          'data': {'vendor': vendor, 'documents': <dynamic>[]},
        }),
        200,
        headers: headers,
      );
    }
    if (path.endsWith('/vendors/me/orders')) {
      return http.Response(jsonEncode({'data': orders}), 200, headers: headers);
    }
    if (path.endsWith('/vendors/me/wallet/payouts') &&
        request.method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'data': {
            'id': 'payout_test',
            'amount': body['amount'],
            'method': body['method'],
            'status': 'pending',
          },
        }),
        201,
        headers: headers,
      );
    }
    if (path.endsWith('/me/notifications')) {
      return http.Response(
        jsonEncode({'data': <dynamic>[]}),
        200,
        headers: headers,
      );
    }
    if (request.method == 'PATCH' && path.endsWith('/vendors/me')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (body.containsKey('closed_at')) {
        final open = body['closed_at'] == null;
        vendor['is_open'] = open;
        vendor['closed_at'] = body['closed_at'];
      }
      for (final entry in body.entries) {
        if (entry.key == 'hours' && entry.value is List) {
          vendor['hours'] = entry.value;
          continue;
        }
        if (entry.value != null) {
          vendor[entry.key] = entry.value;
        }
      }
      final response = Map<String, dynamic>.of(vendor);
      return http.Response(
        jsonEncode({'data': response}),
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

Future<void> _pumpShell(
  WidgetTester tester,
  List<String> log, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final api = ApiClient(
    tokenStore: _NoopTokenStore(),
    httpClient: _mockBackend(log),
    baseUrl: 'http://api.test',
  );
  await tester.pumpWidget(
    MaterialApp(home: RestaurantShellScreen(marketplace: MarketplaceApi(api))),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mobile : tableau de bord avec hamburger → drawer → boutique', (
    tester,
  ) async {
    final log = <String>[];
    await _pumpShell(tester, log, size: const Size(390, 844));

    // En-tête : hamburger, logo + écriture Béninfood, cloche de notifications.
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.text('BÉNINFOOD', findRichText: true), findsOneWidget);
    expect(find.image(const AssetImage('assets/Logo.jpeg')), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none), findsOneWidget);
    // Titre vert du tableau de bord + badge d'état, stats, commandes.
    expect(find.text('Tableau de bord'), findsOneWidget); // titre de l'écran
    expect(find.text('Ouvert'), findsOneWidget);
    // Salutation personnalisée + accès aux statistiques.
    expect(find.text('Bonjour 👋'), findsOneWidget);
    expect(find.text('Voir les statistiques'), findsWidgets);
    expect(find.text('Commandes du jour'), findsOneWidget);
    expect(find.text('CA du jour'), findsOneWidget);

    // Graphiques : courbe des ventes et répartition des commandes.
    await tester.scrollUntilVisible(
      find.text('Aperçu des ventes'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Aperçu des ventes'), findsOneWidget);
    expect(find.text('Répartition'), findsOneWidget);

    // Le flux continue avec les commandes à traiter et les meilleures ventes.
    await tester.scrollUntilVisible(
      find.text('Nouvelles commandes'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Nouvelles commandes'), findsOneWidget);
    expect(find.text('#BF1256'), findsOneWidget);
    expect(find.text('Accepter'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Produits les plus vendus'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Burger poulet'), findsOneWidget);

    // Barre de navigation : 5 accès dont la Boutique surélevée au centre.
    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Commandes'), findsOneWidget);
    expect(find.text('Boutique'), findsOneWidget);
    expect(find.text('Portefeuille'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    // Le drawer est fermé au départ.
    expect(find.text('Vue d’ensemble'), findsNothing);

    // Retour en haut du tableau de bord avant d'ouvrir le menu latéral.
    await tester.scrollUntilVisible(
      find.text('Tableau de bord'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Ouvrir le menu latéral via le hamburger.
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Vue d’ensemble'), findsOneWidget);
    expect(find.text('LE DÉLICE FAST-FOOD'), findsNothing);
    expect(find.text('Ouvert'), findsWidgets);
    expect(find.text('Ma boutique'), findsOneWidget);
    expect(find.text('Mes produits'), findsOneWidget);
    expect(find.text('Commandes'), findsNWidgets(2)); // tiroir + barre
    expect(
      find.text('Revenus'),
      findsOneWidget,
    ); // tiroir (barre = Portefeuille)
    expect(find.text('Mon dossier'), findsOneWidget);
    expect(find.text('Se déconnecter'), findsOneWidget);

    // Cliquer « Boutique » : l'écran principale bascule sur Ma boutique.
    await tester.tap(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Ma boutique'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ma boutique'), findsWidgets);
    // La section Statut est plus bas avec la barre d'actions en pied d'écran.
    await tester.scrollUntilVisible(
      find.text('Statut de la boutique'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Statut de la boutique'), findsOneWidget);
    expect(find.text('Statut du compte'), findsOneWidget);
    expect(find.text('Actif'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('barre inférieure : navigation dynamique entre les écrans', (
    tester,
  ) async {
    final log = <String>[];
    await _pumpShell(tester, log, size: const Size(390, 844));

    // Portefeuille
    await tester.tap(find.text('Portefeuille'));
    await tester.pumpAndSettle();
    expect(find.byType(RevenusScreen), findsOneWidget);
    expect(find.text('BÉNINFOOD', findRichText: true), findsOneWidget);
    expect(find.text('Portefeuille'), findsWidgets); // titre + barre

    // Bannière et synthèse calculées depuis les commandes du backend de test.
    expect(find.text('SOLDE DISPONIBLE'), findsOneWidget);
    expect(find.text('4 250'), findsWidgets); // 6 750 livrés − 2 500 retirés
    expect(find.text('LIVRAISONS EN ATTENTE'), findsOneWidget);
    expect(find.text('18 900'), findsWidgets); // 2 commandes en cours
    expect(find.text('TOTAL GAGNÉ'), findsOneWidget);
    expect(find.text('28 500'), findsOneWidget); // ventes validées
    expect(find.text('COMMISSIONS PAYÉES'), findsOneWidget);
    expect(find.text('2 850'), findsWidgets); // commission 10 %
    expect(find.text('RÉPARTITION DES FONDS'), findsOneWidget);
    expect(find.text('Séquentrés libérés'), findsWidgets);
    expect(find.text('6 750'), findsOneWidget); // 7 500 livrés − 10 %

    // Mouvements : séquestre libéré, ventes en cours, commissions et retraits.
    await tester.scrollUntilVisible(
      find.text('Historique des retraits'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Mouvements'), findsWidgets); // titre + onglet
    expect(find.text('Séquestre libéré'), findsOneWidget);
    expect(find.text('Vente en cours'), findsWidgets);
    expect(find.text('Commission prélevée'), findsWidgets);
    expect(find.text('Voir tous les mouvements'), findsOneWidget);

    // Historique des retraits.
    expect(find.text('Historique des retraits'), findsOneWidget);
    expect(find.text('Voir tout'), findsOneWidget);

    // Commandes
    await tester.tap(find.text('Commandes'));
    await tester.pumpAndSettle();
    expect(find.byType(OrdersScreen), findsOneWidget);

    // Boutique (accès central surélevé)
    await tester.tap(find.text('Boutique'));
    await tester.pumpAndSettle();
    expect(find.byType(ShopScreen), findsOneWidget);

    // Profil (session absente ici : écran d'attente du compte)
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(
      find.text('Profil & Paramètres — bientôt disponible'),
      findsOneWidget,
    );

    // Retour à l'accueil depuis la barre.
    await tester.tap(find.text('Accueil'));
    await tester.pumpAndSettle();
    expect(find.text('Commandes du jour'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'fermeture boutique : interrupteur → PATCH /vendors/me puis toast',
    (tester) async {
      final log = <String>[];
      await _pumpShell(tester, log, size: const Size(390, 844));

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('Ma boutique'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byType(Switch),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Fermeture temporaire : le motif est requis (J21 §3.2).
      expect(find.text('Fermer la boutique'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Rupture de stock');
      await tester.tap(find.widgetWithText(FilledButton, 'Fermer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(log, contains('PATCH /vendors/me'));
      expect(find.text('Boutique fermée.'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Boutique fermée.'), findsNothing);
    },
  );

  testWidgets('modification infos boutique : éditeur → PATCH /vendors/me', (
    tester,
  ) async {
    final log = <String>[];
    await _pumpShell(tester, log, size: const Size(390, 844));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Ma boutique'),
      ),
    );
    await tester.pumpAndSettle();

    // Le profil affiche les infos issues de l'API.
    expect(find.text('Le Délice Fast-Food'), findsWidgets);

    // Ouvrir l'éditeur d'informations depuis l'en-tête.
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    expect(find.text('Enregistrer'), findsOneWidget);

    // Renommer la boutique.
    await tester.enterText(
      find.byType(TextFormField).first,
      'Le Délice Gourmet',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(log, contains('PATCH /vendors/me'));
    // Le shell re-charge le statut : le nouveau nom apparaît dans la boutique.
    expect(find.text('Le Délice Gourmet'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ma boutique : carte horaires → éditeur → sélecteur d’heure', (
    tester,
  ) async {
    final log = <String>[];
    await _pumpShell(tester, log, size: const Size(390, 844));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Ma boutique'),
      ),
    );
    await tester.pumpAndSettle();

    // La semaine est affichée et chaque jour ouvre l'éditeur.
    expect(find.text('Lundi'), findsOneWidget);
    expect(find.text('Dimanche'), findsOneWidget);
    await tester.tap(find.text('Lundi'));
    await tester.pumpAndSettle();
    expect(find.text('Enregistrer'), findsOneWidget);

    // Jours ouverts dans le statut de départ (samedi/dimanche fermés).
    expect(find.text('08:00'), findsNWidgets(5));
    expect(find.text('Tout ouvrir'), findsOneWidget);
    expect(find.text('Tout fermer'), findsOneWidget);
    expect(find.text('Copier le lundi'), findsOneWidget);

    // Raccourcis : ouvrir et refermer toute la semaine d'un seul geste.
    await tester.tap(find.text('Tout ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('08:00'), findsNWidgets(7));
    await tester.tap(find.text('Tout fermer'));
    await tester.pumpAndSettle();
    expect(find.text('08:00'), findsNothing);
    await tester.tap(find.text('Tout ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('08:00'), findsNWidgets(7));

    // Sélecteur d'heure maison : molettes 24 h, raccourcis, Annuler/Valider.
    await tester.ensureVisible(find.text('08:00').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('08:00').first);
    await tester.pumpAndSettle();
    expect(find.text('Valider'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
    expect(find.text('Heure d’ouverture · Lundi'), findsOneWidget);

    await tester.tap(find.text('14:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(find.text('Valider'), findsNothing);
    expect(find.text('14:00'), findsOneWidget);

    // Enregistrement : la planification complète part en PATCH.
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(log, contains('PATCH /vendors/me'));
    expect(find.text('Horaires enregistrés.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ma boutique : carte adresse → éditeur « Mes adresses » → PATCH',
    (tester) async {
      final log = <String>[];
      await _pumpShell(tester, log, size: const Size(390, 844));

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('Ma boutique'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Adresse'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adresse'));
      await tester.pumpAndSettle();

      // Trois sections : boutique, retrait livreurs et informations.
      expect(find.text('Mes adresses'), findsOneWidget);
      expect(find.text('Adresse de la boutique'), findsOneWidget);
      expect(find.text('Adresse de retrait (livreurs)'), findsOneWidget);
      expect(find.text('Informations supplémentaires'), findsOneWidget);
      expect(find.text('Instructions pour le livreur'), findsOneWidget);

      // Édition de l'adresse de la boutique puis enregistrement.
      await tester.enterText(
        find.byType(TextFormField).first,
        'Rue des Palmiers',
      );
      await tester.tap(find.text('Enregistrer'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(log, contains('PATCH /vendors/me'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('produits : hamburger → tiroir, recherche et onglets', (
    tester,
  ) async {
    final log = <String>[];
    await _pumpShell(tester, log, size: const Size(390, 844));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Mes produits'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BÉNINFOOD', findRichText: true), findsOneWidget);
    expect(find.byType(ProductsScreen), findsOneWidget);

    // Le hamburger de l'écran réouvre le tiroir latéral (plus de bouton retour).
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Vue d’ensemble'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Commandes du jour'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('commandes (démo) : onglets dynamiques, actions et détail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: RestaurantShellScreen()));
    await tester.pumpAndSettle();

    // Onglet Commandes de la barre inférieure : liste des commandes.
    await tester.tap(find.text('Commandes'));
    await tester.pumpAndSettle();
    expect(find.byType(OrdersScreen), findsOneWidget);
    expect(find.text('BÉNINFOOD', findRichText: true), findsOneWidget);
    expect(find.text('Commandes'), findsWidgets); // en-tête carte + barre

    // Compteurs dynamiques : 3 nouvelles, 2 en préparation, 1 prête, 2 terminées.
    expect(find.text('Nouvelles (3)'), findsOneWidget);
    expect(find.text('Préparation (2)'), findsOneWidget);
    expect(find.text('Prêtes (1)'), findsOneWidget);
    expect(find.text('Terminées (2)'), findsOneWidget);

    // Première carte : client, montant et étiquette de statut.
    expect(find.text('#BF1256'), findsOneWidget);
    expect(find.text('Ulrich Hounkpe'), findsOneWidget);
    expect(find.text('14 000 FCFA'), findsWidgets);
    expect(find.text('4 articles'), findsWidgets);

    // Accepter : la commande passe dans l'onglet Préparation.
    await tester.tap(find.text('Accepter').first);
    await tester.pumpAndSettle();
    expect(find.text('#BF1256 acceptée.'), findsOneWidget);
    expect(find.text('Nouvelles (2)'), findsOneWidget);
    expect(find.text('Préparation (3)'), findsOneWidget);

    // Détail de la commande acceptée : client, notes, total, action suivante.
    await tester.tap(find.text('Préparation (3)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voir détails').first);
    await tester.pumpAndSettle();
    expect(find.text('Commande #BF1256'), findsOneWidget);
    expect(find.text('+229 97 00 00 00'), findsOneWidget);
    expect(
      find.text('Bien cuire les frites, pas de sauce piquante.'),
      findsOneWidget,
    );
    expect(find.text('Sous-total'), findsOneWidget);
    expect(find.text('13 500 FCFA'), findsWidgets);
    expect(find.text('Paiement à la livraison (Espèces)'), findsOneWidget);
    expect(find.text('Détail financier'), findsOneWidget);
    // L'écran de détail est empilé sur la liste : les textes communs peuvent
    // être trouvés deux fois.
    expect(find.text('Ulrich Hounkpe'), findsWidgets);
    expect(find.text('14 000 FCFA'), findsWidgets);
    expect(find.text('Commencer la préparation'), findsWidgets);

    // Retour à la liste, puis onglet Terminées : historique livré/annulé.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminées (2)'));
    await tester.pumpAndSettle();
    expect(find.text('#BF1250'), findsOneWidget);
    expect(find.text('Livrée'), findsOneWidget);
    expect(find.text('Annulée'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('portefeuille (démo) : solde, répartition et sélecteur de mois', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: RestaurantShellScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Portefeuille'));
    await tester.pumpAndSettle();
    expect(find.byType(RevenusScreen), findsOneWidget);
    expect(find.text('BÉNINFOOD', findRichText: true), findsOneWidget);
    expect(find.text('Portefeuille'), findsWidgets); // titre + barre
    expect(find.text('5 commandes'), findsOneWidget);

    // Bannière : solde disponible issu des commandes de démonstration.
    expect(find.text('SOLDE DISPONIBLE'), findsOneWidget);
    expect(find.text('2 630'), findsWidgets); // 5 130 livrés − 2 500 retirés
    expect(find.text('Disponible au retrait'), findsOneWidget);
    expect(find.text('Faire un retrait'), findsOneWidget);

    // Cartes de synthèse.
    expect(find.text('LIVRAISONS EN ATTENTE'), findsOneWidget);
    expect(find.text('50 220'), findsWidgets); // 5 commandes en cours
    expect(find.text('TOTAL GAGNÉ'), findsOneWidget);
    expect(find.text('61 500'), findsOneWidget); // ventes validées
    expect(find.text('TAUX DE COMMISSION'), findsOneWidget);
    expect(find.text('10 %'), findsWidgets); // carte + part du donut
    expect(find.text('COMMISSIONS PAYÉES'), findsOneWidget);
    expect(find.text('6 150'), findsWidgets); // 10 % des ventes

    // Répartition des fonds : donut + légende.
    expect(find.text('RÉPARTITION DES FONDS'), findsOneWidget);
    expect(find.text('Séquentrés libérés'), findsWidgets);
    expect(find.text('5 130'), findsOneWidget); // 5 700 livrés − 10 %

    // Mouvements : ventes vertes (+), commissions rouges (−), retraits.
    await tester.scrollUntilVisible(
      find.text('Historique des retraits'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Mouvements'), findsWidgets); // titre + onglet
    expect(find.text('Vente en cours'), findsWidgets);
    expect(find.text('Commission prélevée'), findsWidgets);
    expect(find.text('Retrait demandé'), findsOneWidget);
    expect(find.text('+12 150'), findsOneWidget); // 13 500 − 10 %
    expect(find.text('-1 350'), findsOneWidget);
    expect(find.text('+7 200'), findsOneWidget); // 8 000 − 10 %
    expect(find.textContaining('#BF1256'), findsWidgets);
    expect(find.text('Voir tous les mouvements'), findsOneWidget);

    // Historique des retraits.
    expect(find.text('Historique des retraits'), findsOneWidget);
    expect(find.text('4 500 FCFA vers Moov Money'), findsOneWidget);
    expect(find.text('2 500 FCFA vers MTN Mobile Money'), findsOneWidget);
    expect(find.text('Voir tout'), findsOneWidget);

    // Sélecteur de mois : réellement fonctionnel.
    await tester.scrollUntilVisible(
      find.byIcon(Icons.keyboard_arrow_down_rounded),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Période'), findsOneWidget);
    expect(find.byType(ListTile), findsWidgets);

    await tester.tap(find.byType(ListTile).at(1));
    await tester.pumpAndSettle();
    // Le mois précédent n'a ni vente ni retrait : les compteurs tombent à zéro.
    expect(find.text('0'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Aucune transaction ce mois-ci'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Aucune transaction ce mois-ci'), findsOneWidget);
  });

  testWidgets(
    'produits (démo) : recherche, onglets, bascule, archivage et FAB',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: RestaurantShellScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('Mes produits'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProductsScreen), findsOneWidget);
      expect(find.text('BÉNINFOOD', findRichText: true), findsOneWidget);
      expect(find.text('Rechercher un produit...'), findsOneWidget);

      // Onglets dynamiques : 9 produits dont 2 archivés.
      expect(find.text('Tous (9)'), findsOneWidget);
      expect(find.text('Archives (2)'), findsOneWidget);

      // Première carte : nom, prix orange, unité, stock et statistiques.
      expect(find.text('Akassa sauce arachide'), findsOneWidget);
      expect(find.text('1 200 FCFA'), findsOneWidget);
      expect(find.text('portion'), findsWidgets);
      expect(find.text('Stock : 35'), findsOneWidget);
      expect(find.text('4,6'), findsOneWidget);
      expect(find.text('(18 avis)'), findsOneWidget);
      expect(find.text('32'), findsOneWidget);

      // Bascule Actif → inactif via le bouton unique : toast « Produit masqué ».
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Produit masqué'), findsOneWidget);

      // Recherche : seule la fiche correspondante reste visible.
      await tester.enterText(find.byType(TextField), 'att');
      await tester.pumpAndSettle();
      expect(find.text('Attiéké poisson'), findsOneWidget);
      expect(find.text('Akassa sauce arachide'), findsNothing);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.text('Akassa sauce arachide'), findsOneWidget);

      // Onglet Archives : uniquement les produits archivés.
      await tester.tap(find.text('Archives (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Salade complète'), findsOneWidget);
      expect(find.text('Glace artisanale'), findsOneWidget);
      expect(find.text('Akassa sauce arachide'), findsNothing);

      // Retour sur Tous, puis menu contextuel → Archiver.
      await tester.tap(find.text('Tous (9)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Archiver'), findsOneWidget);
      expect(find.text('Supprimer'), findsOneWidget);
      await tester.tap(find.text('Archiver'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Produit archivé'), findsOneWidget);
      expect(find.text('Archives (3)'), findsOneWidget);

      // FAB « Ajouter un produit » : toast en mode démo.
      await tester.tap(find.text('Ajouter un produit'));
      await tester.pump();
      expect(
        find.text('Formulaire produit bientôt disponible.'),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('menu latéral : mon dossier, mes avis clients et historique', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: RestaurantShellScreen()));
    await tester.pumpAndSettle();

    // Mon dossier : progression + documents (démo).
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Mon dossier'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DocumentsScreen), findsOneWidget);
    expect(
      find.text('BÉNINFOOD', findRichText: true),
      findsOneWidget,
    ); // en-tête comun brandé
    expect(find.text('VÉRIFICATION DU DOSSIER'), findsOneWidget);
    expect(find.text('Registre de commerce'), findsOneWidget);
    expect(find.text('Validé'), findsWidgets);

    // Mes avis clients : note moyenne + commentaires (démo).
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Avis clients'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ReviewsScreen), findsOneWidget);
    expect(find.text('BÉNINFOOD', findRichText: true), findsOneWidget);
    expect(
      find.text('Très bon, livraison rapide et plats bien chauds !'),
      findsOneWidget,
    );
    expect(find.text('24 avis'), findsOneWidget);

    // Historique : chronologie des activités (démo).
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Historique'),
      240,
      scrollable: find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Historique'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ActivityScreen), findsOneWidget);
    expect(find.text('BÉNINFOOD', findRichText: true), findsOneWidget);
    expect(find.text('Commande livrée'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tableau de bord (démo) : périodes, statut et meilleures ventes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: RestaurantShellScreen()));
      await tester.pumpAndSettle();

      // Salutation de démonstration, période courante et raccourcis.
      expect(find.text('Bonjour, Marion 👋'), findsOneWidget);
      expect(find.text('Commandes du jour'), findsOneWidget);
      expect(find.text('CA du jour'), findsOneWidget);
      expect(find.text('Ajouter un produit'), findsOneWidget);
      expect(find.text('Créer une promo'), findsOneWidget);

      // Le sélecteur de période recalcule la carte principale et les KPI.
      await tester.tap(find.text('Aujourd’hui'));
      await tester.pumpAndSettle();
      expect(find.text('Période'), findsOneWidget);
      await tester.tap(find.text('Cette semaine'));
      await tester.pumpAndSettle();
      expect(find.text('CHIFFRE D’AFFAIRES DE LA SEMAINE'), findsOneWidget);
      expect(find.text('Commandes de la semaine'), findsOneWidget);
      expect(find.text('CA de la semaine'), findsOneWidget);

      // Le statut de la boutique s'ouvre dans une feuille dédiée.
      await tester.tap(find.text('Ouvert'));
      await tester.pumpAndSettle();
      expect(find.text('Statut de la boutique'), findsOneWidget);
      await tester.tap(find.text('Ouvrir la boutique'));
      await tester.pumpAndSettle();
      expect(find.text('Statut de la boutique'), findsNothing);
      expect(find.text('Ouvert'), findsOneWidget);

      // Les meilleures ventes de démonstration sont proposées en carrousel.
      await tester.scrollUntilVisible(
        find.text('Produits les plus vendus'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Alloco poulet'), findsOneWidget);
      expect(find.text('Riz sauce tomate'), findsOneWidget);
      expect(find.text('42 vendus'), findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'portefeuille : le retrait ouvre directement le formulaire Mobile Money',
    (tester) async {
      final log = <String>[];
      await _pumpShell(tester, log, size: const Size(390, 844));

      await tester.tap(find.text('Portefeuille'));
      await tester.pumpAndSettle();
      expect(find.text('Faire un retrait'), findsOneWidget);

      // Plus de page wallet intermédiaire : le formulaire s'ouvre sur place.
      await tester.tap(find.text('Faire un retrait'));
      await tester.pumpAndSettle();
      expect(find.text('Retirer mes gains'), findsOneWidget);
      expect(find.text('Confirmer le retrait'), findsOneWidget);

      // Le numéro de la boutique n'est pas exposé par ce backend de test.
      await tester.enterText(
        find.byKey(PayoutRequestSheet.phoneFieldKey),
        '+22996000000',
      );
      await tester.tap(find.text('Confirmer le retrait'));
      await tester.pumpAndSettle();

      expect(log, contains('POST /vendors/me/wallet/payouts'));
      expect(
        find.text('Demande de retrait enregistrée, en cours de traitement.'),
        findsOneWidget,
      );
      expect(find.text('Retirer mes gains'), findsNothing);

      // « Voir tout » ouvre l'historique complet en feuille, sans page dédiée.
      await tester.scrollUntilVisible(
        find.text('Historique des retraits'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voir tout'));
      await tester.pumpAndSettle();
      expect(find.text('Historique des retraits'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tableau de bord : lisible sur un écran compact', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: RestaurantShellScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Bonjour, Marion 👋'), findsOneWidget);
    expect(find.text('Commandes du jour'), findsOneWidget);

    // Les graphiques s'empilent et la page reste parcourable sans débordement.
    await tester.scrollUntilVisible(
      find.text('Produits les plus vendus'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Alloco poulet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
