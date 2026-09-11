import 'package:flutter_test/flutter_test.dart';

import 'package:beninfood/app/app.dart';

void main() {
  testWidgets('Béninfood app boots and shows splash', (tester) async {
    await tester.pumpWidget(const BeninfoodApp());
    await tester.pumpAndSettle();

    expect(find.text('Béninfood'), findsOneWidget);
  });
}