import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

class OndesLiquidGlass extends StatelessWidget {
  final Widget child;

  const OndesLiquidGlass({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      glassContainsChild: false,
      shape: const LiquidRoundedSuperellipse(
            borderRadius: 30,
          ),
        child: child,
    );
  }
}