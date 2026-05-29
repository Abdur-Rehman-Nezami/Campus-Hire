import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../providers/networking_provider.dart';
import '../../theme/app_colors.dart';
import '../../components/shared/initials_avatar.dart';
import '../shared/user_public_profile_screen.dart';

class NetworkingHubScreen extends ConsumerStatefulWidget {
  const NetworkingHubScreen({super.key});

  @override
  ConsumerState<NetworkingHubScreen> createState() => _NetworkingHubScreenState();
}

class _NetworkingHubScreenState extends ConsumerState<NetworkingHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recommendationsAsync = ref.watch(peerRecommendationsProvider);
    final currentUserAsync = ref.watch(userStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Network'),
      ),
      body: currentUserAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (currentUser) {
          if (currentUser == null) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Suggestions Section (People You May Know) ─────────
              recommendationsAsync.when(
                loading: () => const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => const SizedBox.shrink(),
                data: (peers) {
                  if (peers.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 20, 24, 12),
                        child: Text(
                          'People you may know on campus 👤',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textLight,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 185,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: peers.length,
                          itemBuilder: (context, index) {
                            final peer = peers[index];
                            return _RecommendationCard(peer: peer, currentUser: currentUser);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(color: AppColors.dividerDark, height: 1),
                    ],
                  );
                },
              ),

              // ─── Tab Bar (Following / Followers) ───────────────────
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMutedLight,
                tabs: const [
                  Tab(text: 'Following'),
                  Tab(text: 'Followers'),
                ],
              ),

              // Tab View
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _FollowingTab(currentUser: currentUser),
                    _FollowersTab(currentUser: currentUser),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RecommendationCard extends ConsumerStatefulWidget {
  final UserModel peer;
  final UserModel currentUser;

  const _RecommendationCard({required this.peer, required this.currentUser});

  @override
  ConsumerState<_RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends ConsumerState<_RecommendationCard> {
  bool _isFollowing = false;

  Future<void> _follow() async {
    setState(() => _isFollowing = true);
    try {
      await ref.read(networkingServiceProvider).followUser(
            currentUserId: widget.currentUser.userId,
            currentUserName: widget.currentUser.name,
            targetUserId: widget.peer.userId,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to follow: $e'), backgroundColor: AppColors.errorRed),
        );
        setState(() => _isFollowing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(right: 12, bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.dividerDark),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserPublicProfileScreen(userId: widget.peer.userId),
          ),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InitialsAvatar(
                name: widget.peer.name,
                radius: 28,
                imageUrl: widget.peer.profilePhotoUrl,
              ),
              const SizedBox(height: 10),
              Text(
                widget.peer.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                widget.peer.department ?? 'Student',
                style: const TextStyle(color: AppColors.textMutedLight, fontSize: 10),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 32,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isFollowing ? null : _follow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    _isFollowing ? 'Followed' : 'Follow',
                    style: const TextStyle(color: AppColors.textDark, fontSize: 11, fontWeight: FontWeight.bold),
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

class _FollowingTab extends ConsumerWidget {
  final UserModel currentUser;

  const _FollowingTab({required this.currentUser});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingIdsAsync = ref.watch(followingIdsStreamProvider);

    return followingIdsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (ids) {
        if (ids.isEmpty) {
          return const Center(
            child: Text(
              'You are not following anyone yet.',
              style: TextStyle(color: AppColors.textMutedLight),
            ),
          );
        }

        final usersListAsync = ref.watch(usersListStreamProvider(ids));
        return usersListAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (users) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return _UserListTile(user: user, currentUser: currentUser);
              },
            );
          },
        );
      },
    );
  }
}

class _FollowersTab extends ConsumerWidget {
  final UserModel currentUser;

  const _FollowersTab({required this.currentUser});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followerIdsAsync = ref.watch(followerIdsStreamProvider);

    return followerIdsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (ids) {
        if (ids.isEmpty) {
          return const Center(
            child: Text(
              'No one is following you yet.',
              style: TextStyle(color: AppColors.textMutedLight),
            ),
          );
        }

        final usersListAsync = ref.watch(usersListStreamProvider(ids));
        return usersListAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (users) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return _UserListTile(user: user, currentUser: currentUser);
              },
            );
          },
        );
      },
    );
  }
}

class _UserListTile extends ConsumerStatefulWidget {
  final UserModel user;
  final UserModel currentUser;

  const _UserListTile({required this.user, required this.currentUser});

  @override
  ConsumerState<_UserListTile> createState() => _UserListTileState();
}

class _UserListTileState extends ConsumerState<_UserListTile> {
  bool _isProcessing = false;

  Future<void> _toggleFollow(bool isFollowing) async {
    setState(() => _isProcessing = true);
    try {
      final service = ref.read(networkingServiceProvider);
      if (isFollowing) {
        await service.unfollowUser(
          currentUserId: widget.currentUser.userId,
          targetUserId: widget.user.userId,
        );
      } else {
        await service.followUser(
          currentUserId: widget.currentUser.userId,
          currentUserName: widget.currentUser.name,
          targetUserId: widget.user.userId,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed operation: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final followingIdsAsync = ref.watch(followingIdsStreamProvider);
    final isFollowing = followingIdsAsync.value?.contains(widget.user.userId) ?? false;
    final isSelf = widget.currentUser.userId == widget.user.userId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: InitialsAvatar(
          name: widget.user.name,
          radius: 22,
          imageUrl: widget.user.profilePhotoUrl,
        ),
        title: Text(
          widget.user.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          widget.user.role == 'founder'
              ? 'Founder'
              : '${widget.user.yearOfStudy ?? "Student"} · ${widget.user.department ?? ""}',
          style: const TextStyle(color: AppColors.textMutedLight, fontSize: 12),
        ),
        trailing: isSelf
            ? null
            : TextButton(
                onPressed: _isProcessing ? null : () => _toggleFollow(isFollowing),
                child: _isProcessing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        isFollowing ? 'Unfollow' : 'Follow',
                        style: TextStyle(
                          color: isFollowing ? AppColors.textMutedLight : AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserPublicProfileScreen(userId: widget.user.userId),
          ),
        ),
      ),
    );
  }
}
