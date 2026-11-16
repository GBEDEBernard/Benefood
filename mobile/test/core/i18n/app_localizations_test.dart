import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beninfood/core/i18n/app_localizations.dart';

void main() {
  Widget localized(String code, Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: AppLocalizations(languageCode: code, child: child),
  );

  testWidgets('traduit les textes connus et conserve le français', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      localized(
        'en',
        Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(ctx.tr('Accueil'), 'Home');
    expect(ctx.tr('Se déconnecter'), 'Log out');
  });

  testWidgets('le fon est servi, avec repli sur le français', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      localized(
        'fon',
        Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(ctx.tr('Accueil'), 'Xwégbè');
    expect(ctx.tr('Choisir la langue'), 'Sɔ́ gbe');
    // Clé non traduite : le français reste affiché, jamais la clé technique.
    expect(ctx.tr('Texte non traduit'), 'Texte non traduit');
  });
}
