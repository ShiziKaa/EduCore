import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/ai_core_paths.dart';

class AdminMediaPreviewGrid extends StatelessWidget {
  const AdminMediaPreviewGrid({
    super.key,
    required this.imageNames,
    required this.videoNames,
    required this.colors,
    this.newsPreview,
  });

  final List<String> imageNames;
  final List<String> videoNames;
  final ColorScheme colors;
  final String? newsPreview;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (newsPreview != null && newsPreview!.isNotEmpty) {
      children.addAll([
        Text('Preview', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        _AdminImageThumb(
          fileName: newsPreview!,
          colors: colors,
          highlight: true,
        ),
        const SizedBox(height: 16),
      ]);
    }

    if (imageNames.isNotEmpty) {
      children.addAll([
        Text('Suratlar', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: imageNames
              .map(
                (name) => SizedBox(
                  width: 124,
                  child: _AdminImageThumb(fileName: name, colors: colors),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
      ]);
    }

    if (videoNames.isNotEmpty) {
      children.addAll([
        Text('Wideo', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        ...videoNames.map(
          (name) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AdminVideoThumb(fileName: name, colors: colors),
          ),
        ),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _AdminImageThumb extends StatelessWidget {
  const _AdminImageThumb({
    required this.fileName,
    required this.colors,
    this.highlight = false,
  });

  final String fileName;
  final ColorScheme colors;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final file = AiCorePaths.resolveImageFile(fileName);
    final isDark = colors.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 84,
            decoration: BoxDecoration(
              border: Border.all(
                color: highlight
                    ? colors.primary
                    : (isDark
                        ? const Color(0xFF3C4043)
                        : colors.outlineVariant),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: file != null
                ? Image.file(file, fit: BoxFit.cover)
                : ColoredBox(
                    color: colors.surfaceContainerHighest,
                    child: Icon(Icons.broken_image_outlined,
                        color: colors.outline),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _AdminVideoThumb extends StatefulWidget {
  const _AdminVideoThumb({
    required this.fileName,
    required this.colors,
  });

  final String fileName;
  final ColorScheme colors;

  @override
  State<_AdminVideoThumb> createState() => _AdminVideoThumbState();
}

class _AdminVideoThumbState extends State<_AdminVideoThumb> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final file = AiCorePaths.resolveVideoFile(widget.fileName);
    if (file == null) {
      _failed = true;
      return;
    }

    final controller = VideoPlayerController.file(file);
    _controller = controller;
    controller
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        controller.play();
      }).catchError((_) {
        if (mounted) setState(() => _failed = true);
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.colors.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 96,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1F20)
                  : widget.colors.surfaceContainerHighest,
              border: Border.all(
                color: isDark
                    ? const Color(0xFF3C4043)
                    : widget.colors.outlineVariant,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_failed)
                  Center(
                    child: Icon(
                      Icons.videocam_off_outlined,
                      color: widget.colors.onSurfaceVariant,
                    ),
                  )
                else if (_ready && _controller != null)
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  )
                else
                  Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.colors.primary,
                      ),
                    ),
                  ),
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    Icons.play_circle_outline,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
