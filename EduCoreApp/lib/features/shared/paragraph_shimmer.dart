import 'package:flutter/material.dart';

import '../../app/app_palette.dart';

class ParagraphShimmer extends StatefulWidget {
  const ParagraphShimmer({super.key, required this.isDark});

  final bool isDark;

  @override
  State<ParagraphShimmer> createState() => _ParagraphShimmerState();
}

class _ParagraphShimmerState extends State<ParagraphShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.isDark
        ? const Color(0xFF3C4043)
        : AppPalette.lightMintDeep;
    final highlight = widget.isDark
        ? const Color(0xFF6F7378)
        : AppPalette.lightMintSoft;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            final slide = _controller.value * 2.6 - 0.8;
            return LinearGradient(
              begin: Alignment(slide - 1, 0),
              end: Alignment(slide, 0),
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _shimmerLine(height: 16),
          const SizedBox(height: 12),
          _shimmerLine(height: 16, widthFactor: 0.72),
        ],
      ),
    );
  }

  Widget _shimmerLine({required double height, double widthFactor = 1}) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
