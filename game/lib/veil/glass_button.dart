import 'package:flutter/material.dart';

/// Shared button styling for the shell (gray) screens. Intentionally distinct
/// from the native game's wooden buttons and from any template styling: a
/// frosted sky-blue pill with a press-scale reaction.
class SkyPillButton extends StatefulWidget {
  const SkyPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.compact = false,
    this.width,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;
  final double? width;

  @override
  State<SkyPillButton> createState() => _SkyPillButtonState();
}

class _SkyPillButtonState extends State<SkyPillButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: widget.width,
          padding: EdgeInsets.symmetric(
            horizontal: 28,
            vertical: widget.compact ? 12 : 17,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF63BEF8), Color(0xFF2E78C9)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF1B4F86).withValues(alpha: 0.55),
                offset: const Offset(0, 5),
                blurRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                offset: const Offset(0, 4),
                blurRadius: 10,
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: widget.compact ? 16 : 19,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                shadows: const <Shadow>[
                  Shadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Subdued text-only action (used for "Skip").
class SkyTextButton extends StatefulWidget {
  const SkyTextButton({
    super.key,
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<SkyTextButton> createState() => _SkyTextButtonState();
}

class _SkyTextButtonState extends State<SkyTextButton> {
  double _opacity = 0.9;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _opacity = 0.5),
      onTapCancel: () => setState(() => _opacity = 0.9),
      onTapUp: (_) {
        setState(() => _opacity = 0.9);
        widget.onTap();
      },
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 90),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: widget.compact ? 6 : 10),
          child: Text(
            widget.label,
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.compact ? 15 : 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white70,
              shadows: const <Shadow>[
                Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
