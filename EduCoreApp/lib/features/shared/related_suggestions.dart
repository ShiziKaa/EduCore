import 'package:flutter/material.dart';

import '../../app/app_palette.dart';
import '../../core/app_constants.dart';
import '../../core/search_service.dart';

class RelatedSuggestionsSection extends StatelessWidget {
  const RelatedSuggestionsSection({
    super.key,
    required this.items,
    required this.colors,
    required this.onSelected,
  });

  final List<RelatedSuggestion> items;
  final ColorScheme colors;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final isDark = colors.brightness == Brightness.dark;
    final suggestions = items.take(AppConstants.maxRelatedSuggestions).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final horizontalPad = maxWidth < 420 ? 10.0 : 14.0;
        final verticalPad = maxWidth < 420 ? 8.0 : 10.0;
        final fontSize = maxWidth < 420 ? 12.5 : 13.5;
        final spacing = maxWidth < 420 ? 8.0 : 10.0;

        return Padding(
          padding: const EdgeInsets.only(top: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mümkin sizi gyzyklandyrýar:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? colors.onSurfaceVariant
                          : AppPalette.lightGreenMuted,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: suggestions.map((item) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxWidth < 480
                          ? maxWidth
                          : (maxWidth * 0.48).clamp(160.0, 320.0),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onSelected(item.query),
                        borderRadius: BorderRadius.circular(12),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: isDark
                                ? AppPalette.darkQuickTag
                                : AppPalette.lightQuickTag,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF3C4043)
                                  : AppPalette.lightGreenBorder,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPad,
                              vertical: verticalPad,
                            ),
                            child: Text(
                              item.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    fontSize: fontSize,
                                    height: 1.25,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? colors.onSurface
                                        : AppPalette.lightGreenText,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
