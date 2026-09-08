import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/ai_core_paths.dart';

class AdminMediaPreviewGrid extends StatelessWidget {
  const AdminMediaPreviewGrid({
    super.key,
    required this.imageNames,
    required this.videoNames,
    required this.colors,
    this.audioNames = const [],
    this.newsPreview,
    this.onRemoveAudio,
    this.onRemoveImage,
    this.onRemoveVideo,
    this.onRemoveNewsPreview,
  });

  final List<String> imageNames;
  final List<String> videoNames;
  final List<String> audioNames;
  final ColorScheme colors;
  final String? newsPreview;
  final ValueChanged<String>? onRemoveAudio;
  final ValueChanged<String>? onRemoveImage;
  final ValueChanged<String>? onRemoveVideo;
  final VoidCallback? onRemoveNewsPreview;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (newsPreview != null && newsPreview!.isNotEmpty) {
      children.addAll([
        Text('Preview', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SizedBox(
          width: 124,
          child: _AdminImageThumb(
            fileName: newsPreview!,
            colors: colors,
            highlight: true,
            onRemove: onRemoveNewsPreview,
          ),
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
                  child: _AdminImageThumb(
                    fileName: name,
                    colors: colors,
                    onRemove: onRemoveImage == null
                        ? null
                        : () => onRemoveImage!(name),
                  ),
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
            child: _AdminVideoThumb(
              fileName: name,
              colors: colors,
              onRemove: onRemoveVideo == null
                  ? null
                  : () => onRemoveVideo!(name),
            ),
          ),
        ),
      ]);
    }

    if (audioNames.isNotEmpty) {
      children.addAll([
        Text('Audio', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        ...audioNames.map(
          (name) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.audiotrack_outlined, color: colors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (onRemoveAudio != null)
                  IconButton(
                    tooltip: 'Audio öçür',
                    onPressed: () => onRemoveAudio!(name),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: colors.error,
                    ),
                  ),
              ],
            ),
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
    this.onRemove,
  });

  final String fileName;
  final ColorScheme colors;
  final bool highlight;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final file = AiCorePaths.resolveImageFile(fileName);
    final isDark = colors.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 84,
                width: double.infinity,
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
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: colors.outline,
                        ),
                      ),
              ),
            ),
            if (onRemove != null)
              Positioned(
                top: 2,
                right: 2,
                child: Material(
                  color: colors.surface.withValues(alpha: 0.88),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Öçür',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    onPressed: onRemove,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: colors.error,
                    ),
                  ),
                ),
              ),
          ],
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
    this.onRemove,
  });

  final String fileName;
  final ColorScheme colors;
  final VoidCallback? onRemove;

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
                  left: 6,
                  child: Icon(
                    Icons.play_circle_outline,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
                if (widget.onRemove != null)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Material(
                      color: widget.colors.surface.withValues(alpha: 0.88),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Wideo öçür',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        onPressed: widget.onRemove,
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: widget.colors.error,
                        ),
                      ),
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
