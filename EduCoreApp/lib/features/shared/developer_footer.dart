import 'package:flutter/material.dart';

import '../../app/app_palette.dart';
import '../../core/app_constants.dart';

class DeveloperFooter extends StatefulWidget {
  const DeveloperFooter({super.key, required this.onLongPress});

  final VoidCallback onLongPress;

  @override
  State<DeveloperFooter> createState() => _DeveloperFooterState();
}

class _DeveloperFooterState extends State<DeveloperFooter>
    with SingleTickerProviderStateMixin {
  static const _holdDuration = Duration(seconds: 3);

  late final AnimationController _progressController;
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: _holdDuration,
    )
      ..addListener(() {
        if (mounted) setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          _completeHold();
        }
      });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _startHold() {
    if (_holding) return;
    setState(() => _holding = true);
    _progressController.forward(from: 0);
  }

  void _cancelHold() {
    if (!_holding) return;
    _progressController.stop();
    _progressController.reset();
    setState(() => _holding = false);
  }

  void _completeHold() {
    if (!_holding) return;
    _progressController.reset();
    setState(() => _holding = false);
    widget.onLongPress();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = colors.brightness == Brightness.dark;

    return Positioned(
      left: 16,
      bottom: 16,
      child: SafeArea(
        top: false,
        child: Listener(
          onPointerDown: (_) => _startHold(),
          onPointerUp: (_) => _cancelHold(),
          onPointerCancel: (_) => _cancelHold(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1F20).withValues(alpha: 0.92)
                  : AppPalette.lightBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _holding
                    ? colors.primary
                    : (isDark
                        ? const Color(0xFF3C4043)
                        : AppPalette.lightGreenBorder),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.08),
                  blurRadius: _holding ? 10 : 2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          value: _holding ? _progressController.value : 0,
                          strokeWidth: 3,
                          strokeCap: StrokeCap.round,
                          color: colors.primary,
                          backgroundColor: colors.outline.withValues(
                            alpha: isDark ? 0.32 : 0.22,
                          ),
                        ),
                      ),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? const [Color(0xFF3949AB), Color(0xFF1A237E)]
                                : const [Color(0xFF5CB868), Color(0xFF1F8A40)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppConstants.developerName,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppConstants.developerEmail,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
