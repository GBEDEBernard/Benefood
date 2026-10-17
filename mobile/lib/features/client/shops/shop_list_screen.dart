import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/models/vendor.dart';
import '../../../shared/widgets/beninfood_header.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/vendor_cards.dart';

/// Liste des boutiques ouvertes d'un type donné (Restaurant, Boutique, Maquis),
/// atteinte depuis les actions rapides de l'accueil.
class ShopListScreen extends StatefulWidget {
  const ShopListScreen({
    super.key,
    required this.marketplace,
    this.type,
  });

  final MarketplaceApi marketplace;

  /// Type de boutique filtré (null = tous types confondus).
  final VendorType? type;

  @override
  State<ShopListScreen> createState() => _ShopListScreenState();
}

class _ShopListScreenState extends State<ShopListScreen> {
  late Future<List<Vendor>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Vendor>> _load() {
    return widget.marketplace.vendors(
      type: widget.type,
      onlyOpen: true,
      perPage: 50,
    );
  }

  void _retry() {
    setState(() {
      _future = _load();
    });
  }

  String get _title => widget.type?.label ?? 'Boutiques';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          BeninfoodAppBar(
            onMenu: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/client');
              }
            },
            api: widget.marketplace,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              4,
              AppDimens.pagePadding,
              10,
            ),
            child: Row(
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.circle,
                  size: 8,
                  color: AppColors.green,
                ),
                const SizedBox(width: 5),
                const Text(
                  'Ouvertes maintenant',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.orange,
              onRefresh: () async {
                _retry();
                await _future;
              },
              child: FutureBuilder<List<Vendor>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const ListSkeleton();
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      children: [
                        SizedBox(
                          height: 360,
                          child: ErrorState(
                            message: snapshot.error is ApiException
                                ? (snapshot.error as ApiException).message
                                : 'Impossible de charger les boutiques.',
                            onRetry: _retry,
                          ),
                        ),
                      ],
                    );
                  }

                  final vendors = snapshot.data ?? const [];
                  if (vendors.isEmpty) {
                    return ListView(
                      children: [
                        SizedBox(
                          height: 360,
                          child: EmptyState(
                            icon: Icons.storefront_outlined,
                            title: 'Aucune boutique ouverte',
                            subtitle:
                                'Revenez plus tard, les $_title ouvrent bientôt.',
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.pagePadding,
                      4,
                      AppDimens.pagePadding,
                      32,
                    ),
                    itemCount: vendors.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final vendor = vendors[index];
                      return VendorListCard(
                        vendor: vendor,
                        onTap: () =>
                            context.push('/client/shop/${vendor.id}'),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
