import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../app/app_palette.dart';
import 'fullscreen_video_page.dart';

class AnswerVideosRow extends StatelessWidget {
  const AnswerVideosRow({
    super.key,
    required this.videoNames,
    required this.colors,
    required this.resolveVideo,
  });

  final List<String> videoNames;
  final ColorScheme colors;
  final File? Function(String name) resolveVideo;

  @override
  Widget build(BuildContext context) {
    if (videoNames.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: SizedBox(
        height: 200,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: videoNames.length,
          separatorBuilder: (context, index) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final videoFile = resolveVideo(videoNames[index]);
            if (videoFile == null) {
              return _MissingVideoCard(
                name: videoNames[index],
                colors: colors,
              );
            }

            return AnswerVideoPreviewCard(
              videoFile: videoFile,
              colors: colors,
            );
          },
        ),
      ),
    );
  }
}

class AnswerVideoPreviewCard extends StatefulWidget {
  const AnswerVideoPreviewCard({
    super.key,
    required this.videoFile,
    required this.colors,
  });

  final File videoFile;
  final ColorScheme colors;

  @override
  State<AnswerVideoPreviewCard> createState() => _AnswerVideoPreviewCardState();
}

class _AnswerVideoPreviewCardState extends State<AnswerVideoPreviewCard> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final controller = VideoPlayerController.file(widget.videoFile);
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

  Future<void> _openFullscreen() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.pause();
    if (!mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FullscreenVideoPage(videoFile: widget.videoFile),
      ),
    );

    if (!mounted || !_ready) return;
    await controller.seekTo(Duration.zero);
    await controller.play();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.colors.brightness == Brightness.dark;

    return GestureDetector(
      onTap: _openFullscreen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 280,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1F20) : AppPalette.lightCardFill,
            border: Border.all(
              color: isDark ? const Color(0xFF3C4043) : AppPalette.lightGreenBorder,
            ),
            borderRadius: BorderRadius.circular(14),
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
                  child: CircularProgressIndicator(
                    color: widget.colors.primary,
                    strokeWidth: 2,
                  ),
                ),
              Positioned(
                left: 10,
                bottom: 10,
                right: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      widget.videoFile.uri.pathSegments.last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissingVideoCard extends StatelessWidget {
  const _MissingVideoCard({required this.name, required this.colors});

  final String name;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.brightness == Brightness.dark
            ? const Color(0xFF282A2C)
            : AppPalette.lightCardFill,
        border: Border.all(
          color: colors.brightness == Brightness.dark
              ? const Color(0xFF3C4043)
              : AppPalette.lightGreenBorder,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off_outlined, color: colors.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
