import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

enum MatchBadgeVariant { filled, subtle, outlined }

class MatchScoreBadge extends StatelessWidget {
  final double score; // 0.0 to 1.0
  final MatchBadgeVariant variant;

  const MatchScoreBadge({
    super.key,
    required this.score,
    this.variant = MatchBadgeVariant.filled,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (score * 100).round();
    
    Color backgroundColor;
    Color textColor;

    switch (variant) {
      case MatchBadgeVariant.filled:
        backgroundColor = AppColors.primary;
        textColor = AppColors.textDark;
        break;
      case MatchBadgeVariant.subtle:
        backgroundColor = const Color(0xFF2B2B2B); // Dark subtle background
        textColor = AppColors.primary;
        break;
      case MatchBadgeVariant.outlined:
        backgroundColor = Colors.transparent;
        textColor = AppColors.primary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: variant == MatchBadgeVariant.outlined 
            ? Border.all(color: AppColors.primary) 
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$percentage%',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'match',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
