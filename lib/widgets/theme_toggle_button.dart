import 'package:flutter/material.dart';

import '../core/theme_controller.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, this.onDarkBackground = false});

  final bool onDarkBackground;

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isDark = controller.isDark;
        return IconButton(
          tooltip: isDark ? 'الوضع الفاتح' : 'الوضع الداكن',
          onPressed: controller.toggle,
          style: IconButton.styleFrom(
            backgroundColor: onDarkBackground
                ? Colors.white.withValues(alpha: .12)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            foregroundColor:
                onDarkBackground ? Colors.white : null,
          ),
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
        );
      },
    );
  }
}
