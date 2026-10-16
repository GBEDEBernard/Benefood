import 'package:beninfood/core/config/app_config.dart';
import 'package:beninfood/shared/widgets/app_network_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // URL que l'API Laravel renvoie par défaut (APP_URL=http://localhost:8000).
  const backendUrl = 'http://localhost:8000/storage/products/a/b/c.webp';

  tearDown(() => AppConfig.apiBaseUrlOverride = null);

  group('resolveMediaUrl', () {
    test('réécrit une URL localhost vers l\'hôte du tunnel sans garder le port', () {
      AppConfig.apiBaseUrlOverride = 'https://xxx.trycloudflare.com';

      final resolved = resolveMediaUrl(backendUrl);

      expect(resolved, 'https://xxx.trycloudflare.com/storage/products/a/b/c.webp');
    });

    test('réécrit une URL 127.0.0.1 vers l\'hôte courant (adb reverse local)', () {
      AppConfig.apiBaseUrlOverride = 'http://127.0.0.1:8000';

      final resolved = resolveMediaUrl('http://127.0.0.1:8000/storage/x.webp');

      expect(resolved, 'http://127.0.0.1:8000/storage/x.webp');
    });

    test('réécrit une URL de stockage créée avec un ancien domaine de tunnel', () {
      AppConfig.apiBaseUrlOverride = 'http://10.0.2.2:8000';

      final resolved = resolveMediaUrl(
        'https://ancien-tunnel.trycloudflare.com/storage/avatars/user.webp?version=2',
      );

      expect(
        resolved,
        'http://10.0.2.2:8000/storage/avatars/user.webp?version=2',
      );
    });

    test('préfixe un chemin racine-relative', () {
      AppConfig.apiBaseUrlOverride = 'https://xxx.trycloudflare.com';

      expect(resolveMediaUrl('/storage/x.webp'), 'https://xxx.trycloudflare.com/storage/x.webp');
    });

    test('laisse intacte une URL déjà distante (CDN)', () {
      AppConfig.apiBaseUrlOverride = 'https://xxx.trycloudflare.com';

      const cdn = 'https://cdn.example.com/img/x.webp';

      expect(resolveMediaUrl(cdn), cdn);
    });

    test('laisse passer null et chaîne vide', () {
      expect(resolveMediaUrl(null), isNull);
      expect(resolveMediaUrl(''), '');
    });
  });
}
