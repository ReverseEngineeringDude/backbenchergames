import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Styled card with neon borders and optional glow effects.
class CyberCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? glowColor;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const CyberCard({
    super.key,
    required this.child,
    this.onTap,
    this.glowColor,
    this.borderColor,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        splashColor: (glowColor ?? AppColors.playerX).withAlpha(40),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? AppColors.cardBorder,
              width: 1.2,
            ),
            boxShadow: glowColor != null
                ? [
                    BoxShadow(
                      color: glowColor!,
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
