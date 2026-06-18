import 'package:flutter/material.dart';

import '../../app/app_palette.dart';
import '../../core/app_constants.dart';

class DeveloperFooter extends StatelessWidget {
  const DeveloperFooter({super.key, required this.onLongPress});

  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = colors.brightness == Brightness.dark;

    return Positioned(
      left: 16,
      bottom: 16,
      child: SafeArea(
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1F20).withValues(alpha: 0.92)
                  : AppPalette.lightBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF3C4043)
                    : AppPalette.lightGreenBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.08),
                  blurRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? const [Color(0xFF3949AB), Color(0xFF1A237E)]
                          : const [Color(0xFF5CB868), Color(0xFF1F8A40)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppConstants.developerName,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppConstants.developerEmail,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
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
  }
}
