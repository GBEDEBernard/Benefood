import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beninfood/core/i18n/language_controller.dart';
import 'package:beninfood/shared/widgets/language_menu_button.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await LanguageController.instance.setLanguage('fr');
  });

  testWidgets('affiche les trois langues et mémorise le choix', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: LanguageMenuButton()),
        ),
      ),
    );

    expect(find.byIcon(Icons.language_rounded), findsOneWidget);
    expect(find.text('FR'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.language_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Français'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Fɔngbè'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(LanguageController.instance.code, 'en');
    expect(find.text('EN'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_locale'), 'en');
  });
}
