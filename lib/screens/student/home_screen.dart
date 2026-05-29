import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../components/shared/initials_avatar.dart';
import '../../providers/user_provider.dart';
import '../../providers/notification_provider.dart';
import '../shared/notifications_hub_screen.dart';

class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userStreamProvider);
    final unreadCount = ref.watch(unreadNotificationsCountStreamProvider).value ?? 0;
    
    final user = userAsync.value;
    final userName = user?.name ?? 'Student';
    final firstName = userName.split(' ').first;
    
    final formattedDate = DateFormat('EEE, MMM d').format(DateTime.now()).toUpperCase();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formattedDate,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            style: Theme.of(context).textTheme.displaySmall,
                            children: [
                              const TextSpan(text: 'Good morning,\n'),
                              TextSpan(
                                text: firstName,
                                style: const TextStyle(color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_none, color: AppColors.textLight, size: 28),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const NotificationsHubScreen()),
                              );
                            },
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  unreadCount > 9 ? '9+' : '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      InitialsAvatar(
                        name: userName,
                        imageUrl: user?.profilePhotoUrl,
                        radius: 28,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Stat Row
              Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: _StatCard(
                      value: '8',
                      label: 'Matches',
                      borderColor: AppColors.primary,
                    ),
                  ),
                  Expanded(
                    child: _StatCard(
                      value: '4',
                      label: 'Applied',
                      borderColor: AppColors.successGreen,
                    ),
                  ),
                  Expanded(
                    child: _StatCard(
                      value: '2',
                      label: 'Shortlisted',
                      borderColor: Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Perfect Matches Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Perfect matches', style: Theme.of(context).textTheme.headlineSmall),
                  TextButton(
                    onPressed: () {},
                    child: const Text('See all', style: TextStyle(color: AppColors.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Horizontal high match card list
              SizedBox(
                height: 140,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 2,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return const _HorizontalMatchCard(
                        startup: 'TECHLAB COMSATS',
                        role: 'Flutter Developer',
                        score: '80%',
                        isDark: true,
                      );
                    }
                    return const _HorizontalMatchCard(
                      startup: 'C-APPS',
                      role: 'Backend Engineer (Node)',
                      score: '90%',
                      isDark: false,
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              
              // New on Campus Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('New on campus', style: Theme.of(context).textTheme.headlineSmall),
                  TextButton(
                    onPressed: () {},
                    child: const Text('See all', style: TextStyle(color: AppColors.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              SizedBox(
                height: 140,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 2,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return const _HorizontalMatchCard(
                        startup: 'UNIDESIGN CO.',
                        role: 'UI/UX Designer',
                        score: '60%',
                        isDark: false,
                      );
                    }
                    return const _HorizontalMatchCard(
                      startup: 'STARTUPNEST',
                      role: 'Social Media Manager',
                      score: '45%',
                      isDark: false,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color borderColor;

  const _StatCard({
    required this.value,
    required this.label,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: borderColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textMutedLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalMatchCard extends StatelessWidget {
  final String startup;
  final String role;
  final String score;
  final bool isDark;

  const _HorizontalMatchCard({
    required this.startup,
    required this.role,
    required this.score,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.dividerDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            startup,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isDark ? AppColors.textMutedLight : AppColors.textMutedDark,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              role,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isDark ? AppColors.textLight : AppColors.textDark,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              score,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
