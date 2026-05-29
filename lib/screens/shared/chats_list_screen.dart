import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../../components/shared/initials_avatar.dart';
import 'chat_conversation_screen.dart';

class ChatsListScreen extends ConsumerWidget {
  const ChatsListScreen({super.key});

  String _getRelativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 7) {
      return '${(diff.inDays / 7).round()}w';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m';
    } else {
      return 'now';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(userStreamProvider);
    final userChatsAsync = ref.watch(userChatsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: currentUserAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => Center(child: Text('Error loading user data: $err')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Please log in to view chats.'));
          }

          final currentUserId = user.userId;
          final isStudent = user.role == 'student';

          return userChatsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (err, stack) => Center(child: Text('Error loading chats: $err')),
            data: (chats) {
              if (chats.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.forum_outlined,
                        size: 72,
                        color: AppColors.textMutedLight.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No conversations yet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.textMutedLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          isStudent
                              ? 'Your chats will appear here once a founder messages you or you initiate a chat from an application.'
                              : 'Chats with applicants will appear here once initialized.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMutedLight.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: chats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  final otherName = isStudent ? chat.founderName : chat.studentName;
                  final otherPhoto = isStudent ? chat.founderPhotoUrl : chat.studentPhotoUrl;
                  final unreadCount = chat.unreadCount[currentUserId] ?? 0;
                  final hasUnread = unreadCount > 0;

                  return Card(
                    margin: EdgeInsets.zero,
                    color: hasUnread ? AppColors.cardLight : AppColors.cardDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: hasUnread ? AppColors.primary.withOpacity(0.3) : AppColors.dividerDark,
                        width: 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        // Reset unread count first
                        ref.read(chatServiceProvider).resetUnreadCount(chat.id, currentUserId);
                        // Navigate to active chat
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatConversationScreen(
                              chatId: chat.id,
                              chatTitle: otherName,
                              chatSubtitle: chat.listingTitle,
                              otherUserId: isStudent ? chat.founderId : chat.studentId,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            InitialsAvatar(
                              name: otherName,
                              imageUrl: otherPhoto,
                              radius: 26,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          otherName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                                            color: AppColors.textLight,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _getRelativeTime(chat.lastMessageTime),
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: hasUnread ? AppColors.primary : AppColors.textMutedLight,
                                          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    chat.listingTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          chat.lastSenderId == currentUserId
                                              ? 'You: ${chat.lastMessage}'
                                              : chat.lastMessage,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: hasUnread ? AppColors.textLight : AppColors.textMutedLight,
                                            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      if (hasUnread) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            unreadCount.toString(),
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
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
    );
  }
}
