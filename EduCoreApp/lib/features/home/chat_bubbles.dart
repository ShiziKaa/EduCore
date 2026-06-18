import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_palette.dart';

class UserBubble extends StatelessWidget {
  const UserBubble({super.key, required this.text, required this.colors});

  final String text;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final isDark = colors.brightness == Brightness.dark;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: isDark ? null : AppPalette.lightUserBubble,
          color: isDark ? const Color(0xFF3C4043) : null,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
            bottomLeft: Radius.circular(22),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.left,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: isDark ? colors.onSurface : AppPalette.lightGreenText,
          ),
        ),
      ),
    );
  }
}

class AnswerImagesRow extends StatelessWidget {
  const AnswerImagesRow({
    super.key,
    required this.imageNames,
    required this.colors,
    required this.resolveImage,
    required this.onImageTap,
  });

  final List<String> imageNames;
  final ColorScheme colors;
  final File? Function(String name) resolveImage;
  final ValueChanged<File> onImageTap;

  @override
  Widget build(BuildContext context) {
    if (imageNames.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: SizedBox(
        height: 160,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: imageNames.length,
          separatorBuilder: (context, index) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final imageFile = resolveImage(imageNames[index]);

            return GestureDetector(
              onTap: imageFile != null ? () => onImageTap(imageFile) : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 220,
                  decoration: BoxDecoration(
                    color: colors.brightness == Brightness.dark
                        ? const Color(0xFF282A2C)
                        : AppPalette.lightCardFill,
                    border: Border.all(
                      color: colors.brightness == Brightness.dark
                          ? const Color(0xFF3C4043)
                          : AppPalette.lightGreenBorder,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: imageFile != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(imageFile, fit: BoxFit.cover),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Container(
                                margin: const EdgeInsets.all(8),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.zoom_out_map_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              imageNames[index],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
