import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_palette.dart';
import 'search_bar_field.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.colors,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onSearch,
    required this.onQuickTag,
    this.instituteLogo,
  });

  final ColorScheme colors;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onSearch;
  final ValueChanged<String> onQuickTag;
  final File? instituteLogo;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const tags = [
      'TDBSI',
      'Fakultetler',
      'Kafedralar',
      'Kurslar',
      'Dersler',
      'Okuw tölegi',
      'Geçen aýyň habarlary',
      'Nyzam tertibi',
      'Sport habarlary',
      'Sosial media',
    ];

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
          'Hormatly talyplar we myhmanlar!',
          textAlign: TextAlign.center,
          style: textTheme.headlineLarge,
        ),
        const SizedBox(height: 16),
        Text(
          'Institutymyz baradaky islendik soragyňyzy aşakda ýazyp bilersiňiz.',
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
        const SizedBox(height: 28),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: tags
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
