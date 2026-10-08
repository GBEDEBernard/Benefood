import 'package:flutter/material.dart';

import '../../../../core/data/marketplace_api.dart';
import '../../../../shared/models/vendor.dart';
import '../restaurant_palette.dart';
import '../widgets/status_chip.dart';
import 'shop_address_edit_screen.dart';
import 'shop_hours_edit_screen.dart';
import 'shop_info_edit_screen.dart';

/// Écran « Ma boutique » (mobile) : carte de profil et réglages entièrement
/// éditables. Les valeurs arrivent de l'API ; chaque réglage ouvre un
/// formulaire dédié qui soumet proprement les changements.
class ShopScreen extends StatelessWidget {
  const ShopScreen({
    super.key,
    required this.onBack,
    required this.isOpen,
    required this.onToggleOpen,
    this.vendor,
    this.hours = const [],
    this.statusLabel = 'Actif',
    this.marketplace,
    this.onDataChanged,
  });

  final VoidCallback onBack;
  final bool isOpen;
  final ValueChanged<bool> onToggleOpen;
  final Vendor? vendor;
  final List<OpeningHour> hours;
  final String statusLabel;
  final MarketplaceApi? marketplace;

  /// À rappeler après un enregistrement pour recharger les données.
  final VoidCallback? onDataChanged;

  Vendor get _vendor => vendor ??
      const Vendor(
        id: '',
        businessName: 'Le Délice Fast-Food',
        status: 'active',
        description: 'Fast-food et cuisine locale livrée à domicile.',
        city: 'Cadjèhoun, Cotonou',
      );

  Future<void> _openEditor(BuildContext context, Widget screen) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (context) => screen),
    );
    if (changed == true) {
      onDataChanged?.call();
    }
  }

  List<OpeningHour> get _hours => hours;

  String get _todaySummary {
    final list = _hours;
    if (list.isEmpty) {
      return 'Horaires non définis';
    }
    final todayIndex = DateTime.now().weekday - 1;
    OpeningHour? today;
    for (final h in list) {
      if (h.dayOfWeek == todayIndex) {
        today = h;
        break;
      }
    }
    if (today == null) {
      return 'Horaires non définis';
    }
    if (today.isClosed) {
      return 'Fermé aujourd’hui';
    }
    final openAt = today.opensAt ?? '--:--';
    final closeAt = today.closesAt ?? '--:--';
    return 'Aujourd’hui : $openAt – $closeAt';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildProfileCard(context),
              const SizedBox(height: 24),
              const _SettingsTitle('Horaires'),
              const SizedBox(height: 8),
              _buildHoursCard(context),
              const SizedBox(height: 24),
              const _SettingsTitle('Réglages'),
              const SizedBox(height: 10),
              _buildSettingsList(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Material(
      color: RestaurantPalette.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, color: RestaurantPalette.darkText),
                  tooltip: 'Retour',
                ),
              ),
              const Text(
                'Ma boutique',
                style: TextStyle(
                  color: RestaurantPalette.darkText,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => _openEditor(
                    context,
                    ShopInfoEditScreen(vendor: _vendor, marketplace: marketplace),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: RestaurantPalette.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Modifier', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final v = _vendor;
    final hasDescription = v.description != null && v.description!.trim().isNotEmpty;
    final hasCity = v.city != null && v.city!.trim().isNotEmpty;
    final hasAddress = v.address != null && v.address!.trim().isNotEmpty;
    final hasPhone = v.phone != null && v.phone!.trim().isNotEmpty;
    final hasEmail = v.email != null && v.email!.trim().isNotEmpty;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: RestaurantPalette.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: 140,
                width: double.infinity,
                child: _CoverImage(url: v.coverUrl),
              ),
              if (v.logoUrl != null && v.logoUrl!.trim().isNotEmpty)
                Positioned(
                  left: 16,
                  bottom: -26,
                  child: _LogoCircle(url: v.logoUrl!),
                ),
            ],
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, (v.logoUrl != null && v.logoUrl!.trim().isNotEmpty) ? 40 : 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        v.businessName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: RestaurantPalette.darkText,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(
                      label: isOpen ? 'Ouvert' : 'Fermé',
                      background: (isOpen ? RestaurantPalette.success : RestaurantPalette.danger)
                          .withValues(alpha: 0.15),
                      foreground: isOpen ? RestaurantPalette.success : RestaurantPalette.danger,
                    ),
                  ],
                ),
                if (hasDescription) ...[
                  const SizedBox(height: 8),
                  Text(
                    v.description!,
                    style: const TextStyle(color: RestaurantPalette.grayText, fontSize: 13, height: 1.4),
                  ),
                ],
                const SizedBox(height: 12),
                _InfoLine(
                  icon: Icons.place_outlined,
                  text: [
                    if (hasCity) v.city!,
                    if (hasAddress) v.address!,
                  ].join(' · '),
                ),
                if (hasPhone) ...[
                  const SizedBox(height: 6),
                  _InfoLine(icon: Icons.phone_outlined, text: v.phone!),
                ],
                if (hasEmail) ...[
                  const SizedBox(height: 6),
                  _InfoLine(icon: Icons.mail_outline, text: v.email!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoursCard(BuildContext context) {
    final rows = _weekRows();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: RestaurantPalette.cardDecoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(RestaurantPalette.radius),
          onTap: () => _openEditor(context, ShopHoursEditScreen(hours: _hours, marketplace: marketplace)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule_outlined, color: RestaurantPalette.orange, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _todaySummary,
                        style: const TextStyle(
                          color: RestaurantPalette.darkText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                  ],
                ),
                if (rows.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF1F1F1)),
                  const SizedBox(height: 4),
                  for (final row in rows) _WeekLine(day: row.$1, hour: row.$2, isToday: row.$3),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// (nom du jour, résumé horaire, est-ce aujourd'hui) pour les 7 jours.
  List<(String, String, bool)> _weekRows() {
    const dayNames = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    final list = [..._hours]..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
    final todayIndex = DateTime.now().weekday - 1;
    return [
      for (final h in list)
        if (h.dayOfWeek >= 0 && h.dayOfWeek < dayNames.length)
          (
            dayNames[h.dayOfWeek],
            h.isClosed || h.opensAt == null ? 'Fermé' : '${h.opensAt} – ${h.closesAt ?? '--:--'}',
            h.dayOfWeek == todayIndex,
          ),
    ];
  }

  Widget _buildSettingsList(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: RestaurantPalette.cardDecoration,
      child: Column(
        children: [
          _SettingTile(
            icon: Icons.info_outline,
            label: 'Informations',
            subtitle: _vendor.businessName,
            onTap: () => _openEditor(context, ShopInfoEditScreen(vendor: _vendor, marketplace: marketplace)),
          ),
          const _SettingDivider(),
          _SettingTile(
            icon: Icons.map_outlined,
            label: 'Adresse',
            subtitle: _vendor.city ?? 'Définir la ville',
            onTap: () => _openEditor(context, ShopAddressEditScreen(vendor: _vendor, marketplace: marketplace)),
          ),
          const _SettingDivider(),
          _SettingTile(
            icon: Icons.schedule_outlined,
            label: 'Horaires d’ouverture',
            subtitle: '$_hourCount j ouverts par semaine',
            onTap: () => _openEditor(context, ShopHoursEditScreen(hours: _hours, marketplace: marketplace)),
          ),
          const _SettingDivider(),
          _SettingTile(
            icon: Icons.storefront_outlined,
            label: 'Statut de la boutique',
            trailing: Switch.adaptive(
              value: isOpen,
              activeTrackColor: RestaurantPalette.success,
              onChanged: onToggleOpen,
            ),
          ),
          const _SettingDivider(),
          _SettingTile(
            icon: Icons.verified_user_outlined,
            label: 'Statut du compte',
            trailing: StatusChip(
              label: statusLabel,
              background: RestaurantPalette.success.withValues(alpha: 0.15),
              foreground: RestaurantPalette.success,
            ),
          ),
        ],
      ),
    );
  }

  int get _hourCount {
    if (_hours.isEmpty) {
      return 7;
    }
    return _hours.where((h) => !h.isClosed).length;
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.trim().isNotEmpty) {
      return Image.network(
        url!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _CoverFallback(),
      );
    }
    return const _CoverFallback();
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [RestaurantPalette.forest, Color(0xFF134E2E)],
        ),
      ),
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Icon(Icons.storefront, size: 56, color: Color(0x22FFFFFF)),
        ),
      ),
    );
  }
}

class _LogoCircle extends StatelessWidget {
  const _LogoCircle({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: ClipOval(
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => ColoredBox(
            color: RestaurantPalette.orange,
            child: Icon(Icons.storefront, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: RestaurantPalette.grayText, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: RestaurantPalette.grayText, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

/// Ligne horaire « Lundi · 08:00 – 22:00 » (surlignée si c'est aujourd'hui).
class _WeekLine extends StatelessWidget {
  const _WeekLine({required this.day, required this.hour, required this.isToday});

  final String day;
  final String hour;
  final bool isToday;

  bool get _closed => hour == 'Fermé';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              day,
              style: TextStyle(
                color: isToday ? RestaurantPalette.orange : RestaurantPalette.darkText,
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              hour,
              style: TextStyle(
                color: _closed ? RestaurantPalette.danger : RestaurantPalette.grayText,
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (isToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: RestaurantPalette.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Aujourd’hui',
                style: TextStyle(
                  color: RestaurantPalette.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsTitle extends StatelessWidget {
  const _SettingsTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: RestaurantPalette.grayText,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: RestaurantPalette.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: RestaurantPalette.orange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: RestaurantPalette.darkText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: RestaurantPalette.grayText, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

class _SettingDivider extends StatelessWidget {
  const _SettingDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, indent: 64, color: Color(0xFFF1F1F1));
  }
}