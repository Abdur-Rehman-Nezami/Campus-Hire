import 'package:flutter/material.dart';
import '../../models/listing_model.dart';
import '../../theme/app_colors.dart';
import '../shared/initials_avatar.dart';
import '../shared/match_score_badge.dart';
import '../shared/skill_chip.dart';
import '../shared/status_pill.dart';

class ListingCard extends StatelessWidget {
  final ListingModel listing;
  final double matchScore;
  final List<String> matchedSkills;

  const ListingCard({
    super.key,
    required this.listing,
    required this.matchScore,
    this.matchedSkills = const [],
  });

  Color _getSectorColor(String? sector) {
    switch (sector?.toLowerCase()) {
      case 'edtech':
        return AppColors.primary;
      case 'fintech':
        return AppColors.successGreen;
      case 'healthtech':
        return AppColors.errorRed;
      case 'ai/ml':
        return Colors.teal;
      case 'saas':
        return Colors.blue;
      default:
        return AppColors.dividerDark;
    }
  }

  String _getRelativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 7) {
      return '${(diff.inDays / 7).round()}w ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else {
      return 'just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Startup Name + University + Score Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InitialsAvatar(
                  name: listing.startupName ?? 'S',
                  radius: 20,
                  backgroundColor: _getSectorColor(listing.startupSector),
                  textColor: AppColors.textLight,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.startupName ?? 'Campus Venture',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.textMutedDark,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        listing.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.textDark,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                MatchScoreBadge(
                  score: matchScore, 
                  variant: MatchBadgeVariant.filled,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Skills Row
            if (matchedSkills.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...matchedSkills.take(3).map((skill) => SkillChip(
                    label: skill,
                    variant: SkillChipVariant.neutral, // Neutral outline on light card
                  )),
                  if (matchedSkills.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0, left: 4.0),
                      child: Text(
                        '+${matchedSkills.length - 3} more',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMutedDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            // Details Row
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textMutedDark),
                const SizedBox(width: 4),
                Text(
                  _getRelativeTime(listing.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMutedDark,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.payments_outlined, size: 14, color: AppColors.successGreen),
                const SizedBox(width: 4),
                Text(
                  listing.compensationDetails ?? listing.compensationType.toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.successGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (listing.deadline.difference(DateTime.now()).inDays < 3)
                  const StatusPill(status: 'URGENT', isSolid: true)
                else
                  const Icon(Icons.arrow_forward, size: 16, color: AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
