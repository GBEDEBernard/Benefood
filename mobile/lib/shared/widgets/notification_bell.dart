import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/data/marketplace_api.dart';
import '../../core/navigation/notification_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/formatters.dart';
import 'notification_detail_sheet.dart';

/// Anti-doublon des bandeaux : plusieurs cloches peuvent être montées en même
/// temps (onglets d'un même shell). La première qui détecte l'arrivée affiche
/// le bandeau, les suivantes l'ignorent.
class _AnnouncedNotifications {
  static const _window = Duration(minutes: 2);

  static String? _lastId;
  static DateTime? _lastAt;

  static bool shouldAnnounce(String id) {
    final lastAt = _lastAt;
    final already =
        _lastId == id &&
        lastAt != null &&
        DateTime.now().difference(lastAt) < _window;
    if (already) {
      return false;
    }
    _lastId = id;
    _lastAt = DateTime.now();
    return true;
  }
}

/// Cloche de notification partagée : pastille = nombre de notifications
/// non lues (GET /me/stats), ouverture = feuille des notifications réelles.
///
/// [audience] indique l'espace courant : les notifications ouvertes depuis la
/// cloche mènent alors au détail de l'espace correspondant (suivi client,
/// commande vendeur, mission livreur).
class NotificationBell extends StatefulWidget {
  const NotificationBell({
    super.key,
    required this.api,
    this.audience = NotificationAudience.client,
  });

  final MarketplaceApi api;
  final NotificationAudience audience;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 30);

  int? _unread;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUnread();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _loadUnread());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Une notification peut être arrivée pendant que l'app était en veille : on
  /// relit le compteur dès le retour au premier plan.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUnread();
    }
  }

  Future<void> _loadUnread() async {
    try {
      final stats = await widget.api.meStats();
      if (!mounted) {
        return;
      }
      final unread = (stats['unread_notifications'] as num?)?.toInt() ?? 0;
      final previous = _unread;
      if (unread != previous) {
        setState(() => _unread = unread);
      }
      // Le compteur monte pendant la session : une notification vient
      // d'arriver, on la signale tout de suite par un bandeau cliquable.
      if (previous != null && unread > previous) {
        await _announceLatest();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _unread = null);
    }
  }

  /// Bandeau « nouvelle notification » : titre + message, avec une action qui
  /// ouvre le contenu complet (même feuille que la cloche).
  Future<void> _announceLatest() async {
    final List<Map<String, dynamic>> items;
    try {
      items = await widget.api.myNotifications();
    } catch (_) {
      return;
    }
    if (!mounted || items.isEmpty) {
      return;
    }

    final latest = items.firstWhere(
      (item) => item['read_at'] == null,
      orElse: () => items.first,
    );
    final id = latest['id'] is String ? latest['id'] as String : '';
    if (id.isEmpty || !_AnnouncedNotifications.shouldAnnounce(id)) {
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }

    final title = latest['title'] is String
        ? latest['title'] as String
        : 'Nouvelle notification';
    final body = latest['body'] is String ? latest['body'] as String : '';

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.text,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.surface,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (body.isNotEmpty)
              Text(
                body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.surface,
                  fontSize: 12.5,
                ),
              ),
          ],
        ),
        action: SnackBarAction(
          label: 'Voir',
          textColor: AppColors.orangeLight,
          onPressed: () {
            // Le bandeau survit à la cloche : on n'ouvre la feuille que si
            // l'état est toujours monté (sinon le contexte est désactivé).
            if (!mounted) {
              return;
            }
            showNotificationDetail(
              context,
              item: latest,
              marketplace: widget.api,
              audience: widget.audience,
            );
          },
        ),
      ),
    );
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
      builder: (_) =>
          _NotificationsSheet(api: widget.api, audience: widget.audience),
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
  // `_openItem` : marquer lu puis ouvrir le contenu complet.
  const _NotificationsSheet({required this.api, required this.audience});

  final MarketplaceApi api;
  final NotificationAudience audience;

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

  /// Marque lue puis ouvre le détail complet de la notification.
  Future<void> _openItem(BuildContext context, Map<String, dynamic> item) async {
    final id = item['id'];
    if (_isUnread(item) && id is String) {
      setState(() => item['read_at'] = DateTime.now().toIso8601String());
      try {
        await widget.api.markNotificationRead(id);
      } catch (_) {
        // Le retour visuel (pastille) prime : l'échec réseau reste muet.
      }
    }
    if (!context.mounted) {
      return;
    }
    await showNotificationDetail(
      context,
      item: item,
      marketplace: widget.api,
      audience: widget.audience,
    );
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
                }                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => 
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) { 
                    final item = items[index];
                    return _NotificationTile(
                      item: item,
                      onTap: () => _openItem(context, item),
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
          notificationIcon(type),
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
