import 'package:flutter/material.dart';

import '../core/services/desktop_window_service.dart';
import '../features/shared/window_title_bar.dart';

/// Desktop shell: custom title bar + app content below.
class AppWindowChrome extends StatelessWidget {
  const AppWindowChrome({
    super.key,
    required this.child,
    this.onToggleTheme,
    this.isDark = true,
    this.showTitleBar = true,
  });

  final Widget child;
  final VoidCallback? onToggleTheme;
  final bool isDark;
  final bool showTitleBar;

  @override
  Widget build(BuildContext context) {
    if (!DesktopWindowService.isDesktop || !showTitleBar) {
      return child;
    }

    return Column(
      children: [
        WindowTitleBar(
          onToggleTheme: onToggleTheme,
          isDark: isDark,
        ),
        Expanded(child: child),
      ],
    );
  }
}
