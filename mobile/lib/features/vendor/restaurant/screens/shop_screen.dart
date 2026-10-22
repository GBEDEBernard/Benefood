import 'package:flutter/material.dart';

import '../../../../core/data/marketplace_api.dart';
import '../../../../core/navigation/notification_router.dart';
import '../../../../shared/widgets/notification_bell.dart';
import '../../../../shared/models/vendor.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../../shared/widgets/food_decor.dart';

import '../restaurant_palette.dart';
import '../widgets/status_chip.dart';
import 'shop_address_edit_screen.dart';
import 'shop_hours_edit_screen.dart';
import 'shop_info_edit_screen.dart';
import 'shop_zones_edit_screen.dart';

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
    this.onHoursChanged,
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

  /// Remonte la nouvelle semaine d'horaires pour un affichage immédiat.
  final ValueChanged<List<OpeningHour>>? onHoursChanged;

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

  Future<void> _openHoursEditor(BuildContext context) async {
    final hours = await Navigator.of(context).push<List<OpeningHour>>(
      MaterialPageRoute<List<OpeningHour>>(
        builder: (context) => ShopHoursEditScreen(
          hours: _hours,
          marketplace: marketplace,
        ),
      ),
    );
    if (hours == null || hours.isEmpty) {
      return;
    }
    onHoursChanged?.call(hours);
    onDataChanged?.call();
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
          padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, color: RestaurantPalette.darkText),
                tooltip: 'Retour',
              ),
              const Expanded(
                child: Text(
                  'Ma boutique',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: RestaurantPalette.darkText,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (marketplace != null) ...[
                NotificationBell(
                  api: marketplace!,
                  audience: NotificationAudience.vendor,
                ),
                const SizedBox(width: 4),
              ],
              FilledButton.icon(
                onPressed: () => _openEditor(
                  context,
                  ShopInfoEditScreen(
                    vendor: _vendor,
                    marketplace: marketplace,
                  ),
                ),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Modifier'),
                style: FilledButton.styleFrom(
                  backgroundColor: RestaurantPalette.orange,
                  foregroundColor: RestaurantPalette.white,
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
          _ProfileCover(
            url: v.coverUrl,
            logoUrl: v.logoUrl,
          ),
          _ProfileBody(
            businessName: v.businessName,
            hasLogo: v.logoUrl != null && v.logoUrl!.trim().isNotEmpty,
            isOpen: isOpen,
            hasDescription: hasDescription,
            description: v.description,
            hasCity: hasCity,
            city: v.city,
            hasAddress: hasAddress,
            address: v.address,
            hasPhone: hasPhone,
            phone: v.phone,
            hasEmail: hasEmail,
            email: v.email,
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
          onTap: () => _openHoursEditor(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HoursCardHeader(
                  todaySummary: _todaySummary,
                  onEdit: () => _openHoursEditor(context),
                ),
                if (rows.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF1F1F1)),
                  const SizedBox(height: 6),
                  for (final row in rows)
                    _WeekLine(
                      day: row.name,
                      hour: row.hour,
                      isToday: row.isToday,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
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
            subtitle: '$_hourCount jours ouverts par semaine',
            onTap: () => _openHoursEditor(context),
          ),
          const _SettingDivider(),
          _SettingTile(
            icon: Icons.location_city_outlined,
            label: 'Zones desservies',
            subtitle: 'Définir les quartiers livrés',
            onTap: () => _openEditor(context, ShopZonesEditScreen(marketplace: marketplace)),
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

  List<_DaySummary> _weekRows() {
    const dayNames = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    final list = [..._hours]..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
    final todayIndex = DateTime.now().weekday - 1;
    return [
      for (final h in list)
        if (h.dayOfWeek >= 0 && h.dayOfWeek < dayNames.length)
          _DaySummary(
            name: dayNames[h.dayOfWeek],
            hour: h.isClosed || h.opensAt == null
                ? 'Fermé'
                : '${h.opensAt} \u2013 ${h.closesAt ?? '--:--'}',
            isToday: h.dayOfWeek == todayIndex,
          ),
    ];
  }
}

class _DaySummary {
  const _DaySummary({required this.name, required this.hour, required this.isToday});

  final String name;
  final String hour;
  final bool isToday;
}

class _ProfileCover extends StatelessWidget {
  const _ProfileCover({this.url, this.logoUrl});

  final String? url;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.trim().isNotEmpty;
    return SizedBox(
      height: 150,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: _CoverImage(url: url)),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.5, 1],
                    colors: [
                      Colors.transparent,
                      RestaurantPalette.forest.withValues(alpha: 0.45),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (hasLogo)
            Positioned(
              left: 16,
              bottom: -30,
              child: _LogoCircle(url: logoUrl!),
            ),
        ],
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.businessName,
    required this.hasLogo,
    required this.isOpen,
    required this.hasDescription,
    required this.description,
    required this.hasCity,
    required this.city,
    required this.hasAddress,
    required this.address,
    required this.hasPhone,
    required this.phone,
    required this.hasEmail,
    required this.email,
  });

  final String businessName;
  final bool hasLogo;
  final bool isOpen;
  final bool hasDescription;
  final String? description;
  final bool hasCity;
  final String? city;
  final bool hasAddress;
  final String? address;
  final bool hasPhone;
  final String? phone;
  final bool hasEmail;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final location = [
      if (hasCity) city!,
      if (hasAddress) address!,
    ].join(' · ');
    final hasContact = location.isNotEmpty || hasPhone || hasEmail;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, hasLogo ? 44 : 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  businessName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RestaurantPalette.darkText,
                    fontSize: 21,
                    height: 1.15,
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
              description!,
              style: const TextStyle(
                color: RestaurantPalette.grayText,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
          if (hasContact) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 12),
            if (location.isNotEmpty)
              _InfoLine(icon: Icons.place_outlined, text: location),
            if (hasPhone) ...[
              const SizedBox(height: 8),
              _InfoLine(icon: Icons.phone_outlined, text: phone!),
            ],
            if (hasEmail) ...[
              const SizedBox(height: 8),
              _InfoLine(icon: Icons.mail_outline, text: email!),
            ],
          ],
        ],
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.trim().isNotEmpty) {
      return Image.network(
        resolveMediaUrl(url!)!,
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
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [RestaurantPalette.forest, Color(0xFF14532D)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const FoodDecor(
            bowlWidth: 168,
            herbsWidth: 124,
            bowlRight: -20,
            bowlBottom: -34,
            herbsRight: -12,
            herbsTop: -30,
            bowlOpacity: 0.34,
            herbsOpacity: 0.26,
          ),
          Align(
            alignment: Alignment.center,
            child: Icon(
              Icons.storefront_rounded,
              size: 58,
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
        ],
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
      width: 68,
      height: 68,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: RestaurantPalette.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          resolveMediaUrl(url)!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const ColoredBox(
            color: RestaurantPalette.orange,
            child: Icon(Icons.storefront, color: Colors.white, size: 32),
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
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: RestaurantPalette.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: RestaurantPalette.grayText, size: 15),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              text,
              style: const TextStyle(
                color: RestaurantPalette.grayText,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HoursCardHeader extends StatelessWidget {
  const _HoursCardHeader({required this.todaySummary, this.onEdit});

  final String todaySummary;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: RestaurantPalette.orange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.schedule_rounded,
            color: RestaurantPalette.orange,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cette semaine',
                style: TextStyle(
                  color: RestaurantPalette.darkText,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                todaySummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: RestaurantPalette.grayText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (onEdit != null) ...[
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
        ],
      ],
    );
  }
}

class _WeekLine extends StatelessWidget {
  const _WeekLine({required this.day, required this.hour, required this.isToday});

  final String day;
  final String hour;
  final bool isToday;

  bool get _closed => hour == 'Fermé';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: isToday ? RestaurantPalette.orange : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(
            width: 96,
            child: Text(
              day,
              maxLines: 2,
              style: TextStyle(
                color: isToday ? RestaurantPalette.darkText : RestaurantPalette.grayText,
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              hour,
              style: TextStyle(
                color: _closed ? RestaurantPalette.danger : RestaurantPalette.darkText,
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: RestaurantPalette.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
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
