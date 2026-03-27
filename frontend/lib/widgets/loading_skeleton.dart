import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../config/theme.dart';

class LoadingSkeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;

  const LoadingSkeleton({
    Key? key,
    this.width,
    this.height,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.border,
      highlightColor: AppTheme.background,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }
}
