import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/formatters.dart';

/// Liste des notifications du compte : réelle (GET /me/notifications),
/// marquage lu à l'ouverture d'un élément et « Tout lire » groupé.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.marketplace});

  final MarketplaceApi marketplace;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.marketplace.myNotifications();
  }

  void _reload() {
    final next = widget.marketplace.myNotifications();
    setState(() {
      _future = next;
    });
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['read_at'] != null || item['id'] is! String) {
      return;
    }
    final id = item['id'] as String;
    setState(() => item['read_at'] = DateTime.now().toIso8601String());
    try {
      await widget.marketplace.markNotificationRead(id);
    } catch (_) {
      // L'état local reste à jour même si le réseau échoue.
    }
  }

  Future<void> _markAllRead() async {
    try {
      await widget.marketplace.markAllNotificationsRead();
      _reload();
    } catch (_) {
      // Pas de blocage de l'interface sur erreur réseau.
    }
  }

  static IconData _iconFor(String type) {
    if (type.startsWith('order.')) {
      return Icons.receipt_long_outlined;
    }
    if (type.startsWith('complaint.')) {
      return Icons.support_agent;
    }
    if (type.startsWith('delivery.')) {
      return Icons.delivery_dining_outlined;
    }
    return Icons.notifications_none;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(onPressed: _markAllRead, child: const Text('Tout lire')),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Impossible de charger vos notifications.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: _reload,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Aucune notification pour le moment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Vous recevrez ici les alertes de commandes, '
                      'livraisons et remboursements.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
            itemCount: items.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, indent: 72, color: AppColors.border),
            itemBuilder: (context, index) {
              final item = items[index];
              final type = item['type'] is String ? item['type'] as String : '';
              final title = item['title'] is String
                  ? item['title'] as String
                  : '';
              final body = item['body'] is String ? item['body'] as String : '';
              final createdAt = item['created_at'] is String
                  ? item['created_at'] as String
                  : null;
              final unread = item['read_at'] == null;

              return ListTile(
                onTap: () => _markRead(item),
                tileColor: unread
                    ? AppColors.orangeLight.withValues(alpha: 0.35)
                    : null,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: unread
                        ? AppColors.orangeLight
                        : AppColors.greenLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _iconFor(type),
                    size: 20,
                    color: unread ? AppColors.orange : AppColors.green,
                  ),
                ),
                title: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (body.isNotEmpty)
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    if (createdAt != null)
                      Text(
                        formatDateTime(createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                trailing: unread
                    ? Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: AppColors.red,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
