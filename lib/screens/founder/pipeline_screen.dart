import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/founder_providers.dart';
import '../../theme/app_colors.dart';
import '../../components/shared/initials_avatar.dart';
import '../../components/shared/match_score_badge.dart';
import '../../components/shared/status_pill.dart';
import 'applicant_detail_screen.dart';

class FounderPipelineScreen extends ConsumerWidget {
  const FounderPipelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicantsAsync = ref.watch(founderApplicantsProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Applicant Pipeline'),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMutedLight,
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Shortlisted'),
              Tab(text: 'Outcomes'),
            ],
          ),
        ),
        body: applicantsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.errorRed))),
          data: (applicants) {
            final pending = applicants.where((a) => a.application.status == 'pending').toList();
            final shortlisted = applicants.where((a) => a.application.status == 'shortlisted').toList();
            final outcomes = applicants.where((a) => a.application.status == 'hired' || a.application.status == 'rejected').toList();

            return TabBarView(
              children: [
                _ApplicantList(applicants: pending),
                _ApplicantList(applicants: shortlisted),
                _ApplicantList(applicants: outcomes),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ApplicantList extends StatelessWidget {
  final List<HydratedApplicant> applicants;

  const _ApplicantList({required this.applicants});

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
    if (applicants.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: AppColors.textMutedLight),
            const SizedBox(height: 16),
            Text('No applicants in this stage', style: TextStyle(color: AppColors.textMutedLight)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: applicants.length,
      itemBuilder: (context, index) {
        final applicant = applicants[index];
        final student = applicant.student;
        final application = applicant.application;
        final listing = applicant.listing;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FounderApplicantDetailScreen(hydratedApplicant: applicant),
                ),
              );
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Student Name + University + Match Badge
                  Row(
                    children: [
                      InitialsAvatar(name: student.name, radius: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.name,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                            ),
                            Text(
                              '${student.university} · ${student.department ?? "Student"}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMutedLight),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      MatchScoreBadge(score: application.matchScore, variant: MatchBadgeVariant.filled),
                    ],
                  ),
                  const Divider(height: 32, color: AppColors.dividerDark),

                  // Applied Role + Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'APPLIED FOR',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMutedLight, letterSpacing: 1.0),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            listing.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
                      StatusPill(status: application.status),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Truncated Cover Note
                  Text(
                    'Cover Note Preview:',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMutedLight),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    application.coverNote,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4, color: AppColors.textLight.withOpacity(0.8)),
                  ),
                  
                  const SizedBox(height: 16),
                  Text(
                    'Applied ${_getRelativeTime(application.createdAt)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMutedLight, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
