import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/startup_model.dart';
import '../../models/listing_model.dart';
import '../../providers/listings_provider.dart';
import '../../theme/app_colors.dart';
import '../../components/shared/initials_avatar.dart';
import '../../components/shared/skill_chip.dart';
import '../../components/shared/match_score_badge.dart';
import '../../utils/match_utils.dart';
import '../../providers/user_provider.dart';
import '../../providers/networking_provider.dart';
import 'listing_detail_screen.dart';

class StartupPublicProfileScreen extends ConsumerWidget {
  final String startupId;

  const StartupPublicProfileScreen({super.key, required this.startupId});

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

  IconData _getSectorIcon(String? sector) {
    switch (sector?.toLowerCase()) {
      case 'edtech': return Icons.school_outlined;
      case 'fintech': return Icons.account_balance_outlined;
      case 'healthtech': return Icons.health_and_safety_outlined;
      case 'ai/ml': return Icons.psychology_outlined;
      case 'saas': return Icons.cloud_outlined;
      default: return Icons.business_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(userStreamProvider);
    final followedStartupIdsAsync = ref.watch(followedStartupIdsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Startup Profile'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('startups').doc(startupId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('Startup profile not found or deleted.', style: TextStyle(color: AppColors.textMutedLight)),
            );
          }

          final startupData = snapshot.data!.data() as Map<String, dynamic>;
          final startup = StartupModel.fromMap(startupData, snapshot.data!.id);
          final sectorColor = _getSectorColor(startup.sector);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Hero Banner ──────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        sectorColor.withValues(alpha: 0.15),
                        AppColors.scaffoldBackground,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Logo + name
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          InitialsAvatar(
                            name: startup.name,
                            radius: 52,
                            imageUrl: startup.logoUrl,
                            backgroundColor: sectorColor,
                            textColor: AppColors.textLight,
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: sectorColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.scaffoldBackground, width: 2),
                            ),
                            child: Icon(_getSectorIcon(startup.sector), color: sectorColor, size: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        startup.name,
                        style: Theme.of(context).textTheme.displaySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: sectorColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: sectorColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              startup.sector ?? 'Tech Startup',
                              style: TextStyle(color: sectorColor, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_city, size: 14, color: AppColors.textMutedLight),
                              const SizedBox(width: 4),
                              Text(
                                startup.university,
                                style: const TextStyle(color: AppColors.textMutedLight, fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Stat chips row
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('listings')
                            .where('startupId', isEqualTo: startupId)
                            .where('status', isEqualTo: 'open')
                            .snapshots(),
                        builder: (context, listSnap) {
                          final openRoles = listSnap.data?.docs.length ?? 0;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _StatBubble(value: '$openRoles', label: 'Open Roles'),
                              Container(width: 1, height: 32, color: AppColors.dividerDark, margin: const EdgeInsets.symmetric(horizontal: 16)),
                              _StatBubble(value: startup.sector, label: 'Sector'),
                              Container(width: 1, height: 32, color: AppColors.dividerDark, margin: const EdgeInsets.symmetric(horizontal: 16)),
                              _StatBubble(value: '${startup.followerCount}', label: 'Followers'),
                            ],
                          );
                        },
                      ),
                      
                      // Follow/Unfollow Startup Button
                      followedStartupIdsAsync.when(
                        loading: () => const SizedBox(height: 20),
                        error: (err, _) => const SizedBox.shrink(),
                        data: (followedIds) {
                          final isFollowing = followedIds.contains(startupId);
                          return studentAsync.when(
                            loading: () => const SizedBox.shrink(),
                            error: (err, _) => const SizedBox.shrink(),
                            data: (student) {
                              if (student == null || student.role != 'student') {
                                return const SizedBox.shrink();
                              }

                              return Padding(
                                padding: const EdgeInsets.only(top: 20.0),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final service = ref.read(networkingServiceProvider);
                                      if (isFollowing) {
                                        await service.unfollowStartup(
                                          userId: student.userId,
                                          startupId: startupId,
                                        );
                                      } else {
                                        await service.followStartup(
                                          userId: student.userId,
                                          startupId: startupId,
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isFollowing ? AppColors.dividerDark : AppColors.primary,
                                      foregroundColor: isFollowing ? AppColors.textLight : AppColors.textDark,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: Icon(isFollowing ? Icons.check : Icons.add, size: 18),
                                    label: Text(
                                      isFollowing ? 'Following Startup' : 'Follow Startup',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── About Section ──────────────────────────────────
                      Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.primary, size: 22),
                          const SizedBox(width: 8),
                          Text('About', style: Theme.of(context).textTheme.headlineSmall),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        startup.description?.isNotEmpty == true
                            ? startup.description!
                            : 'No startup overview provided yet.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.7,
                          color: startup.description?.isNotEmpty == true
                              ? AppColors.textLight
                              : AppColors.textMutedLight,
                          fontStyle: startup.description?.isNotEmpty == true
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ─── What Makes Us Different ─────────────────────────
                      Row(
                        children: [
                          const Icon(Icons.rocket_launch_outlined, color: AppColors.primary, size: 22),
                          const SizedBox(width: 8),
                          Text('Why Join Us?', style: Theme.of(context).textTheme.headlineSmall),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...(_getWhyJoinItems(startup.sector)).map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 14.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: sectorColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(item.icon, size: 14, color: sectorColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title, style: const TextStyle(
                                    color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 14,
                                  )),
                                  const SizedBox(height: 2),
                                  Text(item.subtitle, style: const TextStyle(
                                    color: AppColors.textMutedLight, fontSize: 13, height: 1.4,
                                  )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 16),
                      const Divider(color: AppColors.dividerDark),
                      const SizedBox(height: 24),

                      // ─── Active Listings ──────────────────────────────────
                      Row(
                        children: [
                          const Icon(Icons.work_outline, color: AppColors.primary, size: 22),
                          const SizedBox(width: 8),
                          Text('Open Roles', style: Theme.of(context).textTheme.headlineSmall),
                        ],
                      ),
                      const SizedBox(height: 16),

                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('listings')
                            .where('startupId', isEqualTo: startupId)
                            .where('status', isEqualTo: 'open')
                            .snapshots(),
                        builder: (context, listingsSnapshot) {
                          if (listingsSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!listingsSnapshot.hasData || listingsSnapshot.data!.docs.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppColors.cardDark,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.dividerDark),
                              ),
                              child: const Center(
                                child: Text(
                                  'No active openings at this moment.\nCheck back soon!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textMutedLight, height: 1.5),
                                ),
                              ),
                            );
                          }

                          final listings = listingsSnapshot.data!.docs
                              .map((doc) => ListingModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                              .toList();

                          return studentAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (err, _) => Text('Error: $err'),
                            data: (student) {
                              final studentSkills = student?.skills ?? [];

                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: listings.length,
                                itemBuilder: (context, index) {
                                  final listing = listings[index];
                                  final match = computeMatch(studentSkills, listing.requiredSkills);
                                  final matchScore = match['score'] as double;
                                  final matchedSkills = List<String>.from(match['matchedSkills']);
                                  final missingSkills = List<String>.from(match['missingSkills']);

                                  final matchedListing = MatchedListing(
                                    listing: listing,
                                    score: matchScore,
                                    matchedSkills: matchedSkills,
                                    missingSkills: missingSkills,
                                  );

                                  final daysLeft = listing.deadline.difference(DateTime.now()).inDays;
                                  final isUrgent = daysLeft >= 0 && daysLeft <= 3;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    child: InkWell(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => StudentListingDetailScreen(matchedListing: matchedListing),
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      child: Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Top row: type + score
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.primary.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        listing.type.toUpperCase(),
                                                        style: const TextStyle(
                                                          color: AppColors.primary,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ),
                                                    if (isUrgent) ...[
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: AppColors.errorRed.withValues(alpha: 0.1),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Text(
                                                          daysLeft == 0 ? 'CLOSES TODAY' : 'CLOSES IN $daysLeft DAYS',
                                                          style: const TextStyle(
                                                            color: AppColors.errorRed,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                MatchScoreBadge(score: matchScore, variant: MatchBadgeVariant.filled),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Text(listing.title, style: Theme.of(context).textTheme.titleLarge),
                                            const SizedBox(height: 8),
                                            // Meta info
                                            Row(
                                              children: [
                                                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMutedLight),
                                                const SizedBox(width: 4),
                                                Text(listing.locationType.toUpperCase(),
                                                    style: const TextStyle(color: AppColors.textMutedLight, fontSize: 12)),
                                                const SizedBox(width: 12),
                                                const Icon(Icons.payments_outlined, size: 14, color: AppColors.successGreen),
                                                const SizedBox(width: 4),
                                                Text(
                                                  listing.compensationDetails ?? listing.compensationType,
                                                  style: const TextStyle(color: AppColors.successGreen, fontSize: 12, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: listing.requiredSkills.map((s) => SkillChip(
                                                label: s,
                                                variant: matchedSkills.contains(s)
                                                    ? SkillChipVariant.matched
                                                    : SkillChipVariant.neutral,
                                              )).toList(),
                                            ),
                                            const SizedBox(height: 12),
                                            // Deadline
                                            Text(
                                              'Deadline: ${DateFormat('MMM d, yyyy').format(listing.deadline)}',
                                              style: const TextStyle(color: AppColors.textMutedLight, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_WhyJoinItem> _getWhyJoinItems(String? sector) {
    return [
      _WhyJoinItem(
        icon: Icons.rocket_launch_outlined,
        title: 'Real-World Impact',
        subtitle: 'Ship actual features used by thousands of campus students, not just mockups.',
      ),
      _WhyJoinItem(
        icon: Icons.people_alt_outlined,
        title: 'Mentorship from Founders',
        subtitle: 'Work directly with the founding team and get personalized guidance on your career.',
      ),
      _WhyJoinItem(
        icon: Icons.workspace_premium_outlined,
        title: 'Letter of Recommendation',
        subtitle: 'Earn a verified letter after successful internship or employment tenure.',
      ),
      _WhyJoinItem(
        icon: Icons.trending_up,
        title: 'Career Acceleration',
        subtitle: 'Build a standout portfolio with real startup experience that employers recognize.',
      ),
    ];
  }
}

class _WhyJoinItem {
  final IconData icon;
  final String title;
  final String subtitle;
  const _WhyJoinItem({required this.icon, required this.title, required this.subtitle});
}

class _StatBubble extends StatelessWidget {
  final String value;
  final String label;
  const _StatBubble({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.primary, fontWeight: FontWeight.bold,
        )),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textMutedLight, fontSize: 11)),
      ],
    );
  }
}
