import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/geo.dart';
import '../models/driver_selection.dart';
import 'app_network_image.dart';

/// Liste de livreurs proches réutilisée au checkout et lors d'un remplacement.
Future<NearbyDriver?> showDriverPickerSheet(
  BuildContext context, {
  required List<NearbyDriver> drivers,
  String? selectedId,
  String title = 'Choisir un livreur',
  String subtitle =
      'Les frais d’approche dépendent de la distance entre le livreur et la boutique. Ils sont inclus dans le total.',
}) {
  return showModalBottomSheet<NearbyDriver>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DriverPickerSheet(
      drivers: drivers,
      selectedId: selectedId,
      title: title,
      subtitle: subtitle,
    ),
  );
}

class _DriverPickerSheet extends StatelessWidget {
  const _DriverPickerSheet({
    required this.drivers,
    required this.title,
    required this.subtitle,
    this.selectedId,
  });

  final List<NearbyDriver> drivers;
  final String title;
  final String subtitle;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.82,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: drivers.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final driver = drivers[index];
                  final selected = driver.id == selectedId;
                  final details = [
                    if (driver.rating != null)
                      driver.rating!.toStringAsFixed(1),
                    if (driver.vehicle != null && driver.vehicle!.isNotEmpty)
                      driver.vehicle!,
                    'À ${formatDistance(driver.distanceToPickupKm)}',
                    if (driver.etaToPickupSeconds != null)
                      '~${formatEta((driver.etaToPickupSeconds! / 60).ceil())}',
                  ].join(' · ');

                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(driver),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? AppColors.orange
                                : AppColors.border,
                            width: selected ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: AppNetworkImage(
                                url: driver.avatarUrl,
                                borderRadius: BorderRadius.circular(14),
                                icon: Icons.two_wheeler,
                                iconBackground: AppColors.orangeLight,
                                iconColor: AppColors.orangeDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    driver.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    details,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  driver.approachFee == null
                                      ? '—'
                                      : formatAmount(driver.approachFee!),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.orangeDark,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'approche',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.textFaint,
                                  ),
                                ),
                              ],
                            ),
                            if (selected) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.check_circle,
                                color: AppColors.green,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
