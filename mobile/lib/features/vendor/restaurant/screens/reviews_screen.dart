import 'package:flutter/material.dart';

import '../../../../core/data/marketplace_api.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/state_widgets.dart';
import '../restaurant_palette.dart';
import '../widgets/vendor_screen_header.dart';

/// Mes avis clients (J21 §9) : note moyenne, répartition des notes,
/// commentaires et réponse du vendeur.
class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key, this.marketplace, this.onOpenDrawer});

  final MarketplaceApi? marketplace;
  final VoidCallback? onOpenDrawer;

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  double _average = 0;
  int _total = 0;
  List<int> _distribution = List.filled(5, 0);
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;
  String? _error;
  String? _replyingId;

  bool get _demoMode => widget.marketplace == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_demoMode) {
      final demo = _demoData();
      setState(() {
        _apply(demo);
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.marketplace!.vendorReviews(perPage: 50);
      if (mounted) {
        setState(() {
          _apply(data);
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  void _apply(Map<String, dynamic> data) {
    final summary = data['summary'];
    if (summary is Map<String, dynamic>) {
      _average = (summary['average'] as num?)?.toDouble() ?? 0;
      _total = (summary['total'] as num?)?.toInt() ?? 0;
      final distribution = summary['distribution'];
      if (distribution is Map) {
        _distribution = List.generate(5, (i) => (distribution['${i + 1}'] as num?)?.toInt() ?? 0);
      }
    }
    final reviews = data['reviews'];
    _reviews = reviews is List ? reviews.whereType<Map<String, dynamic>>().toList() : [];
  }

  Future<void> _reply(Map<String, dynamic> review) async {
    final id = review['id'] as String?;
    if (id == null || _demoMode) {
      if (_demoMode) {
        showToast(context, 'Réponse indisponible en démonstration.');
      }
      return;
    }
    final controller = TextEditingController(text: review['vendor_reply'] as String? ?? '');
    final reply = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Répondre à l\'avis'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 1000,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Votre réponse au client...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) {
                return;
              }
              Navigator.pop(context, value);
            },
            style: FilledButton.styleFrom(backgroundColor: RestaurantPalette.orange),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
    if (reply == null || reply.isEmpty || !mounted) {
      return;
    }
    setState(() => _replyingId = id);
    try {
      final updated = await widget.marketplace!.replyToReview(id, reply);
      if (!mounted) {
        return;
      }
      setState(() {
        final index = _reviews.indexWhere((r) => r['id'] == id);
        if (index >= 0) {
          _reviews[index] = {..._reviews[index], ...updated};
        }
      });
      showToast(context, 'Réponse publiée.');
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _replyingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RestaurantPalette.background,
      child: Column(
        children: [
          VendorScreenHeader(title: 'MES AVIS CLIENTS', onOpenDrawer: widget.onOpenDrawer),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && !_demoMode) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _SummaryCard(average: _average, total: _total, distribution: _distribution),
          const SizedBox(height: 16),
          if (_reviews.isEmpty)
            const EmptyState(
              icon: Icons.reviews_outlined,
              title: 'Aucun avis',
              subtitle: 'Les avis de vos clients s\'afficheront ici après leurs commandes.',
            )
          else
            for (final review in _reviews)
              _ReviewCard(
                review: review,
                replying: _replyingId == review['id'],
                onReply: () => _reply(review),
              ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.average, required this.total, required this.distribution});

  final double average;
  final int total;
  final List<int> distribution;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: RestaurantPalette.cardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                average.toStringAsFixed(1).replaceFirst('.', ','),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: RestaurantPalette.darkText,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              _Stars(rating: average),
              const SizedBox(height: 4),
              Text(
                '$total avis',
                style: const TextStyle(fontSize: 12, color: RestaurantPalette.grayText),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [
                for (var star = 5; star >= 1; star--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 10,
                          child: Text('$star', style: const TextStyle(fontSize: 12, color: RestaurantPalette.grayText)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: total == 0 ? 0 : distribution[star - 1] / total,
                              minHeight: 6,
                              backgroundColor: RestaurantPalette.borderColor,
                              valueColor: const AlwaysStoppedAnimation(Color(0xFFFBBF24)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 22,
                          child: Text(
                            '${distribution[star - 1]}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 11, color: RestaurantPalette.grayText),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating, this.size = 16});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i ? Icons.star_rounded : Icons.star_border_rounded,
            size: size,
            color: const Color(0xFFFBBF24),
          ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.replying, required this.onReply});

  final Map<String, dynamic> review;
  final bool replying;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final name = review['customer_name'] as String? ?? 'Client';
    final comment = review['comment'] as String? ?? '';
    final rating = (review['rating'] as num?)?.toDouble() ?? 0;
    final reply = review['vendor_reply'] as String?;
    final reference = review['order_reference'] as String?;
    final products = review['products'];
    final productNames = products is List
        ? products.whereType<Map<String, dynamic>>().map((p) => p['name']).whereType<String>().join(', ')
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: RestaurantPalette.cardSpacing),
      padding: const EdgeInsets.all(14),
      decoration: RestaurantPalette.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: RestaurantPalette.orange.withValues(alpha: 0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: RestaurantPalette.orange,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: RestaurantPalette.darkText,
                      ),
                    ),
                    if (reference != null && reference.isNotEmpty)
                      Text(
                        'Commande $reference',
                        style: const TextStyle(fontSize: 11.5, color: RestaurantPalette.grayText),
                      ),
                  ],
                ),
              ),
              Text(
                formatDate(review['created_at'] as String?),
                style: const TextStyle(fontSize: 11, color: RestaurantPalette.grayText),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Stars(rating: rating, size: 15),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              comment,
              style: const TextStyle(fontSize: 13.5, color: RestaurantPalette.darkText, height: 1.4),
            ),
          ],
          if (productNames.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              productNames,
              style: const TextStyle(fontSize: 12, color: RestaurantPalette.grayText),
            ),
          ],
          const SizedBox(height: 10),
          if (reply != null && reply.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: RestaurantPalette.forest.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: RestaurantPalette.forest.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Votre réponse',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: RestaurantPalette.forest,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    reply,
                    style: const TextStyle(fontSize: 13, color: RestaurantPalette.darkText, height: 1.35),
                  ),
                ],
              ),
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: replying ? null : onReply,
                icon: replying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.reply_outlined, size: 18),
                label: const Text('Répondre'),
                style: TextButton.styleFrom(foregroundColor: RestaurantPalette.orange),
              ),
            ),
        ],
      ),
    );
  }
}

Map<String, dynamic> _demoData() => {
      'summary': {
        'average': 4.5,
        'total': 24,
        'distribution': {'1': 1, '2': 1, '3': 3, '4': 7, '5': 12},
      },
      'reviews': [
        {
          'id': 'demo-r1',
          'rating': 5,
          'comment': 'Très bon, livraison rapide et plats bien chauds !',
          'customer_name': 'Ulrich Hounkpe',
          'order_reference': '#BF1250',
          'products': [
            {'name': 'Burger Délice'},
          ],
          'vendor_reply': 'Merci beaucoup pour votre retour !',
          'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        },
        {
          'id': 'demo-r2',
          'rating': 3,
          'comment': 'Correct mais un peu d\'attente sur la préparation.',
          'customer_name': 'Aïcha Sossou',
          'order_reference': '#BF1248',
          'products': [
            {'name': 'Attiéké poisson'},
          ],
          'vendor_reply': null,
          'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        },
        {
          'id': 'demo-r3',
          'rating': 5,
          'comment': 'Je recommande, les frites sont excellentes.',
          'customer_name': 'Koffi Adjovi',
          'order_reference': '#BF1244',
          'products': [
            {'name': 'Frites (M)'},
          ],
          'vendor_reply': null,
          'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
        },
      ],
    };
