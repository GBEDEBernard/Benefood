import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beninfood/core/config/api_settings.dart';
import 'package:beninfood/core/config/app_config.dart';
import 'package:beninfood/core/http/api_client.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppConfig.apiBaseUrlOverride = null;
  });

  test(
    'saved server URL applies immediately to existing API clients',
    () async {
      final api = ApiClient(tokenStore: _NoopTokenStore());

      await ApiSettings.saveOverride('http://127.0.0.1:8001');
      expect(api.baseUrl, 'http://127.0.0.1:8001/api/v1');

      await ApiSettings.saveOverride(null);
      expect(api.baseUrl, '${AppConfig.defaultApiBaseUrl}/api/v1');
    },
  );
}

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
