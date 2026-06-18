import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class DesktopWindowService {
  DesktopWindowService._();

  static bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static Future<void> initialize() async {
    if (!isDesktop) return;

    await windowManager.ensureInitialized();

    const options = WindowOptions(
      size: Size(1280, 720),
      minimumSize: Size(900, 600),
      center: true,
      backgroundColor: Color(0xFF282A2C),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'EduCore',
    );

    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
}
