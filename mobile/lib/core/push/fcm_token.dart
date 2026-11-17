import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Jeton FCM courant, ou `null` si Firebase/push n'est pas disponible.
///
/// Utilisé notamment à la déconnexion pour désactiver l'appareil côté backend
/// avant que le token d'authentification ne soit effacé.
Future<String?> currentFcmToken() async {
  try {
    if (Firebase.apps.isEmpty) {
      return null;
    }
    final token = await FirebaseMessaging.instance.getToken();
    return token == null || token.isEmpty ? null : token;
  } catch (_) {
    return null;
  }
}
