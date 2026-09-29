import 'package:flutter_test/flutter_test.dart';

import 'package:beninfood/shared/models/user.dart';

User _userWithRoles(List<String> slugs) => User.fromJson({
      'id': 'usr-1',
      'name': 'Aline',
      'phone': '+22997000001',
      'status': 'active',
      'locale': 'fr',
      'roles': slugs.map((slug) => {'slug': slug, 'name': slug, 'is_active': true}).toList(),
    });

void main() {
  group('AppContext.fromSlug', () {
    test('mappe client et vendor à eux-mêmes', () {
      expect(AppContext.fromSlug('client'), AppContext.client);
      expect(AppContext.fromSlug('vendor'), AppContext.vendor);
    });

    test('regroupe tous les slugs de livreur dans un contexte unique', () {
      for (final slug in ['driver', 'driver-independent', 'driver-beninfood']) {
        expect(AppContext.fromSlug(slug), AppContext.driver, reason: slug);
      }
    });

    test('ignore les rôles hors application (admin, support)', () {
      expect(AppContext.fromSlug('admin'), isNull);
      expect(AppContext.fromSlug(''), isNull);
    });
  });

  group('User.contexts', () {
    test('expose un contexte par espace, sans doublon pour les livreurs', () {
      final user = _userWithRoles(['client', 'driver-independent', 'vendor']);

      expect(user.contexts, {
        AppContext.client,
        AppContext.vendor,
        AppContext.driver,
      });
    });

    test('reste vide si le compte n’a que des rôles hors application', () {
      expect(_userWithRoles(['admin']).contexts, isEmpty);
      expect(_userWithRoles([]).contexts, isEmpty);
    });
  });

  group('User.slugForContext', () {
    test('renvoie le slug réel attendu par POST /me/active-role', () {
      final user = _userWithRoles(['client', 'driver-independent']);

      expect(user.slugForContext(AppContext.client), 'client');
      expect(user.slugForContext(AppContext.driver), 'driver-independent');
    });

    test('prend le slug du livreur Béninfood quand c’est celui du compte', () {
      final user = _userWithRoles(['driver-beninfood']);

      expect(user.slugForContext(AppContext.driver), 'driver-beninfood');
    });

    test('renvoie null pour un contexte non détenu', () {
      expect(_userWithRoles(['client']).slugForContext(AppContext.vendor), isNull);
    });
  });

  group('User.toJson — persistance de session (J146)', () {
    test('conserve les rôles pour la restauration hors ligne', () {
      final restored = User.fromJson(_userWithRoles(['vendor', 'driver-independent']).toJson());

      expect(restored.contexts, {AppContext.vendor, AppContext.driver});
      expect(restored.slugForContext(AppContext.driver), 'driver-independent');
    });
  });
}
