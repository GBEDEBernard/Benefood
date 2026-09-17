import 'package:flutter_test/flutter_test.dart';

import 'package:beninfood/app/app.dart';
import 'package:beninfood/core/auth/session_provider.dart';
import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';

void main() {
  testWidgets('Béninfood app boots and shows splash', (tester) async {
    final api = ApiClient(tokenStore: _MemoryTokenStore());
    final session = SessionProvider(api: api);
    await tester.pumpWidget(
      BeninfoodApp(
        session: session,
        marketplace: MarketplaceApi(api),
      ),
    );
    await tester.pump();

    expect(find.text('Béninfood'), findsWidgets);
  });
}

class _MemoryTokenStore implements TokenStore {
  String? _token;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<String?> readRefreshToken() async => _token;

  @override
  Future<void> write(Map<String, dynamic> authPayload) async {
    _token = authPayload['access_token']?.toString();
  }

  @override
  Future<void> clear() async => _token = null;
}