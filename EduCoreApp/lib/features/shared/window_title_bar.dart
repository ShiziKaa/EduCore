import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';

import 'background_glow.dart';

class WindowTitleBar extends StatefulWidget {
  const WindowTitleBar({
    super.key,
    this.onToggleTheme,
    this.isDark = true,
  });

  final VoidCallback? onToggleTheme;
  final bool isDark;

  static const double height = 42;

  @override
  State<WindowTitleBar> createState() => _WindowTitleBarState();
}

class _WindowTitleBarState extends State<WindowTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _syncMaximized() async {
    final maximized = await windowManager.isMaximized();
    if (mounted) setState(() => _isMaximized = maximized);
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: AppBackground.titleBarDecoration(
        isDark: widget.isDark,
        colors: colors,
      ),
      child: SizedBox(
        height: WindowTitleBar.height,
        child: Row(
          children: [
            Expanded(
              child: DragToMoveArea(
                child: SizedBox(
                  height: WindowTitleBar.height,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _AppBrand(colors: colors),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.onToggleTheme != null)
              _TitleBarIconButton(
                icon: widget.isDark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                label: widget.isDark ? 'Ýagty tema' : 'Garaňky tema',
                colors: colors,
                onPressed: widget.onToggleTheme,
              ),
            _WindowControlButton(
              icon: Icons.remove_rounded,
              label: 'Kiçelt',
              colors: colors,
              onPressed: windowManager.minimize,
            ),
            _WindowControlButton(
              icon: _isMaximized
                  ? Icons.filter_none_rounded
                  : Icons.crop_square_rounded,
              label: _isMaximized ? 'Dikelt' : 'Giňelt',
              colors: colors,
              onPressed: () async {
                if (_isMaximized) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
            _WindowControlButton(
              icon: Icons.close_rounded,
              label: 'Ýap',
              colors: colors,
              hoverColor: const Color(0xFFE81123),
              hoverForeground: Colors.white,
              onPressed: windowManager.close,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBrand extends StatelessWidget {
  const _AppBrand({required this.colors});

  final ColorScheme colors;

  static const _logoAsset = 'assets/icons/launcher_icon.png';

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            _logoAsset,
            width: 22,
            height: 22,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  size: 14,
                  color: colors.primary,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        DefaultTextStyle(
          style: const TextStyle(decoration: TextDecoration.none),
          child: Text(
            'EduCore',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: colors.onSurface,
              decoration: TextDecoration.none,
              decorationThickness: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _TitleBarIconButton extends StatefulWidget {
  const _TitleBarIconButton({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final ColorScheme colors;
  final VoidCallback? onPressed;

  @override
  State<_TitleBarIconButton> createState() => _TitleBarIconButtonState();
}

class _TitleBarIconButtonState extends State<_TitleBarIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = _hovered
        ? widget.colors.onSurface.withValues(alpha: 0.08)
        : Colors.transparent;

    return Semantics(
      label: widget.label,
      button: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: SizedBox(
          width: 42,
          height: WindowTitleBar.height,
          child: Material(
            color: bg,
            child: InkWell(
              onTap: widget.onPressed,
              child: Icon(
                widget.icon,
                size: 16,
                color: widget.colors.onSurface.withValues(alpha: 0.88),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowControlButton extends StatefulWidget {
  const _WindowControlButton({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onPressed,
    this.hoverColor,
    this.hoverForeground,
  });

  final IconData icon;
  final String label;
  final ColorScheme colors;
  final Future<void> Function()? onPressed;
  final Color? hoverColor;
  final Color? hoverForeground;

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = _hovered
        ? (widget.hoverColor ??
              widget.colors.onSurface.withValues(alpha: 0.08))
        : Colors.transparent;
    final fg = _hovered && widget.hoverForeground != null
        ? widget.hoverForeground!
        : widget.colors.onSurface.withValues(alpha: 0.88);

    return Semantics(
      label: widget.label,
      button: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: SizedBox(
          width: 46,
          height: WindowTitleBar.height,
          child: Material(
            color: bg,
            child: InkWell(
              onTap: widget.onPressed,
              child: Icon(widget.icon, size: 16, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}
