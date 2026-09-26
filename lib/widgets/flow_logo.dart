import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class FlowLogo extends StatelessWidget {
  const FlowLogo({this.size = 30, this.color, super.key});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint =
        color ??
        (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFC4A5FA)
            : const Color(0xFF75398C));
    return SvgPicture.asset(
      'assets/branding/logo.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}
