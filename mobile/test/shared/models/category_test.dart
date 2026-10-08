import 'package:flutter_test/flutter_test.dart';

import 'package:beninfood/shared/models/category.dart';

void main() {
  group('Category.fromJson — is_active', () {
    test('champ absent (GET /categories) : la catégorie reste active', () {
      final category = Category.fromJson({
        'id': 'cat-1',
        'name': 'Snacks et restauration',
        'slug': 'snacks-et-restauration',
      });

      expect(category.isActive, isTrue);
    });

    test('is_active true : la catégorie est active', () {
      final category = Category.fromJson({
        'id': 'cat-1',
        'name': 'Épicerie',
        'slug': 'epicerie',
        'is_active': true,
      });

      expect(category.isActive, isTrue);
    });

    test('is_active false : la catégorie est inactive', () {
      final category = Category.fromJson({
        'id': 'cat-1',
        'name': 'Cachée',
        'slug': 'cachee',
        'is_active': false,
      });

      expect(category.isActive, isFalse);
    });
  });
}
