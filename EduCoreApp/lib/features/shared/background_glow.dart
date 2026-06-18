import 'package:flutter/material.dart';

import '../../app/app_palette.dart';

/// Shared screen / title-bar background matching [BackgroundGlow].
class AppBackground {
  AppBackground._();

  static BoxDecoration decoration({
    required bool isDark,
    required ColorScheme colors,
  }) {
    return BoxDecoration(
      color: isDark ? colors.surface : AppPalette.lightBackground,
      gradient: isDark
          ? RadialGradient(
              center: const Alignment(0, -0.15),
              radius: 0.9,
              colors: [
                const Color(0xFF1A237E).withValues(alpha: 0.35),
                const Color(0xFF131314),
              ],
            )
          : null,
    );
  }

  /// Title bar uses a wide horizontal sweep — radial looks like a circle on a thin strip.
  static BoxDecoration titleBarDecoration({
    required bool isDark,
    required ColorScheme colors,
  }) {
    return BoxDecoration(
      color: isDark ? colors.surface : AppPalette.lightBackground,
      gradient: isDark
          ? LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                const Color(0xFF131314),
                const Color(0xFF1A237E).withValues(alpha: 0.55),
                const Color(0xFF24318A).withValues(alpha: 0.4),
                const Color(0xFF1A237E).withValues(alpha: 0.55),
                const Color(0xFF131314),
              ],
              stops: const [0.0, 0.28, 0.5, 0.72, 1.0],
            )
          : null,
    );
  }
}

class BackgroundGlow extends StatelessWidget {
  const BackgroundGlow({
    super.key,
    required this.isDark,
    required this.colors,
  });

  final bool isDark;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: AppBackground.decoration(isDark: isDark, colors: colors),
      ),
    );
  }
}
