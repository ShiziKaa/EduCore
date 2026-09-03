import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import 'app_theme.dart';
import 'app_window_chrome.dart';
import '../features/home/edu_core_screen.dart';

class EduCoreApp extends StatefulWidget {
  const EduCoreApp({super.key});

  @override
  State<EduCoreApp> createState() => _EduCoreAppState();
}

class _EduCoreAppState extends State<EduCoreApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  bool _hideWindowChrome = false;

  final _navigatorKey = GlobalKey<NavigatorState>();
  final _routeObserver = _ChromeRouteObserver();

  @override
  void initState() {
    super.initState();
    _routeObserver.onChromeVisibilityChanged = (hide) {
      _scheduleRebuild(() => _hideWindowChrome = hide);
    };
  }

  void _scheduleRebuild(VoidCallback update) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(update);
    });
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _themeMode == ThemeMode.dark;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConstants.appDisplayName,
      navigatorKey: _navigatorKey,
      themeMode: _themeMode,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      navigatorObservers: [_routeObserver],
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();

        return AppWindowChrome(
          showTitleBar: !_hideWindowChrome,
          isDark: isDark,
          onToggleTheme: _toggleTheme,
          child: child,
        );
      },
      home: EduCoreScreen(onToggleTheme: _toggleTheme),
    );
  }
}

class _ChromeRouteObserver extends NavigatorObserver {
  void Function(bool hide)? onChromeVisibilityChanged;
  bool _hideChrome = false;

  bool _shouldHideChrome(Route<dynamic>? route) {
    if (route is! PageRoute<dynamic>) return false;
    return route.fullscreenDialog;
  }

  void _notify(Route<dynamic>? route) {
    final hide = _shouldHideChrome(route);
    if (hide != _hideChrome) {
      _hideChrome = hide;
      onChromeVisibilityChanged?.call(hide);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _notify(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _notify(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _notify(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _notify(previousRoute);
  }
}
