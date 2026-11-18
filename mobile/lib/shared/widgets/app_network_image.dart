import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';

/// Réécrit les URLs générées avec `APP_URL` locale (localhost / 127.0.0.1)
/// vers l'API configurée dans l'app ([AppConfig.apiBaseUrl]), pour que les
/// images soient joignables depuis un appareil physique. Gère aussi les
/// chemins relatifs legacy (`storage/...`, `vendor-media/...`) en les
/// préfixant.
String? resolveMediaUrl(String? source) {
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

  // Les URLs legacy du disque local Laravel utilisent `/storage/...` et
  // doivent être ramenées sur l'API. Les stockages externes (Supabase, R2,
  // S3) peuvent aussi exposer un chemin `/storage/...` : on ne réécrit donc
  // que si l'hôte est celui de l'API, un hôte local ou un ancien tunnel.
  final isApiOrLocalHost = uri.host == base.host ||
      uri.host == 'localhost' ||
      uri.host == '127.0.0.1' ||
      _isLegacyTunnelHost(uri.host);
  if (isApiOrLocalHost &&
      (uri.path == '/storage' || uri.path.startsWith('/storage/'))) {
    return base
        .replace(
          path: uri.path,
          query: uri.hasQuery ? uri.query : null,
          fragment: uri.hasFragment ? uri.fragment : null,
        )
        .toString();
  }

  if (uri.host != 'localhost' && uri.host != '127.0.0.1') {
    return source;
  }

  // On remplace schéma + hôte (+ port) par ceux de la base API configurée :
  // le port éventuel (ex. 8000) ne doit pas être reporté sur l'hôte public.
  return base
      .replace(
        path: uri.path,
        query: uri.hasQuery ? uri.query : null,
        fragment: uri.hasFragment ? uri.fragment : null,
      )
      .toString();
}

bool _isLegacyTunnelHost(String host) {
  return host.endsWith('.ngrok-free.app') ||
      host.endsWith('.ngrok.io') ||
      host.endsWith('.trycloudflare.com');
}

bool _needsTunnelHeaders(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) {
    return false;
  }
  return uri.host == Uri.parse(AppConfig.apiBaseUrl).host ||
      _isLegacyTunnelHost(uri.host);
}

/// Image distante avec placeholder et fallback d'erreur.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    this.url,
    this.fit = BoxFit.cover,
    this.icon = Icons.image,
    this.iconColor,
    this.iconBackground,
    this.borderRadius,
    this.fallback,
  });

  final String? url;
  final BoxFit fit;
  final IconData icon;
  final Color? iconColor;
  final Color? iconBackground;
  final BorderRadius? borderRadius;

  /// Rendu personnalisé quand l'URL est absente ou ne charge pas.
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final resolved = _resolve(url);
    if (resolved == null || resolved.isEmpty) {
      final placeholder = fallback ?? _fallback(context);
      if (borderRadius == null) return placeholder;
      return ClipRRect(borderRadius: borderRadius!, child: placeholder);
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: SizedBox.expand(
        child: Image.network(
          resolved,
          headers: _needsTunnelHeaders(resolved)
              ? AppConfig.tunnelHeaders
              : null,
          fit: fit,
          errorBuilder: (_, _, _) => fallback ?? _fallback(context),
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
        ),
      ),
    );
  }

  String? _resolve(String? source) => resolveMediaUrl(source);

  Widget _fallback(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: iconBackground ?? Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius ?? BorderRadius.zero,
      ),
      child: Icon(icon, size: 28, color: iconColor ?? Theme.of(context).colorScheme.outline),
    );
  }
}