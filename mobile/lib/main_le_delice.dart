import 'package:flutter/material.dart';

import 'features/vendor/restaurant/restaurant_palette.dart';
import 'features/vendor/restaurant/restaurant_shell_screen.dart';

/// Point d'entrée dédié à la prévisualisation de l'interface
/// « Le Délice Fast-Food ».
///
/// Lancement : `flutter run -t lib/main_le_delice.dart`
void main() {
  runApp(const LeDeliceFastFoodApp());
}

class LeDeliceFastFoodApp extends StatelessWidget {
  const LeDeliceFastFoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Le Délice Fast-Food',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: RestaurantPalette.orange),
        scaffoldBackgroundColor: RestaurantPalette.background,
      ),
      home: const RestaurantShellScreen(),
    );
  }
}