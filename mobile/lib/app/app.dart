import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../router/app_router.dart';

class BeninfoodApp extends StatelessWidget {
  const BeninfoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Béninfood',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: appRouter,
    );
  }
}