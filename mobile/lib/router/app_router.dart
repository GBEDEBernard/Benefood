import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/session_provider.dart';
import '../core/data/marketplace_api.dart';
import '../features/auth/presentation/landing_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/auth/presentation/context_selector_screen.dart';
import '../features/client/presentation/client_shell.dart';
import '../features/client/product/product_detail_screen.dart';
import '../features/client/shop/shop_detail_screen.dart';
import '../features/client/search/search_screen.dart';
import '../features/client/checkout/checkout_screen.dart';
import '../features/client/account/addresses_screen.dart';
import '../features/client/account/complaints_screen.dart';
import '../features/client/account/coupons_screen.dart';
import '../features/client/account/favorites_screen.dart';
import '../features/client/account/notifications_screen.dart';
import '../features/client/account/payment_methods_screen.dart';
import '../features/client/account/profile_edit_screen.dart';
import '../features/client/account/security_screen.dart';
import '../features/client/account/server_settings_screen.dart';
import '../features/client/orders/orders_screen.dart';
import '../features/vendor/presentation/vendor_shell.dart';
import '../features/driver/presentation/driver_shell.dart';
import '../shared/models/user.dart';

/// Routeur central (J146) : contenu protégé selon session + contexte actif.
GoRouter buildAppRouter(SessionProvider session, MarketplaceApi marketplace) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: session,
    redirect: (context, state) {
      if (session.restoring) {
        return null;
      }

      final logged = session.isAuthenticated;
      final location = state.matchedLocation;
      final isAuthRoute = _isAuthRoute(location);

      // Le splash n'est jamais une destination : dès que la restauration est
      // terminée on bascule vers la landing, le sélecteur de contexte ou la
      // home du rôle actif (sinon le spinner tourne indéfiniment).
      if (location == '/') {
        if (!logged) {
          return '/landing';
        }
        return session.activeRole == null ? '/context' : _homeFor(session);
      }

      if (!logged) {
        if (isAuthRoute || location == '/server') {
          return null;
        }
        return '/landing';
      }

      if (isAuthRoute) {
        return _homeFor(session);
      }

      final role = session.activeRole;
      if (role == null) {
        return '/context';
      }
      if (location == '/context') {
        return null;
      }

      // Garde-fou : un utilisateur sans le rôle ne peut pas entrer dans le contexte.
      final allowed = _canAccess(context, session, role, location);
      if (!allowed) {
        return '/context';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _SplashPage(),
      ),
      GoRoute(
        path: '/landing',
        builder: (context, state) => LandingScreen(session: session),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(session: session),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => RegisterScreen(session: session),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => ResetPasswordScreen(session: session),
      ),
      GoRoute(
        path: '/server',
        builder: (context, state) => const ServerSettingsScreen(),
      ),
      GoRoute(
        path: '/context',
        builder: (context, state) => ContextSelectorScreen(session: session),
      ),
      GoRoute(
        path: '/client',
        builder: (context, state) => ClientShell(session: session, marketplace: marketplace),
      ),
      GoRoute(
        path: '/client/product/:id',
        builder: (context, state) => ProductDetailScreen(
          marketplace: marketplace,
          productId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/client/shop/:id',
        builder: (context, state) => ShopDetailScreen(
          marketplace: marketplace,
          vendorId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/client/search',
        builder: (context, state) {
          final extra = state.extra;
          String? category;
          if (extra is Map<String, dynamic> && extra['category'] is String) {
            category = extra['category'] as String;
          }
          return SearchScreen(marketplace: marketplace, initialCategory: category);
        },
      ),
      GoRoute(
        path: '/client/checkout',
        builder: (context, state) => CheckoutScreen(marketplace: marketplace),
      ),
      GoRoute(
        path: '/client/addresses',
        builder: (context, state) {
          final select = state.uri.queryParameters['select'] == '1';
          return AddressesScreen(marketplace: marketplace, selectMode: select);
        },
      ),
      GoRoute(
        path: '/client/orders',
        builder: (context, state) => OrdersScreen(marketplace: marketplace),
      ),
      GoRoute(
        path: '/client/complaints',
        builder: (context, state) => ComplaintsScreen(marketplace: marketplace),
      ),
      GoRoute(
        path: '/client/complaints/new',
        builder: (context, state) {
          final extra = state.extra;
          String? orderId;
          if (extra is Map<String, dynamic> && extra['order_id'] is String) {
            orderId = extra['order_id'] as String;
          }
          return ComplaintCreateScreen(marketplace: marketplace, orderId: orderId);
        },
      ),
      GoRoute(
        path: '/client/complaints/:id',
        builder: (context, state) => ComplaintDetailScreen(
          marketplace: marketplace,
          complaintId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/client/profile/edit',
        builder: (context, state) => ProfileEditScreen(
          marketplace: marketplace,
          session: session,
        ),
      ),
      GoRoute(
        path: '/client/payment-methods',
        builder: (context, state) => PaymentMethodsScreen(marketplace: marketplace),
      ),
      GoRoute(
        path: '/client/security',
        builder: (context, state) => SecurityScreen(marketplace: marketplace),
      ),
      GoRoute(
        path: '/client/notifications',
        builder: (context, state) => NotificationsScreen(marketplace: marketplace),
      ),
      GoRoute(
        path: '/client/favorites',
        builder: (context, state) => FavoritesScreen(marketplace: marketplace),
      ),
      GoRoute(
        path: '/client/coupons',
        builder: (context, state) => CouponsScreen(marketplace: marketplace),
      ),
      GoRoute(
        path: '/vendor',
        builder: (context, state) => VendorShell(session: session, marketplace: marketplace),
      ),
      GoRoute(
        path: '/vendor/profile/edit',
        builder: (context, state) => ProfileEditScreen(marketplace: marketplace, session: session),
      ),
      GoRoute(
        path: '/vendor/notifications',
        builder: (context, state) => NotificationsScreen(marketplace: marketplace),
      ),
      GoRoute(
        path: '/vendor/security',
        builder: (context, state) => SecurityScreen(marketplace: marketplace),
      ),
      GoRoute(
        path: '/vendor/complaints',
        builder: (context, state) => ComplaintsScreen(marketplace: marketplace),
      ),
      GoRoute(
        path: '/driver',
        builder: (context, state) => DriverShell(session: session, marketplace: marketplace),
      ),
      GoRoute(
        path: '/driver/profile/edit',
        builder: (context, state) => ProfileEditScreen(marketplace: marketplace, session: session),
      ),
      GoRoute(
        path: '/driver/notifications',
        builder: (context, state) => NotificationsScreen(marketplace: marketplace),
      ),
      GoRoute(
        path: '/driver/security',
        builder: (context, state) => SecurityScreen(marketplace: marketplace),
      ),
      GoRoute(
        path: '/driver/complaints',
        builder: (context, state) => ComplaintsScreen(marketplace: marketplace),
      ),
    ],
  );
}

bool _isAuthRoute(String location) =>
    location == '/landing' || location == '/login' || location == '/register' || location == '/reset-password';

String _homeFor(SessionProvider session) {
  switch (session.activeRole) {
    case AppContext.vendor:
      return '/vendor';
    case AppContext.driver:
      return '/driver';
    default:
      return '/client';
  }
}

bool _canAccess(BuildContext context, SessionProvider session, String role, String location) {
  final user = session.user;
  if (user == null) {
    return false;
  }
  return user.contexts.contains(role);
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/Logo.jpeg', width: 120, height: 120, errorBuilder: (_, __, ___) => const SizedBox()),
            const SizedBox(height: 20),
            const Text('Béninfood', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            const CircularProgressIndicator(strokeWidth: 2.5),
          ],
        ),
      ),
    );
  }
}