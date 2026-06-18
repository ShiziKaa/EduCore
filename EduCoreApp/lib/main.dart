import 'package:flutter/material.dart';

import 'app/edu_core_app.dart';
import 'core/services/desktop_window_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DesktopWindowService.initialize();
  runApp(const EduCoreApp());
}
