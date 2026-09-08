import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class FullscreenVideoPage extends StatefulWidget {
  const FullscreenVideoPage({super.key, required this.videoFile});

  final File videoFile;

  @override
  State<FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<FullscreenVideoPage> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final controller = VideoPlayerController.file(widget.videoFile);
    _controller = controller;
    controller.initialize().then((_) async {
      if (!mounted) return;
      await controller.seekTo(Duration.zero);
      await controller.setLooping(true);
      await controller.setVolume(1);
      await controller.play();
      setState(() => _ready = true);
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
    controller.addListener(() {
      if (!mounted) return;
      final value = controller.value;
      if (value.isInitialized &&
          value.duration > Duration.zero &&
          value.position >= value.duration &&
          !value.isPlaying) {
        controller.seekTo(Duration.zero);
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: _failed
            ? const Text(
                'Wideo açyp bolmady',
                style: TextStyle(color: Colors.white70),
              )
            : _ready && _controller != null
            ? AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
      floatingActionButton: _ready && _controller != null
          ? FloatingActionButton(
              onPressed: () async {
                final controller = _controller!;
                if (controller.value.isPlaying) {
                  await controller.pause();
                } else {
                  final value = controller.value;
                  if (value.duration > Duration.zero &&
                      value.position >= value.duration) {
                    await controller.seekTo(Duration.zero);
                  }
                  await controller.play();
                }
                if (mounted) setState(() {});
              },
              child: Icon(
                _controller!.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
            )
          : null,
    );
  }
}
