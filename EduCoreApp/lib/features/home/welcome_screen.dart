import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_palette.dart';
import '../../core/models/welcome_settings.dart';
import 'search_bar_field.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.colors,
    required this.settings,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onSearch,
    required this.onQuickTag,
    this.recentSearches = const [],
    this.onRecentSearch,
    this.instituteLogo,
  });

  final ColorScheme colors;
  final WelcomeSettings settings;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onSearch;
  final ValueChanged<String> onQuickTag;
  final List<String> recentSearches;
  final ValueChanged<String>? onRecentSearch;
  final File? instituteLogo;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      key: const ValueKey('welcome'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (instituteLogo != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.file(
              instituteLogo!,
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 20),
        ],
        Text(
          settings.title,
          textAlign: TextAlign.center,
          style: textTheme.headlineLarge,
        ),
        const SizedBox(height: 16),
        Text(
          settings.subtitle,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 30),
        SearchBarField(
          controller: controller,
          focusNode: focusNode,
          colors: colors,
          enabled: enabled,
          onSubmitted: onSearch,
        ),
        if (recentSearches.isNotEmpty) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Soňky gözlegler',
              style: textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 8,
            runSpacing: 8,
            children: recentSearches
                .take(8)
                .map(
                  (query) => ActionChip(
                    label: Text(
                      query.length > 40 ? '${query.substring(0, 40)}…' : query,
                    ),
                    onPressed: enabled && onRecentSearch != null
                        ? () => onRecentSearch!(query)
                        : null,
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
        ],
        if (settings.quickTags.isNotEmpty) ...[
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: settings.quickTags
                .map(
                  (tag) => _QuickTag(
                    label: tag,
                    colors: colors,
                    onPressed: onQuickTag,
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _QuickTag extends StatelessWidget {
  const _QuickTag({
    required this.label,
    required this.colors,
    required this.onPressed,
  });

  final String label;
  final ColorScheme colors;
  final ValueChanged<String> onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = colors.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onPressed(label),
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            gradient: isDark
                ? AppPalette.darkQuickTag
                : AppPalette.lightQuickTag,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF3C4043)
                  : AppPalette.lightGreenBorder,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? colors.onSurface : AppPalette.lightGreenText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
