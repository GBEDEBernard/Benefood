import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/feedback_widgets.dart';

/// Coupons du client : liste réelle (GET /me/coupons), copie du code.
class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key, required this.marketplace});

  final MarketplaceApi marketplace;

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.marketplace.myCoupons();
  }

  void _reload() {
    final next = widget.marketplace.myCoupons();
    setState(() {
      _future = next;
    });
  }

  Future<void> _copyCode(Map<String, dynamic> item) async {
    final code = item['code'];
    if (code is! String || code.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      showToast(context, 'Code $code copié');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Mes coupons')),
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
                      'Impossible de charger vos coupons.',
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
                      Icons.confirmation_number_outlined,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Aucun coupon pour le moment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Vos codes promo apparaîtront ici.',
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
            padding: const EdgeInsets.all(AppDimens.pagePadding),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final code = item['code'] is String ? item['code'] as String : '';
              final label = item['label'] is String
                  ? item['label'] as String
                  : '';
              final discountType = item['discount_type'] is String
                  ? item['discount_type'] as String
                  : 'percent';
              final discountValue = item['discount_value'] is int
                  ? item['discount_value'] as int
                  : 0;
              final expiresAt = item['expires_at'] is String
                  ? item['expires_at'] as String
                  : null;
              final used = item['used_at'] != null;
              final available = item['is_available'] == true;

              final statusLabel = used
                  ? 'Utilisé'
                  : available
                  ? 'Disponible'
                  : 'Expiré';
              final statusColor = used
                  ? AppColors.textSecondary
                  : available
                  ? AppColors.green
                  : AppColors.orange;
              final statusTint = used
                  ? AppColors.background
                  : available
                  ? AppColors.greenLight
                  : AppColors.orangeLight;
              final discountLabel = discountType == 'fixed'
                  ? '${formatAmount(discountValue, showSymbol: false).trim()} FCFA'
                  : '$discountValue %';

              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                  boxShadow: AppTheme.softShadow(),
                ),
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: available ? () => _copyCode(item) : null,
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.lg),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.goldLight,
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusSm + 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.confirmation_number_outlined,
                              size: 24,
                              color: AppColors.goldDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(
                                          AppDimens.radiusSm,
                                        ),
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: Text(
                                        code,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        expiresAt != null
                                            ? 'Expire le ${formatDate(expiresAt)}'
                                            : 'Sans expiration',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                discountLabel,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.green,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusTint,
                                  borderRadius: BorderRadius.circular(
                                    AppDimens.radiusPill,
                                  ),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
