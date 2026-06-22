import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_palette.dart';

class AdminToastData {
  AdminToastData({
    required this.id,
    required this.message,
    this.isError = false,
  });

  final String id;
  final String message;
  final bool isError;
}

class AdminToastStack extends StatefulWidget {
  const AdminToastStack({
    super.key,
    required this.toasts,
    required this.onDismiss,
    this.autoDismissDuration = const Duration(milliseconds: 1500),
  });

  final List<AdminToastData> toasts;
  final ValueChanged<String> onDismiss;
  final Duration autoDismissDuration;

  @override
  State<AdminToastStack> createState() => _AdminToastStackState();
}

class _AdminToastStackState extends State<AdminToastStack> {
  final Set<String> _scheduled = {};

  @override
  void didUpdateWidget(covariant AdminToastStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final toast in widget.toasts) {
      _scheduleDismiss(toast.id);
    }
    _scheduled.removeWhere(
      (id) => widget.toasts.every((toast) => toast.id != id),
    );
  }

  void _scheduleDismiss(String id) {
    if (_scheduled.contains(id)) return;
    _scheduled.add(id);
    Timer(widget.autoDismissDuration, () {
      if (!mounted) return;
      _scheduled.remove(id);
      widget.onDismiss(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.toasts.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final isDark = colors.brightness == Brightness.dark;

    for (final toast in widget.toasts) {
      _scheduleDismiss(toast.id);
    }

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: widget.toasts.map((toast) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AdminToastCard(
                toast: toast,
                colors: colors,
                isDark: isDark,
                onDismiss: () => widget.onDismiss(toast.id),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _AdminToastCard extends StatelessWidget {
  const _AdminToastCard({
    required this.toast,
    required this.colors,
    required this.isDark,
    required this.onDismiss,
  });

  final AdminToastData toast;
  final ColorScheme colors;
  final bool isDark;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final accent = toast.isError ? colors.error : colors.primary;
    final icon = toast.isError
        ? Icons.error_outline_rounded
        : Icons.check_circle_outline_rounded;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isDark ? AppPalette.darkQuickTag : AppPalette.lightQuickTag,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: toast.isError
              ? colors.error.withValues(alpha: 0.65)
              : (isDark
                  ? const Color(0xFF3C4043)
                  : AppPalette.lightGreenBorder),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                toast.message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.35,
                      color: isDark
                          ? colors.onSurface
                          : AppPalette.lightGreenText,
                    ),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: 'Ýap',
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                foregroundColor: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
