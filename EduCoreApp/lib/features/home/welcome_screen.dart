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
    this.instituteLogo,
  });

  final ColorScheme colors;
  final WelcomeSettings settings;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onSearch;
  final ValueChanged<String> onQuickTag;
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

/// Recent search chips for the home top-left overlay.
class RecentSearchHistoryPanel extends StatelessWidget {
  const RecentSearchHistoryPanel({
    super.key,
    required this.colors,
    required this.searches,
    required this.enabled,
    required this.onSelect,
    required this.onClear,
  });

  final ColorScheme colors;
  final List<String> searches;
  final bool enabled;
  final ValueChanged<String> onSelect;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (searches.isEmpty) return const SizedBox.shrink();

    final isDark = colors.brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final items = searches.take(4).toList();

    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Soňky gözlegler',
                style: textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 2),
              Tooltip(
                message: 'Arassala',
                child: InkWell(
                  onTap: enabled ? onClear : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _HistoryChip(
                  label: items[i],
                  colors: colors,
                  isDark: isDark,
                  onPressed: enabled ? () => onSelect(items[i]) : null,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryChip extends StatelessWidget {
  const _HistoryChip({
    required this.label,
    required this.colors,
    required this.isDark,
    required this.onPressed,
  });

  final String label;
  final ColorScheme colors;
  final bool isDark;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontSize: 13,
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
