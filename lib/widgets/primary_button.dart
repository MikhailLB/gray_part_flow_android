import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A chunky cartoon-style button with a pressed-state animation.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.sunset,
    this.icon,
    this.width,
    this.enabled = true,
    this.labelDx = 0,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;
  final double? width;
  final bool enabled;

  /// Horizontal nudge (in logical pixels) applied to the label text only.
  /// Negative moves it left. Useful to optically center text next to an icon.
  final double labelDx;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && widget.onPressed != null;
    final Color base = active ? widget.color : Colors.grey.shade500;
    final Color shadow = Color.alphaBlend(Colors.black26, base);

    return Opacity(
      opacity: active ? 1 : 0.7,
      child: GestureDetector(
        onTapDown: active ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: active ? () => setState(() => _pressed = false) : null,
        onTapUp: active
            ? (_) {
                setState(() => _pressed = false);
                widget.onPressed!();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: widget.width,
          transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
            boxShadow: _pressed
                ? <BoxShadow>[]
                : <BoxShadow>[
                    BoxShadow(
                      color: shadow,
                      offset: const Offset(0, 5),
                      blurRadius: 0,
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (widget.icon != null) ...<Widget>[
                Icon(widget.icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Transform.translate(
                  offset: Offset(widget.labelDx, 0),
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: AppTheme.titleStyle(size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
