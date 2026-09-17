import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';

/// Image distante avec placeholder et fallback d'erreur.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({super.key, this.url, this.fit = BoxFit.cover, this.icon = Icons.image});

  final String? url;
  final BoxFit fit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final resolved = _resolve(url);
    if (resolved == null || resolved.isEmpty) {
      return _fallback(context);
    }

    return Image.network(
      resolved,
      fit: fit,
      errorBuilder: (context, _, __) => _fallback(context),
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return child;
        }
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        );
      },
    );
  }

  /// Réécrit les URLs générées avec `APP_URL` locale (localhost / 127.0.0.1)
  /// vers l'API configurée dans l'app (`API_BASE_URL`), pour que les images
  /// soient joignables depuis un appareil physique. Gère aussi les chemins
  /// relatifs legacy (`storage/...`, `vendor-media/...`) en les préfixant.
  String? _resolve(String? source) {
    if (source == null || source.isEmpty) {
      return source;
    }

    final base = Uri.parse(AppConfig.apiBaseUrl);

    // Chemin racine-relative ("/storage/...") : on le préfixe avec la base API.
    if (source.startsWith('/')) {
      return base.replace(path: source).toString();
    }

    final uri = Uri.tryParse(source);
    if (uri == null || uri.host.isEmpty) {
      return base.resolve(source).toString();
    }

    if (uri.host != 'localhost' && uri.host != '127.0.0.1') {
      return source;
    }

    return uri
        .replace(
          scheme: base.scheme,
          host: base.host,
          port: base.hasPort ? base.port : uri.port,
        )
        .toString();
  }

  Widget _fallback(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(icon, size: 28, color: Theme.of(context).colorScheme.outline),
    );
  }
}