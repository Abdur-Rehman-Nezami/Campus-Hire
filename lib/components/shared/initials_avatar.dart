import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class InitialsAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;
  final String? imageUrl;

  const InitialsAvatar({
    super.key,
    required this.name,
    this.radius = 24.0,
    this.backgroundColor,
    this.textColor,
    this.imageUrl,
  });

  String get _initials {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.transparent,
        backgroundImage: NetworkImage(imageUrl!),
      );
    }

    // Pick a deterministic background color if not provided
    // For MVP, we just default to primary or dark gray based on a simple hash
    final defaultBg = name.length % 2 == 0 ? AppColors.primary : const Color(0xFF2B2B2B);
    final defaultText = name.length % 2 == 0 ? AppColors.textDark : AppColors.textLight;

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? defaultBg,
      child: Text(
        _initials,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: textColor ?? defaultText,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}
