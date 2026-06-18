import 'dart:io';

import 'package:flutter/material.dart';

class FullscreenImagePage extends StatelessWidget {
  const FullscreenImagePage({super.key, required this.imageFile});

  final File imageFile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: InteractiveViewer(
        minScale: 0.8,
        maxScale: 5,
        child: Center(child: Image.file(imageFile, fit: BoxFit.contain)),
      ),
    );
  }
}
