import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/founder_providers.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../components/shared/initials_avatar.dart';
import '../../components/shared/match_score_badge.dart';
import '../../components/shared/skill_chip.dart';
import '../../services/notification_service.dart';
import '../shared/chat_conversation_screen.dart';
import '../shared/user_public_profile_screen.dart';

class FounderApplicantDetailScreen extends ConsumerStatefulWidget {
  final HydratedApplicant hydratedApplicant;

  const FounderApplicantDetailScreen({super.key, required this.hydratedApplicant});

  @override
  ConsumerState<FounderApplicantDetailScreen> createState() => _FounderApplicantDetailScreenState();
}

class _FounderApplicantDetailScreenState extends ConsumerState<FounderApplicantDetailScreen> {
  bool _isProcessing = false;

  Future<void> _updateApplicantStatus(String status) async {
    setState(() => _isProcessing = true);
    try {
      final docId = widget.hydratedApplicant.application.applicationId;
      await FirebaseFirestore.instance
          .collection('applications')
          .doc(docId)
          .update({'status': status});

      // Send status change notification to student
      final title = status == 'shortlisted' 
          ? 'Application Shortlisted! 🎉' 
          : status == 'hired' 
              ? 'Congratulations! You are Hired! 🥳' 
              : 'Application Update';
      final body = status == 'shortlisted'
          ? 'Great news! You have been shortlisted for the ${widget.hydratedApplicant.listing.title} role at ${widget.hydratedApplicant.listing.startupName}.'
          : status == 'hired'
              ? 'You have been selected for the ${widget.hydratedApplicant.listing.title} role at ${widget.hydratedApplicant.listing.startupName}! Check details.'
              : status == 'rejected'
                  ? 'Thank you for applying to ${widget.hydratedApplicant.listing.title} at ${widget.hydratedApplicant.listing.startupName}. Unfortunately, they have decided to proceed with other candidates.'
                  : 'Your application status has been updated to $status.';

      await NotificationService.sendNotification(
        userId: widget.hydratedApplicant.application.studentId,
        title: title,
        body: body,
        type: 'application_status',
        routeId: docId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Applicant status updated to $status!'),
          backgroundColor: status == 'hired' 
              ? AppColors.successGreen 
              : status == 'rejected' 
                  ? AppColors.errorRed 
                  : AppColors.primary,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e'), backgroundColor: AppColors.errorRed),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final applicant = widget.hydratedApplicant;
    final student = applicant.student;
    final app = applicant.application;
    final listing = applicant.listing;
    final founder = ref.watch(userStreamProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Applicant Profile'),
        actions: [
          if (founder != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  final chatId = await ref.read(chatServiceProvider).getOrCreateChat(
                    applicationId: app.applicationId,
                    listingId: listing.listingId,
                    studentId: student.userId,
                    founderId: founder.userId,
                    studentName: student.name,
                    founderName: founder.name,
                    listingTitle: listing.title,
                    studentPhotoUrl: student.profilePhotoUrl,
                    founderPhotoUrl: founder.profilePhotoUrl,
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatConversationScreen(
                          chatId: chatId,
                          chatTitle: student.name,
                          chatSubtitle: listing.title,
                          otherUserId: student.userId,
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to load chat: $e')),
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Student Header ──────────────────────────────────────
             Center(
               child: InkWell(
                 onTap: () => Navigator.push(
                   context,
                   MaterialPageRoute(
                     builder: (_) => UserPublicProfileScreen(userId: student.userId),
                   ),
                 ),
                 borderRadius: BorderRadius.circular(16),
                 child: Padding(
                   padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                   child: Column(
                     children: [
                       InitialsAvatar(
                         name: student.name,
                         radius: 52,
                         imageUrl: student.profilePhotoUrl,
                       ),
                       const SizedBox(height: 16),
                       Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           Text(student.name, style: Theme.of(context).textTheme.displaySmall),
                           const SizedBox(width: 6),
                           const Icon(Icons.open_in_new, size: 16, color: AppColors.textMutedLight),
                         ],
                       ),
                       const SizedBox(height: 6),
                       Text(
                         '${student.department ?? "Student"} · ${student.yearOfStudy ?? "1st"} Year',
                         style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textMutedLight),
                       ),
                       const SizedBox(height: 4),
                       Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           const Icon(Icons.location_city, size: 14, color: AppColors.primary),
                           const SizedBox(width: 4),
                           Text(student.university, style: const TextStyle(color: AppColors.primary, fontSize: 13)),
                         ],
                       ),
                       const SizedBox(height: 20),
                       // Stats row
                       Row(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           _ApplicantStat(value: '${student.skills.length}', label: 'Skills'),
                           Container(width: 1, height: 30, color: AppColors.dividerDark, margin: const EdgeInsets.symmetric(horizontal: 16)),
                           _ApplicantStat(value: student.yearOfStudy ?? '–', label: 'Year'),
                           Container(width: 1, height: 30, color: AppColors.dividerDark, margin: const EdgeInsets.symmetric(horizontal: 16)),
                           _ApplicantStat(
                             value: '${(app.matchScore * 100).round()}%',
                             label: 'Match',
                             valueColor: app.matchScore >= 0.7 ? AppColors.successGreen : app.matchScore >= 0.4 ? AppColors.warningAmber : AppColors.errorRed,
                           ),
                         ],
                       ),
                     ],
                   ),
                 ),
               ),
             ),
             const Divider(height: 48, color: AppColors.dividerDark),

            // Match Info Card
            Container(
              padding: const EdgeInsets.all(20),
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
                          Text('Role Fit Score', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(
                            'Applied to: ${listing.title}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMutedLight),
                          ),
                        ],
                      ),
                      MatchScoreBadge(score: app.matchScore, variant: MatchBadgeVariant.filled),
                    ],
                  ),
                  const Divider(height: 32, color: AppColors.dividerDark),

                  // Matched Skills
                  if (app.matchedSkills.isNotEmpty) ...[
                    Text('MATCHED SKILLS', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: app.matchedSkills.map((s) => SkillChip(
                        label: s,
                        variant: SkillChipVariant.matched,
                      )).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Missing Skills
                  if (app.missingSkills.isNotEmpty) ...[
                    Text('MISSING REQUIRED SKILLS', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMutedLight)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: app.missingSkills.map((s) => SkillChip(
                        label: s,
                        variant: SkillChipVariant.missing,
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ─── Student Bio ────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.person_outline, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text('About the Applicant', style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              student.bio?.isNotEmpty == true ? student.bio! : 'No bio added.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.5,
                color: student.bio?.isNotEmpty == true ? AppColors.textLight : AppColors.textMutedLight,
                fontStyle: student.bio?.isNotEmpty == true ? FontStyle.normal : FontStyle.italic,
              ),
            ),
            const Divider(height: 48, color: AppColors.dividerDark),

            // Resume Section
            if (app.resumeUrl != null || (student.resumeUrl != null && student.resumeUrl!.isNotEmpty)) ...[
              Text('Resume', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final resumeUrl = app.resumeUrl ?? student.resumeUrl!;
                  try {
                    final uri = Uri.parse(resumeUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      throw 'Could not launch $resumeUrl';
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to open resume: $e'), backgroundColor: AppColors.errorRed),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.dividerDark),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, color: AppColors.errorRed, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.resumeUrl != null ? 'custom_resume.pdf' : 'profile_resume.pdf',
                              style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              app.resumeUrl != null ? 'Specifically attached to this application' : 'Attached from student profile',
                              style: TextStyle(color: AppColors.textMutedLight, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        'View PDF',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.open_in_new, color: AppColors.primary, size: 16),
                    ],
                  ),
                ),
              ),
              const Divider(height: 48, color: AppColors.dividerDark),
            ],

            // ─── Cover Note ────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.format_quote, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text('Why They\'re a Great Fit', style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.format_quote, color: AppColors.primary, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    app.coverNote,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7, color: AppColors.textLight),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '— ${student.name}',
                      style: const TextStyle(color: AppColors.textMutedLight, fontStyle: FontStyle.italic, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 140), // Margin bottom for safe overlay buttons
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
            spacing: 12,
            children: [
              // Reject Button
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing || app.status == 'rejected'
                      ? null
                      : () => _updateApplicantStatus('rejected'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.errorRed,
                    side: const BorderSide(color: AppColors.errorRed),
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              
              // Shortlist/Hire conditional action
              if (app.status == 'pending')
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing 
                        ? null 
                        : () => _updateApplicantStatus('shortlisted'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: const Text('Shortlist', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
                  ),
                )
              else if (app.status == 'shortlisted')
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing 
                        ? null 
                        : () => _updateApplicantStatus('hired'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successGreen,
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: const Text('Hire 🎉', style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold)),
                  ),
                )
              else
                Expanded(
                  child: ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dividerDark,
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: Text(
                      app.status.toUpperCase(),
                      style: const TextStyle(color: AppColors.textMutedLight, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApplicantStat extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;

  const _ApplicantStat({required this.value, required this.label, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: valueColor ?? AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textMutedLight, fontSize: 11)),
      ],
    );
  }
}

