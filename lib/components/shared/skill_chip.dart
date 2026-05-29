import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

enum SkillChipVariant { neutral, selected, matched, missing }

class SkillChip extends StatelessWidget {
  final String label;
  final SkillChipVariant variant;
  final VoidCallback? onTap;

  const SkillChip({
    super.key,
    required this.label,
    this.variant = SkillChipVariant.neutral,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color borderColor;
    Color textColor;

    switch (variant) {
      case SkillChipVariant.selected:
        backgroundColor = AppColors.primary;
        borderColor = AppColors.primary;
        textColor = AppColors.textDark;
        break;
      case SkillChipVariant.matched:
        backgroundColor = AppColors.successGreen.withOpacity(0.2);
        borderColor = AppColors.successGreen;
        textColor = AppColors.successGreen;
        break;
      case SkillChipVariant.missing:
        backgroundColor = AppColors.errorRed.withOpacity(0.1);
        borderColor = AppColors.errorRed.withOpacity(0.5);
        textColor = AppColors.errorRed;
        break;
      case SkillChipVariant.neutral:
      default:
        // Use default theme or explicit outline based on context
        backgroundColor = Colors.transparent;
        borderColor = AppColors.dividerDark;
        textColor = AppColors.textMutedLight;
        break;
    }

    // Attempt to detect if we're on a light background implicitly by Theme
    final isLightBackground = Theme.of(context).cardTheme.color == AppColors.cardLight;
    if (variant == SkillChipVariant.neutral && isLightBackground) {
       borderColor = AppColors.dividerLight;
       textColor = AppColors.textMutedDark;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: textColor,
              fontWeight: variant == SkillChipVariant.neutral ? FontWeight.normal : FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
