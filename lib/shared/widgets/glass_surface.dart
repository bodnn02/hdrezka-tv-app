import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum GlassVariant { light, medium, strong, card }

/// Apple TV 26 Liquid Glass surface.
/// Wraps [child] in BackdropFilter blur + gradient fill + border rim.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final GlassVariant variant;
  final bool focused;
  final EdgeInsetsGeometry? padding;

  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.variant = GlassVariant.medium,
    this.focused = false,
    this.padding,
  });

  double get _blur {
    switch (variant) {
      case GlassVariant.light:  return LiquidGlass.blurLight;
      case GlassVariant.medium: return LiquidGlass.blurMedium;
      case GlassVariant.strong: return LiquidGlass.blurHeavy;
      case GlassVariant.card:   return LiquidGlass.blurMedium;
    }
  }

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(borderRadius);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: focused
          ? LiquidGlass.focused(radius: borderRadius)
          : LiquidGlass.surface(radius: borderRadius, strong: variant == GlassVariant.strong),
      child: ClipRRect(
        borderRadius: br,
        child: Stack(
          children: [
            // Blur layer
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
                child: const SizedBox.expand(),
              ),
            ),

            // Top-rim iridescent highlight
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: borderRadius * 1.5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
                  gradient: LiquidGlass.topRimGradient,
                ),
              ),
            ),

            // Content
            if (padding != null)
              Padding(padding: padding!, child: child)
            else
              child,
          ],
        ),
      ),
    );
  }
}

/// Pill-shaped glass button (Liquid Glass style).
class GlassButton extends StatelessWidget {
  final Widget child;
  final bool focused;
  final bool primary;

  const GlassButton({
    super.key,
    required this.child,
    this.focused = false,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: primary
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFD0D8FF)],
              ),
              boxShadow: focused
                  ? const [
                      BoxShadow(color: Color(0x80FFFFFF), blurRadius: 20),
                      BoxShadow(color: AppColors.accentGlow, blurRadius: 28, spreadRadius: -4),
                    ]
                  : const [
                      BoxShadow(color: Color(0x40FFFFFF), blurRadius: 12),
                    ],
              border: Border.all(
                color: focused ? AppColors.glassBorderFocus : Colors.white.withAlpha(120),
                width: focused ? 2.5 : 1,
              ),
            )
          : BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withAlpha(focused ? 55 : 35),
                  Colors.white.withAlpha(focused ? 20 : 10),
                ],
              ),
              border: Border.all(
                color: focused ? AppColors.glassBorderFocus : AppColors.glassBorder,
                width: focused ? 2.5 : 1,
              ),
              boxShadow: focused
                  ? const [
                      BoxShadow(color: Color(0x50FFFFFF), blurRadius: 18),
                      BoxShadow(color: AppColors.accentGlow, blurRadius: 24, spreadRadius: -6),
                    ]
                  : null,
            ),
      child: child,
    );
  }
}

/// Glass tag / chip — small pill label.
class GlassChip extends StatelessWidget {
  final String text;
  final Color? textColor;
  final Color? fillColor;

  const GlassChip({
    super.key,
    required this.text,
    this.textColor,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: fillColor ?? const Color(0xAA000000),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor ?? AppColors.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
