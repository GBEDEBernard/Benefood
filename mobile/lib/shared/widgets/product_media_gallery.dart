import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'app_network_image.dart';

/// Galerie média d'un produit : petite vidéo (si présente) puis images,
/// navigables horizontalement avec indicateur de pagination.
class ProductMediaGallery extends StatefulWidget {
  const ProductMediaGallery({
    super.key,
    this.imageUrls = const [],
    this.videoUrl,
    this.height = 280,
    this.placeholderIcon = Icons.fastfood_outlined,
  });

  final List<String> imageUrls;
  final String? videoUrl;
  final double height;
  final IconData placeholderIcon;

  @override
  State<ProductMediaGallery> createState() => _ProductMediaGalleryState();
}

class _ProductMediaGalleryState extends State<ProductMediaGallery> {
  final PageController _controller = PageController();
  int _page = 0;

  List<_MediaItem> get _items => _buildItems();

  List<_MediaItem> _buildItems() {
    final items = <_MediaItem>[];
    for (final url in widget.imageUrls) {
      if (url.isNotEmpty) {
        items.add(_MediaItem(url: url, isVideo: false));
      }
    }
    final video = widget.videoUrl;
    if (video != null && video.isNotEmpty) {
      items.add(_MediaItem(url: video, isVideo: true));
    }
    if (items.isEmpty) {
      items.add(const _MediaItem(url: null, isVideo: false));
    }
    return items;
  }

  @override
  void didUpdateWidget(covariant ProductMediaGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrls != widget.imageUrls || oldWidget.videoUrl != widget.videoUrl) {
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
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _items.length,
            physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (context, index) {
              final item = _items[index];
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 360),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.97, end: 1).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey('${item.isVideo}:${item.url}'),
                  child: item.isVideo
                      ? _VideoSlide(
                          url: item.url!,
                          fallbackIcon: widget.placeholderIcon,
                        )
                      : AppNetworkImage(
                          url: item.url,
                          icon: widget.placeholderIcon,
                        ),
                ),
              );
            },
          ),
          if (_items.length > 1)
            Positioned(
              top: 12,
              right: 12,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: Container(
                  key: ValueKey(_page),
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${_page + 1} / ${_items.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          if (_items.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _items.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _page ? Colors.white : Colors.white54,
                        borderRadius: BorderRadius.circular(4),
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

class _MediaItem {
  const _MediaItem({required this.url, required this.isVideo});

  final String? url;
  final bool isVideo;
}

class _VideoSlide extends StatefulWidget {
  const _VideoSlide({required this.url, required this.fallbackIcon});

  final String url;
  final IconData fallbackIcon;

  @override
  State<_VideoSlide> createState() => _VideoSlideState();
}

class _VideoSlideState extends State<_VideoSlide> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final resolved = resolveMediaUrl(widget.url);
    if (resolved == null || resolved.isEmpty) {
      setState(() => _failed = true);
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(resolved));
    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      setState(() => _ready = true);
    } catch (_) {
      if (mounted) {
        setState(() => _failed = true);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggle() {
    final controller = _controller;
    if (controller == null || !_ready) {
      return;
    }
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (_failed || controller == null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Icon(widget.fallbackIcon, color: Colors.white54, size: 40),
        ),
      );
    }

    if (!_ready) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: _toggle,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: controller.value.isPlaying ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  color: Colors.black26,
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
