import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Displays [earned] of 3 filled stars.
class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    required this.earned,
    this.size = 22,
    this.spacing = 2,
  });

  final int earned;
  final double size;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(3, (int i) {
        final bool filled = i < earned;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            color: filled ? AppColors.star : AppColors.starEmpty,
            size: size,
            shadows: filled
                ? const <Shadow>[
                    Shadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 1))
                  ]
                : null,
          ),
        );
      }),
    );
  }
}
