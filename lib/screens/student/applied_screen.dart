import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/applications_provider.dart';
import '../../theme/app_colors.dart';
import '../../components/shared/status_pill.dart';
import 'application_detail_screen.dart';

class StudentAppliedScreen extends ConsumerWidget {
  const StudentAppliedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(studentApplicationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Applications'),
      ),
      body: applicationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error loading applications: $err', style: const TextStyle(color: AppColors.errorRed)),
        ),
        data: (applications) {
          if (applications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_outlined, size: 64, color: AppColors.textMutedLight),
                  const SizedBox(height: 16),
                  Text('No Applications Yet', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('Your job/internship applications will appear here.', style: TextStyle(color: AppColors.textMutedLight)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: applications.length,
            itemBuilder: (context, index) {
              final app = applications[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentApplicationDetailScreen(application: app),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              app.startupName ?? 'Startup',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.primary,
                                letterSpacing: 1.0,
                              ),
                            ),
                            StatusPill(status: app.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          app.listingTitle ?? 'Role Application',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              app.compensationDetails ?? 'Paid',
                              style: const TextStyle(color: AppColors.successGreen, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Match: ${(app.matchScore * 100).round()}%',
                              style: const TextStyle(color: AppColors.textMutedLight),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
