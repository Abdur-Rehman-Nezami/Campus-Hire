import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class StatusPill extends StatelessWidget {
  final String status;
  final bool isSolid; // If true, uses solid background with white text (e.g. URGENT)
  final bool isOutlined; // If true, uses outline style (e.g. PRE-SEED)

  const StatusPill({
    super.key,
    required this.status,
    this.isSolid = false,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    Color textColor;
    Color backgroundColor;
    Color borderColor = Colors.transparent;

    final lowerStatus = status.toLowerCase();

    if (isSolid && lowerStatus == 'urgent') {
      backgroundColor = AppColors.errorRed;
      textColor = AppColors.textLight;
    } else if (isOutlined) {
      backgroundColor = Colors.transparent;
      borderColor = AppColors.primaryDark.withOpacity(0.5);
      textColor = AppColors.primary;
    } else {
      // Determine colors based on status string
      if (lowerStatus.contains('shortlisted') || lowerStatus.contains('accepted')) {
        backgroundColor = AppColors.successGreen.withOpacity(0.15);
        textColor = AppColors.successGreen;
      } else if (lowerStatus.contains('rejected') || lowerStatus.contains('closed')) {
        backgroundColor = AppColors.errorRed.withOpacity(0.15);
        textColor = AppColors.errorRed;
      } else if (lowerStatus.contains('pending') || lowerStatus.contains('new') || lowerStatus.contains('applied')) {
        backgroundColor = AppColors.warningAmber.withOpacity(0.15);
        textColor = AppColors.warningAmber;
      } else {
        // Default muted gray
        backgroundColor = AppColors.dividerDark;
        textColor = AppColors.textMutedLight;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
