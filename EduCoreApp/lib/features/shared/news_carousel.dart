import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../app/app_palette.dart';
import '../../core/ai_core_paths.dart';
import '../../core/models/news_item.dart';

class NewsCarousel extends StatefulWidget {
  const NewsCarousel({
    super.key,
    required this.items,
    required this.onItemTap,
    this.width = 260,
    this.cardHeight = 168,
  });

  final List<NewsItem> items;
  final ValueChanged<NewsItem> onItemTap;
  final double width;
  final double cardHeight;

  static double preferredWidth(double screenWidth) {
    if (screenWidth < 560) return 200;
    if (screenWidth < 900) return 240;
    return (screenWidth * 0.22).clamp(240.0, 300.0);
  }

  static double preferredCardHeight(double screenHeight) {
    if (screenHeight < 560) return 140;
    if (screenHeight < 800) return 168;
    return (screenHeight * 0.22).clamp(168.0, 200.0);
  }

  @override
  State<NewsCarousel> createState() => _NewsCarouselState();
}

class _NewsCarouselState extends State<NewsCarousel> {
  static const _cardRadius = 12.0;
  static const _cardGap = 2.0;
  static const _inactiveScale = 0.50;

  final CarouselSliderController _carouselController =
      CarouselSliderController();

  double _scrollPage = 0;
  Timer? _resumeAutoPlayTimer;

  bool get _canLoop => widget.items.length > 1;

  CarouselOptions get _carouselOptions => CarouselOptions(
    height: widget.cardHeight,
    scrollDirection: Axis.horizontal,
    viewportFraction: 0.88,
    enableInfiniteScroll: _canLoop,
    padEnds: true,
    disableCenter: true,
    clipBehavior: Clip.hardEdge,
    enlargeCenterPage: false,
    pageSnapping: true,
    autoPlay: _canLoop,
    autoPlayInterval: const Duration(seconds: 3),
    autoPlayAnimationDuration: const Duration(milliseconds: 450),
    autoPlayCurve: Curves.easeInOutCubic,
    pauseAutoPlayOnTouch: true,
    pauseAutoPlayOnManualNavigate: true,
    scrollPhysics: const PageScrollPhysics(),
    onPageChanged: (index, reason) {
      setState(() => _scrollPage = index.toDouble());
    },
    onScrolled: (page) {
      if (page == null) return;
      if ((_scrollPage - page).abs() < 0.001) return;
      setState(() => _scrollPage = page);
    },
  );

  void _pauseAutoPlayBriefly() {
    if (!_canLoop) return;
    _carouselController.stopAutoPlay();
    _resumeAutoPlayTimer?.cancel();
    _resumeAutoPlayTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || !_canLoop) return;
      _carouselController.startAutoPlay();
    });
  }

  double _normalizedPage(double page) {
    final count = widget.items.length;
    if (count == 0) return 0;
    var normalized = page % count;
    if (normalized < 0) normalized += count;
    return normalized;
  }

  double _circularDistance(int index, double page) {
    if (widget.items.isEmpty) return 0;
    final count = widget.items.length;
    final normalized = _normalizedPage(page);
    var dist = (normalized - index).abs();
    if (_canLoop && count > 1) {
      dist = math.min(dist, count - dist);
    }
    return dist.toDouble();
  }

  double _scaleForDistance(double distance) {
    final t = (1.0 - distance.clamp(0.0, 1.0));
    return _inactiveScale + (1.0 - _inactiveScale) * t;
  }

  @override
  void didUpdateWidget(covariant NewsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _scrollPage = 0;
      _carouselController.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _resumeAutoPlayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = colors.brightness == Brightness.dark;
    final indicatorPage = _normalizedPage(_scrollPage);

    return SizedBox(
      width: widget.width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Möhüm habarlar',
            style: textTheme.labelLarge?.copyWith(
              color: isDark ? colors.primary : AppPalette.lightGreenPrimary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: widget.width,
            height: widget.cardHeight,
            child: Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent && event.scrollDelta.dy != 0) {
                  _pauseAutoPlayBriefly();
                }
              },
              child: CarouselSlider.builder(
                key: ValueKey(
                  'news_${widget.items.length}_${widget.cardHeight}',
                ),
                carouselController: _carouselController,
                itemCount: widget.items.length,
                options: _carouselOptions,
                itemBuilder: (context, index, pageIndex) {
                  final distance = _circularDistance(index, _scrollPage);
                  final scale = _scaleForDistance(distance);
                  final opacity = (1.0 - distance * 0.28).clamp(0.62, 1.0);

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _cardGap / 2,
                    ),
                    child: Center(
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.center,
                        child: Opacity(
                          opacity: opacity,
                          child: SizedBox(
                            width: widget.width - _cardGap,
                            height: widget.cardHeight,
                            child: _NewsCard(
                              item: widget.items[index],
                              previewFile: AiCorePaths.resolveImageFile(
                                widget.items[index].preview,
                              ),
                              colors: colors,
                              textTheme: textTheme,
                              isDark: isDark,
                              onTap: () =>
                                  widget.onItemTap(widget.items[index]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (widget.items.length > 1) ...[
            const SizedBox(height: 10),
            _buildPageIndicator(
              page: indicatorPage,
              isDark: isDark,
              colors: colors,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPageIndicator({
    required double page,
    required bool isDark,
    required ColorScheme colors,
  }) {
    final inactiveColor = isDark
        ? colors.onSurface.withValues(alpha: 0.72)
        : AppPalette.lightGreenBorder.withValues(alpha: 0.7);
    final activeColor = isDark ? colors.primary : AppPalette.lightGreenPrimary;

    final effect = ExpandingDotsEffect(
      dotWidth: 7,
      dotHeight: 7,
      spacing: 8,
      expansionFactor: 2.4,
      radius: 3.5,
      dotColor: inactiveColor,
      activeDotColor: activeColor,
    );

    return SizedBox(
      width: widget.width,
      child: Center(
        child: SmoothIndicator(
          offset: page,
          count: widget.items.length,
          size: effect.calculateSize(widget.items.length),
          effect: effect,
          onDotClicked: (index) {
            _pauseAutoPlayBriefly();
            _carouselController.animateToPage(index);
          },
        ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({
    required this.item,
    required this.previewFile,
    required this.colors,
    required this.textTheme,
    required this.isDark,
    required this.onTap,
  });

  final NewsItem item;
  final File? previewFile;
  final ColorScheme colors;
  final TextTheme textTheme;
  final bool isDark;
  final VoidCallback onTap;

  String get _title {
    final firstLine = item.text.split('\n').first.trim();
    return firstLine.isNotEmpty ? firstLine : item.text.trim();
  }

  @override
  Widget build(BuildContext context) {
    const radius = _NewsCarouselState._cardRadius;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF3C4043)
                  : AppPalette.lightGreenBorder.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (previewFile != null)
                  Image.file(previewFile!, fit: BoxFit.cover)
                else
                  ColoredBox(
                    color: isDark
                        ? colors.surfaceContainerHigh
                        : AppPalette.lightMintWash,
                    child: Icon(
                      Icons.image_outlined,
                      color: colors.outline,
                      size: 40,
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.78),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 28, 12, 10),
                      child: Text(
                        _title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          shadows: const [
                            Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
