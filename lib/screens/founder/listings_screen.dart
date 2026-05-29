import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/founder_providers.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_colors.dart';
import '../../components/shared/status_pill.dart';
import '../../components/shared/skill_chip.dart';
import '../shared/notifications_hub_screen.dart';
import 'post_listing_screen.dart';

class FounderListingsScreen extends ConsumerWidget {
  const FounderListingsScreen({super.key});

  Future<void> _toggleListingStatus(BuildContext context, String docId, String currentStatus) async {
    final newStatus = currentStatus == 'open' ? 'paused' : 'open';
    try {
      await FirebaseFirestore.instance
          .collection('listings')
          .doc(docId)
          .update({'status': newStatus});
          
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Listing is now $newStatus!'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(founderListingsProvider);
    final unreadCount = ref.watch(unreadNotificationsCountStreamProvider).value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Listings'),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, size: 28),
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
          const SizedBox(width: 16),
        ],
      ),
      body: listingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error: $err', style: const TextStyle(color: AppColors.errorRed)),
        ),
        data: (listings) {
          if (listings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.work_outline, size: 64, color: AppColors.textMutedLight),
                  const SizedBox(height: 16),
                  Text('No roles posted yet', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('Tap the button below to post your first campus role!', style: TextStyle(color: AppColors.textMutedLight)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: listings.length,
            itemBuilder: (context, index) {
              final listing = listings[index];
              final isClosed = listing.status == 'closed';
              final isPaused = listing.status == 'paused';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          StatusPill(status: listing.status.toUpperCase(), isSolid: listing.status == 'open'),
                          Text(
                            listing.type.toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        listing.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      
                      // Skills tags list
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: listing.requiredSkills.map((s) => SkillChip(
                          label: s,
                          variant: SkillChipVariant.neutral,
                        )).toList(),
                      ),
                      const Divider(height: 32, color: AppColors.dividerDark),

                      // Footer Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            listing.compensationDetails ?? listing.compensationType.toUpperCase(),
                            style: const TextStyle(color: AppColors.successGreen, fontWeight: FontWeight.bold),
                          ),
                          
                          // Toggle Status Actions
                          Row(
                            children: [
                              TextButton(
                                onPressed: isClosed 
                                    ? null 
                                    : () => _toggleListingStatus(context, listing.listingId, listing.status),
                                child: Text(isPaused ? 'Resume' : 'Pause', style: const TextStyle(color: AppColors.primary)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.archive_outlined, color: AppColors.errorRed),
                                onPressed: isClosed ? null : () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Close Listing?'),
                                      content: const Text('This will close applications and hide it from student feeds permanently.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true), 
                                          style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  );
                                  
                                  if (confirm == true && context.mounted) {
                                    await FirebaseFirestore.instance
                                        .collection('listings')
                                        .doc(listing.listingId)
                                        .update({'status': 'closed'});
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textDark,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FounderPostListingScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
