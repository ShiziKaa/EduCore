import 'package:flutter/material.dart';

import '../../app/app_palette.dart';

class SearchBarField extends StatelessWidget {
  const SearchBarField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.colors,
    required this.enabled,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ColorScheme colors;
  final bool enabled;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final isDark = colors.brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? AppPalette.darkSearchField : AppPalette.lightSearchField,
        color: null,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF3C4043) : AppPalette.lightGreenBorder,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppPalette.lightGreenPrimary.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              style: textTheme.labelLarge,
              decoration: InputDecoration(
                hintText: 'Soragyňyz...',
                hintStyle: textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSubmitted(),
            ),
          ),
          IconButton(
            onPressed: enabled ? onSubmitted : null,
            style: IconButton.styleFrom(
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              focusColor: Colors.transparent,
              padding: const EdgeInsets.only(left: 4, right: 16),
              minimumSize: const Size(36, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Icon(
              Icons.send_rounded,
              size: 22,
              color: enabled ? colors.primary : colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
