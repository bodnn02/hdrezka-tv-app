import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

/// TV-focusable wrapper with Liquid Glass focus ring.
class FocusableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onSelect;
  final void Function(bool focused)? onFocusChange;
  final bool autofocus;
  final FocusNode? focusNode;
  final BorderRadius? borderRadius;

  const FocusableCard({
    super.key,
    required this.child,
    required this.onSelect,
    this.onFocusChange,
    this.autofocus = false,
    this.focusNode,
    this.borderRadius,
  });

  @override
  State<FocusableCard> createState() => _FocusableCardState();
}

class _FocusableCardState extends State<FocusableCard> {
  bool _focused = false;

  BoxDecoration _decoration() {
    final br = widget.borderRadius ?? BorderRadius.circular(14);
    if (_focused) {
      return BoxDecoration(
        borderRadius: br,
        border: Border.all(color: AppColors.glassBorderFocus, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Color(0x55FFFFFF), blurRadius: 20, spreadRadius: 0),
          BoxShadow(color: AppColors.accentGlow, blurRadius: 32, spreadRadius: -6),
        ],
      );
    }
    return BoxDecoration(
      borderRadius: br,
      border: Border.all(color: Colors.transparent, width: 2.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      onFocusChange: (f) {
        setState(() => _focused = f);
        widget.onFocusChange?.call(f);
      },
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onSelect();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: _decoration(),
          child: widget.child,
        ),
      ),
    );
  }
}
