import 'package:flutter/material.dart';

/// Image distante avec placeholder et fallback d'erreur.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({super.key, this.url, this.fit = BoxFit.cover, this.icon = Icons.image});

  final String? url;
  final BoxFit fit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return _fallback(context);
    }

    return Image.network(
      url!,
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

  Widget _fallback(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(icon, size: 28, color: Theme.of(context).colorScheme.outline),
    );
  }
}