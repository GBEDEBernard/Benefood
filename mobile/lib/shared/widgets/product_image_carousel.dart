import 'package:flutter/material.dart';

import 'app_network_image.dart';

/// Carrousel photo réutilisable dans les cartes produit.
/// Le balayage horizontal reste naturel; les indicateurs s'animent à chaque page.
class ProductImageCarousel extends StatefulWidget {
  const ProductImageCarousel({
    super.key,
    required this.imageUrls,
    this.height,
    this.placeholderIcon = Icons.fastfood_outlined,
    this.borderRadius = BorderRadius.zero,
    this.showCounter = true,
  });

  final List<String> imageUrls;
  final double? height;
  final IconData placeholderIcon;
  final BorderRadius borderRadius;
  final bool showCounter;

  @override
  State<ProductImageCarousel> createState() => _ProductImageCarouselState();
}

class _ProductImageCarouselState extends State<ProductImageCarousel> {
  late final PageController _controller = PageController();
  int _page = 0;

  List<String> get _images => widget.imageUrls.where((url) => url.isNotEmpty).toList();

  @override
  void didUpdateWidget(covariant ProductImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrls != widget.imageUrls) {
      _page = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          _controller.jumpToPage(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    final count = images.isEmpty ? 1 : images.length;

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: count,
              physics: const PageScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              onPageChanged: (index) => setState(() => _page = index),
              itemBuilder: (context, index) => AppNetworkImage(
                key: ValueKey(images.isEmpty ? 'empty-product-image' : images[index]),
                url: images.isEmpty ? null : images[index],
                icon: widget.placeholderIcon,
              ),
            ),
            if (count > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < count; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _page ? Colors.white : Colors.white70,
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            if (count > 1 && widget.showCounter)
              Positioned(
                top: 9,
                right: 9,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: Container(
                    key: ValueKey(_page),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.52),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${_page + 1}/$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            if (count == 1)
              Positioned(
                top: 9,
                right: 9,
                child: Icon(
                  Icons.photo_library_outlined,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.88),
                  shadows: const [Shadow(color: Colors.black45, blurRadius: 5)],
                ),
              ),
          ],
        ),
      ),
    );
  }
}