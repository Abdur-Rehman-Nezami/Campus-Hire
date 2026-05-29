import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/listings_provider.dart';
import '../../providers/applications_provider.dart';
import '../../theme/app_colors.dart';
import '../../components/shared/initials_avatar.dart';
import '../../components/shared/match_score_badge.dart';
import '../../components/shared/skill_chip.dart';
import 'apply_bottom_sheet.dart';
import 'startup_profile_screen.dart';

import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../shared/chat_conversation_screen.dart';

class StudentListingDetailScreen extends ConsumerWidget {
  final MatchedListing matchedListing;

  const StudentListingDetailScreen({super.key, required this.matchedListing});

  Color _getSectorColor(String? sector) {
    switch (sector?.toLowerCase()) {
      case 'edtech': return AppColors.primary;
      case 'fintech': return AppColors.successGreen;
      case 'healthtech': return AppColors.errorRed;
      case 'ai/ml': return Colors.teal;
      case 'saas': return Colors.blue;
      default: return AppColors.dividerDark;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'internship': return Icons.school_outlined;
      case 'job': return Icons.work_outline;
      case 'cofounding': return Icons.rocket_launch_outlined;
      case 'partnership': return Icons.handshake_outlined;
      default: return Icons.work_outline;
    }
  }

  IconData _getLocationIcon(String locationType) {
    switch (locationType.toLowerCase()) {
      case 'remote': return Icons.laptop_outlined;
      case 'on-site': return Icons.location_on_outlined;
      case 'hybrid': return Icons.swap_horiz;
      default: return Icons.location_on_outlined;
    }
  }

  String _formatDeadline(DateTime deadline) {
    final diff = deadline.difference(DateTime.now());
    if (diff.isNegative) return 'Deadline passed';
    if (diff.inDays == 0) return 'Closes today!';
    if (diff.inDays == 1) return 'Closes tomorrow';
    if (diff.inDays <= 7) return 'Closes in ${diff.inDays} days';
    return 'Deadline: ${DateFormat('MMM d, yyyy').format(deadline)}';
  }

  bool _isUrgent(DateTime deadline) {
    final diff = deadline.difference(DateTime.now());
    return !diff.isNegative && diff.inDays <= 3;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listing = matchedListing.listing;
    final hasApplied = ref.watch(hasAppliedToListingProvider(listing.listingId));
    final application = ref.watch(studentApplicationForListingProvider(listing.listingId));
    final user = ref.watch(userStreamProvider).value;
    final isUrgent = _isUrgent(listing.deadline);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Role Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Startup Header (tappable) ──────────────────────────
            GestureDetector(
              onTap: () {
                if (listing.startupId.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StartupPublicProfileScreen(startupId: listing.startupId),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.dividerDark),
                ),
                child: Row(
                  children: [
                    InitialsAvatar(
                      name: listing.startupName ?? 'S',
                      radius: 30,
                      backgroundColor: _getSectorColor(listing.startupSector),
                      textColor: AppColors.textLight,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                listing.startupName ?? 'Startup',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textMutedLight),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${listing.startupSector ?? "General"} · ${listing.university ?? "University"}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMutedLight),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getSectorColor(listing.startupSector).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        listing.startupSector ?? 'Tech',
                        style: TextStyle(
                          color: _getSectorColor(listing.startupSector),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ─── Role Title & Status Badges ────────────────────────
            Text(listing.title, style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: _getTypeIcon(listing.type),
                  label: listing.type.toUpperCase(),
                  color: AppColors.primary,
                ),
                _InfoChip(
                  icon: _getLocationIcon(listing.locationType),
                  label: listing.locationType.toUpperCase(),
                  color: AppColors.textMutedLight,
                ),
                _InfoChip(
                  icon: Icons.payments_outlined,
                  label: listing.compensationDetails ?? listing.compensationType.toUpperCase(),
                  color: AppColors.successGreen,
                ),
                _InfoChip(
                  icon: isUrgent ? Icons.alarm : Icons.calendar_today_outlined,
                  label: _formatDeadline(listing.deadline),
                  color: isUrgent ? AppColors.errorRed : AppColors.textMutedLight,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ─── Match Score Card ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.dividerDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your Match Score', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(
                            '${matchedListing.matchedSkills.length} of ${listing.requiredSkills.length} skills matched',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMutedLight),
                          ),
                        ],
                      ),
                      MatchScoreBadge(score: matchedListing.score, variant: MatchBadgeVariant.filled),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: matchedListing.score,
                      minHeight: 8,
                      backgroundColor: AppColors.dividerDark,
                      color: matchedListing.score >= 0.7
                          ? AppColors.successGreen
                          : matchedListing.score >= 0.4
                              ? AppColors.warningAmber
                              : AppColors.errorRed,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (matchedListing.matchedSkills.isNotEmpty) ...[
                    Text('MATCHED SKILLS', style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.successGreen, letterSpacing: 1.0,
                    )),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: matchedListing.matchedSkills.map((s) => SkillChip(
                        label: s, variant: SkillChipVariant.matched,
                      )).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (matchedListing.missingSkills.isNotEmpty) ...[
                    Text('SKILLS TO DEVELOP', style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.errorRed, letterSpacing: 1.0,
                    )),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: matchedListing.missingSkills.map((s) => SkillChip(
                        label: s, variant: SkillChipVariant.missing,
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ─── About the Role ────────────────────────────────────
            Text('About the Role', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              listing.description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.7,
                color: AppColors.textMutedLight,
              ),
            ),
            const SizedBox(height: 32),

            // ─── Responsibilities ──────────────────────────────────
            Text('What You\'ll Do', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            ..._getResponsibilities(listing.type, listing.title).map((item) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textLight,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ─── Perks Section ─────────────────────────────────────
            Text('Perks & Benefits', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _getPerks(listing.compensationType, listing.locationType).map((perk) =>
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.dividerDark),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(perk.icon, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        perk.label,
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ).toList(),
            ),
            const SizedBox(height: 32),

            // ─── Required Skills Full List ─────────────────────────
            Text('Required Skills', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: listing.requiredSkills.map((s) => SkillChip(
                label: s,
                variant: matchedListing.matchedSkills.contains(s)
                    ? SkillChipVariant.matched
                    : SkillChipVariant.missing,
              )).toList(),
            ),

            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(
          color: AppColors.scaffoldBackground,
          border: Border(top: BorderSide(color: AppColors.dividerDark)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              if (hasApplied && application != null && user != null) ...[
                OutlinedButton(
                  onPressed: () async {
                    final chatId = await ref.read(chatServiceProvider).getOrCreateChat(
                      applicationId: application.applicationId,
                      listingId: listing.listingId,
                      studentId: user.userId,
                      founderId: listing.founderId,
                      studentName: user.name,
                      founderName: listing.startupName ?? 'Startup Founder',
                      listingTitle: listing.title,
                      studentPhotoUrl: user.profilePhotoUrl,
                    );

                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatConversationScreen(
                            chatId: chatId,
                            chatTitle: listing.startupName ?? 'Startup Founder',
                            chatSubtitle: listing.title,
                            otherUserId: listing.founderId,
                          ),
                        ),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(56, 56),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: hasApplied
                      ? null
                      : () async {
                          await showModalBottomSheet<bool>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => ApplyBottomSheet(matchedListing: matchedListing),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: hasApplied ? AppColors.dividerDark : AppColors.primary,
                  ),
                  child: Text(
                    hasApplied ? '✓ Applied' : 'Apply Now',
                    style: TextStyle(
                      color: hasApplied ? AppColors.textMutedLight : AppColors.textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _getResponsibilities(String type, String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('flutter') || lowerTitle.contains('mobile')) {
      return [
        'Build and maintain cross-platform mobile screens using Flutter & Dart',
        'Integrate Firebase Auth, Firestore, and Storage with reactive providers',
        'Collaborate with designers to implement pixel-perfect UI from Figma specs',
        'Write clean, maintainable code with proper state management (Riverpod/Bloc)',
        'Participate in code reviews and bi-weekly sprint retrospectives',
      ];
    } else if (lowerTitle.contains('backend') || lowerTitle.contains('node')) {
      return [
        'Design and scale RESTful APIs using Node.js and Express',
        'Optimize PostgreSQL queries and manage database schema migrations',
        'Containerize services using Docker and manage deployment pipelines',
        'Implement authentication flows, rate limiting, and security best practices',
        'Collaborate with frontend teams to define API contracts and data models',
      ];
    } else if (lowerTitle.contains('design') || lowerTitle.contains('ui') || lowerTitle.contains('ux')) {
      return [
        'Create wireframes, user flows, and high-fidelity prototypes in Figma',
        'Design and maintain a component-based design system for consistent UX',
        'Conduct user research and translate insights into actionable design decisions',
        'Work with developers to ensure accurate implementation of designs',
        'Iterate based on user feedback and A/B testing results',
      ];
    } else if (lowerTitle.contains('social') || lowerTitle.contains('marketing')) {
      return [
        'Develop and schedule weekly content for LinkedIn, Instagram, and Twitter',
        'Design engaging social graphics using Canva or Adobe Illustrator',
        'Track and report campaign performance metrics (reach, engagement, CTR)',
        'Write compelling product copy, newsletters, and blog posts',
        'Coordinate with founders to align content with product launch timelines',
      ];
    }
    return [
      'Contribute to the team\'s core product roadmap with a high sense of ownership',
      'Collaborate across functions to solve real user problems effectively',
      'Participate in bi-weekly team syncs, demos, and product retrospectives',
      'Bring fresh ideas and perspectives to the team culture',
    ];
  }

  List<_Perk> _getPerks(String compensationType, String locationType) {
    final perks = <_Perk>[];
    if (compensationType == 'paid') {
      perks.add(_Perk(Icons.attach_money, 'Monthly Stipend'));
    } else if (compensationType == 'equity') {
      perks.add(_Perk(Icons.pie_chart_outline, 'Equity Option'));
    } else if (compensationType == 'unpaid') {
      perks.add(_Perk(Icons.workspace_premium_outlined, 'Certificate & LOR'));
    } else {
      perks.add(_Perk(Icons.handshake_outlined, 'Negotiable Pay'));
    }
    if (locationType == 'remote') {
      perks.add(_Perk(Icons.laptop_outlined, 'Fully Remote'));
    } else if (locationType == 'hybrid') {
      perks.add(_Perk(Icons.swap_horiz, 'Hybrid Schedule'));
    } else {
      perks.add(_Perk(Icons.location_on_outlined, 'On-Campus Office'));
    }
    perks.addAll([
      _Perk(Icons.people_outline, 'Mentorship from Founders'),
      _Perk(Icons.description_outlined, 'Letter of Recommendation'),
      _Perk(Icons.rocket_launch_outlined, 'Real Startup Experience'),
    ]);
    return perks;
  }
}

class _Perk {
  final IconData icon;
  final String label;
  const _Perk(this.icon, this.label);
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
