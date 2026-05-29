import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/application_model.dart';
import '../../theme/app_colors.dart';
import '../../components/shared/match_score_badge.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../shared/chat_conversation_screen.dart';

class StudentApplicationDetailScreen extends ConsumerWidget {
  final ApplicationModel application;

  const StudentApplicationDetailScreen({super.key, required this.application});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userStreamProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Detail'),
        actions: [
          if (user != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () async {
                // Show loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  // Fetch the listing to retrieve founderId
                  final listingDoc = await FirebaseFirestore.instance
                      .collection('listings')
                      .doc(application.listingId)
                      .get();
                  
                  final founderId = listingDoc.data()?['founderId'] ?? '';
                  final listingTitle = listingDoc.data()?['title'] ?? 'Role Application';

                  // Initialize or fetch chat
                  final chatId = await ref.read(chatServiceProvider).getOrCreateChat(
                    applicationId: application.applicationId,
                    listingId: application.listingId,
                    studentId: user.userId,
                    founderId: founderId,
                    studentName: user.name,
                    founderName: application.startupName ?? 'Startup Founder',
                    listingTitle: listingTitle,
                    studentPhotoUrl: user.profilePhotoUrl,
                  );

                  if (context.mounted) {
                    Navigator.pop(context); // Dismiss loading dialog
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatConversationScreen(
                          chatId: chatId,
                          chatTitle: application.startupName ?? 'Startup Founder',
                          chatSubtitle: listingTitle,
                          otherUserId: founderId,
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context); // Dismiss loading dialog
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
            // Header Info
            Text(
              application.startupName ?? 'Startup',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
                letterSpacing: 1.2,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              application.listingTitle ?? 'Role Application',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 24),

            // Match details row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Skills Match Score', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${application.matchedSkills.length} matching skills',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMutedLight),
                    ),
                  ],
                ),
                MatchScoreBadge(score: application.matchScore, variant: MatchBadgeVariant.filled),
              ],
            ),
            const Divider(height: 48, color: AppColors.dividerDark),

            // Dynamic Progress Timeline (Step 7)
            Text('Application Timeline', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            _TimelineView(status: application.status),
            const Divider(height: 48, color: AppColors.dividerDark),

            // Submitted Cover Note
            Text('Your Cover Note', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.dividerDark),
              ),
              child: Text(
                application.coverNote,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                  color: AppColors.textLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineView extends StatelessWidget {
  final String status;

  const _TimelineView({required this.status});

  @override
  Widget build(BuildContext context) {
    // 3 Steps: 1. Applied, 2. Under Review/Shortlisted, 3. Final Outcome
    final step1Completed = true;
    final step2Completed = status == 'shortlisted' || status == 'hired' || status == 'rejected';
    final step3Completed = status == 'hired' || status == 'rejected';
    
    String step2Title = 'Under Review';
    if (status == 'shortlisted') step2Title = 'Shortlisted';
    
    String step3Title = 'Outcome';
    Color step3Color = AppColors.primary;
    IconData step3Icon = Icons.stars;
    
    if (status == 'hired') {
      step3Title = 'Hired 🎉';
      step3Color = AppColors.successGreen;
      step3Icon = Icons.check_circle;
    } else if (status == 'rejected') {
      step3Title = 'Rejected';
      step3Color = AppColors.errorRed;
      step3Icon = Icons.cancel;
    }

    return Column(
      children: [
        _buildTimelineStep(
          context: context,
          title: 'Application Submitted',
          subtitle: 'Startup notified of your match details.',
          isDone: step1Completed,
          isActive: true,
          isLast: false,
        ),
        _buildTimelineStep(
          context: context,
          title: step2Title,
          subtitle: status == 'shortlisted' 
              ? 'Congratulations! You are shortlisted for interviews.'
              : 'Founder is reviewing your profile and skills match.',
          isDone: step2Completed,
          isActive: status == 'pending' || status == 'shortlisted',
          isLast: false,
        ),
        _buildTimelineStep(
          context: context,
          title: step3Title,
          subtitle: status == 'hired' 
              ? 'Awesome! The startup has offered you this role.' 
              : status == 'rejected'
                  ? 'Thank you for your time. StartupNest decided to move forward with other candidates.'
                  : 'Pending final feedback/interview.',
          isDone: status == 'hired',
          isRejected: status == 'rejected',
          isActive: step3Completed,
          isLast: true,
          customIcon: step3Completed ? step3Icon : null,
          customColor: step3Completed ? step3Color : null,
        ),
      ],
    );
  }

  Widget _buildTimelineStep({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool isDone,
    required bool isActive,
    required bool isLast,
    bool isRejected = false,
    IconData? customIcon,
    Color? customColor,
  }) {
    Color dotColor = AppColors.dividerDark;
    Widget dotWidget = Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground,
        border: Border.all(color: AppColors.dividerDark, width: 2),
        shape: BoxShape.circle,
      ),
    );

    if (isDone) {
      dotColor = customColor ?? AppColors.successGreen;
      dotWidget = Icon(customIcon ?? Icons.check_circle, color: dotColor, size: 24);
    } else if (isRejected) {
      dotColor = AppColors.errorRed;
      dotWidget = Icon(Icons.cancel, color: dotColor, size: 24);
    } else if (isActive) {
      dotColor = AppColors.primary;
      dotWidget = Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.scaffoldBackground,
          border: Border.all(color: AppColors.primary, width: 2),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dot and Line
          Column(
            children: [
              dotWidget,
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDone ? (customColor ?? AppColors.successGreen) : AppColors.dividerDark,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isRejected 
                          ? AppColors.errorRed 
                          : isDone 
                              ? (customColor ?? AppColors.successGreen) 
                              : isActive 
                                  ? AppColors.primary 
                                  : AppColors.textMutedLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMutedLight,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
