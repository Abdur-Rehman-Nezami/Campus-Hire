import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../providers/networking_provider.dart';
import '../../theme/app_colors.dart';
import '../../components/shared/initials_avatar.dart';
import '../../components/shared/skill_chip.dart';

class UserPublicProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserPublicProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<UserPublicProfileScreen> createState() => _UserPublicProfileScreenState();
}

class _UserPublicProfileScreenState extends ConsumerState<UserPublicProfileScreen> {
  bool _isProcessing = false;

  Future<void> _toggleFollow(bool isFollowing, UserModel currentUser, UserModel targetUser) async {
    setState(() => _isProcessing = true);
    try {
      final service = ref.read(networkingServiceProvider);
      if (isFollowing) {
        await service.unfollowUser(
          currentUserId: currentUser.userId,
          targetUserId: targetUser.userId,
        );
      } else {
        await service.followUser(
          currentUserId: currentUser.userId,
          currentUserName: currentUser.name,
          targetUserId: targetUser.userId,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update follow status: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _viewResume(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open resume link.'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(userStreamProvider);
    final followingIdsAsync = ref.watch(followingIdsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final targetUser = UserModel.fromMap(
            snapshot.data!.data() as Map<String, dynamic>,
            snapshot.data!.id,
          );

          return currentUserAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (currentUser) {
              if (currentUser == null) return const SizedBox.shrink();

              final isFollowing = followingIdsAsync.value?.contains(targetUser.userId) ?? false;
              final isSelf = currentUser.userId == targetUser.userId;

              return SingleChildScrollView(
                child: Column(
                  children: [
                    // ─── Header Banner & Profile Pic ────────────────
                    Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: 140,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.cardDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 80,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.scaffoldBackground, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: InitialsAvatar(
                              name: targetUser.name,
                              radius: 54,
                              imageUrl: targetUser.profilePhotoUrl,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 70),

                    // Name & Title
                    Text(
                      targetUser.name,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      targetUser.role == 'founder'
                          ? 'Founder'
                          : '${targetUser.yearOfStudy ?? "Student"} · ${targetUser.department ?? ""}',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      targetUser.university,
                      style: const TextStyle(color: AppColors.textMutedLight, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Followers / Following Count Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.dividerDark),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatColumn(count: targetUser.followerCount, label: 'Followers'),
                          Container(height: 30, width: 1, color: AppColors.dividerDark),
                          _StatColumn(count: targetUser.followingCount, label: 'Following'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Follow/Unfollow Button (Only for peers / not self)
                    if (!isSelf) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : () => _toggleFollow(isFollowing, currentUser, targetUser),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFollowing ? AppColors.dividerDark : AppColors.primary,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isProcessing
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.textDark, strokeWidth: 2))
                              : Text(
                                  isFollowing ? 'Following' : 'Follow',
                                  style: TextStyle(
                                    color: isFollowing ? AppColors.textLight : AppColors.textDark,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Info sections
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Bio Section
                          if (targetUser.bio?.isNotEmpty == true) ...[
                            const Text('Bio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textLight)),
                            const SizedBox(height: 8),
                            Text(
                              targetUser.bio!,
                              style: const TextStyle(color: AppColors.textMutedLight, height: 1.5, fontSize: 14),
                            ),
                            const Divider(height: 32, color: AppColors.dividerDark),
                          ],

                          // Skills Section (if student)
                          if (targetUser.role == 'student' && targetUser.skills.isNotEmpty) ...[
                            const Text('Skills', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textLight)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: targetUser.skills.map((skill) => SkillChip(
                                label: skill,
                                variant: SkillChipVariant.matched,
                              )).toList(),
                            ),
                            const Divider(height: 32, color: AppColors.dividerDark),
                          ],

                          // Resume Section (if student and uploaded)
                          if (targetUser.role == 'student' && targetUser.resumeUrl?.isNotEmpty == true) ...[
                            const Text('Resume / CV', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textLight)),
                            const SizedBox(height: 12),
                            Container(
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
                                  const Expanded(
                                    child: Text('resume.pdf', style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold)),
                                  ),
                                  TextButton(
                                    onPressed: () => _viewResume(targetUser.resumeUrl!),
                                    child: const Text('View', style: TextStyle(color: AppColors.primary)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final int count;
  final String label;

  const _StatColumn({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textLight),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textMutedLight),
        ),
      ],
    );
  }
}
