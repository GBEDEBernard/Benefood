import 'package:flutter/material.dart';

import '../../core/data/marketplace_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/formatters.dart';

/// Cloche de notification partagée : pastille = nombre de notifications
/// non lues (GET /me/stats), ouverture = feuille des notifications réelles.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, required this.api});

  final MarketplaceApi api;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int? _unread;

  @override
  void initState() {
    super.initState();
    _loadUnread();
  }

  Future<void> _loadUnread() async {
    try {
      final stats = await widget.api.meStats();
      if (!mounted) {
        return;
      }
      setState(() {
        _unread = (stats['unread_notifications'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _unread = null);
    }
  }

  Future<void> _openSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusXl),
        ),
      ),
      builder: (_) => _NotificationsSheet(api: widget.api),
    );
    if (mounted) {
      await _loadUnread();
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _unread;
    final showBadge = unread != null && unread > 0;
    final label = unread != null && unread > 9 ? '9+' : '${unread ?? 0}';

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          IconButton(
            onPressed: _openSheet,
            tooltip: 'Notifications',
            icon: const Icon(
              Icons.notifications_none,
              size: 26,
              color: AppColors.text,
            ),
          ),
          if (showBadge)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.surface,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Feuille des notifications : liste réelle (GET /me/notifications),
/// marquage lu à l'ouverture d'un élément et « Tout lire » groupé.
class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet({required this.api});

  final MarketplaceApi api;

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.myNotifications();
  }

  bool _isUnread(Map<String, dynamic> item) => item['read_at'] == null;

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (!_isUnread(item)) {
      return;
    }
    final id = item['id'];
    if (id is! String) {
      return;
    }
    setState(() => item['read_at'] = DateTime.now().toIso8601String());
    try {
      await widget.api.markNotificationRead(id);
    } catch (_) {
      // Le retour visuel (pastille) prime : l'échec réseau reste muet.
    }
  }

  Future<void> _markAllRead() async {
    try {
      await widget.api.markAllNotificationsRead();
      if (mounted) {
        final next = widget.api.myNotifications();
        setState(() {
          _future = next;
        });
      }
    } catch (_) {
      // Idem : pas de blocage de l'interface sur erreur réseau.
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Notifications',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: _markAllRead,
                  child: const Text('Tout lire'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Impossible de charger les notifications.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }
                final items = snapshot.data ?? const [];
                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 40,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Aucune notification pour le moment.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _NotificationTile(
                      item: item,
                      onTap: () => _markRead(item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

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
    final type = item['type'] is String ? item['type'] as String : '';
    final title = item['title'] is String ? item['title'] as String : '';
    final body = item['body'] is String ? item['body'] as String : '';
    final createdAt = item['created_at'] is String
        ? item['created_at'] as String
        : null;
    final unread = item['read_at'] == null;

    return ListTile(
      onTap: onTap,
      tileColor: unread ? AppColors.orangeLight.withValues(alpha: 0.35) : null,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: unread ? AppColors.orangeLight : AppColors.greenLight,
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
  }
}
