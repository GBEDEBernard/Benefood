import 'package:beninfood/shared/widgets/product_image_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('le carrousel produit glisse entre les photos avec un compteur anime', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 240,
            child: ProductImageCarousel(
              imageUrls: [
                'https://cdn.example.test/plat-1.webp',
                'https://cdn.example.test/plat-2.webp',
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-220, 0));
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsOneWidget);
  });
}
