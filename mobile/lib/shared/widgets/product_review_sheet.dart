import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

class ProductReviewInput {
  const ProductReviewInput({required this.rating, this.comment});

  final int rating;
  final String? comment;
}

Future<ProductReviewInput?> showProductReviewSheet(
  BuildContext context, {
  required String productName,
}) {
  return showModalBottomSheet<ProductReviewInput>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimens.radiusXl),
      ),
    ),
    builder: (_) => _ProductReviewSheet(productName: productName),
  );
}

class _ProductReviewSheet extends StatefulWidget {
  const _ProductReviewSheet({required this.productName});

  final String productName;

  @override
  State<_ProductReviewSheet> createState() => _ProductReviewSheetState();
}

class _ProductReviewSheetState extends State<_ProductReviewSheet> {
  final TextEditingController _comment = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Noter « ${widget.productName} »',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Votre avis aide les autres clients à choisir.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(
                    i <= _rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: AppColors.gold,
                    size: 36,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _comment,
            maxLines: 3,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Votre commentaire (optionnel)',
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: AppDimens.buttonHeight,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(
                ProductReviewInput(
                  rating: _rating,
                  comment: _comment.text.trim(),
                ),
              ),
              child: const Text(
                'Envoyer mon avis',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
