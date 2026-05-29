import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../models/notification_model.dart';
import '../../models/application_model.dart';
import '../../providers/notification_provider.dart';
import '../../providers/user_provider.dart';
import '../student/application_detail_screen.dart';
import 'chat_conversation_screen.dart';

class NotificationsHubScreen extends ConsumerWidget {
  const NotificationsHubScreen({super.key});

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'chat':
        return Icons.chat_bubble_outline;
      case 'application_status':
        return Icons.business_center_outlined;
      case 'event':
      case 'rsvp':
        return Icons.calendar_today_outlined;
      case 'follow':
        return Icons.person_outline;
      default:
        return Icons.info_outline;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'chat':
        return AppColors.primary;
      case 'application_status':
        return AppColors.successGreen;
      case 'event':
      case 'rsvp':
        return AppColors.warningAmber;
      case 'follow':
        return Colors.blue;
      default:
        return AppColors.textMutedLight;
    }
  }

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  Future<void> _handleNotificationTap(BuildContext context, WidgetRef ref, NotificationModel notification) async {
    // Mark as read
    await ref.read(notificationControllerProvider).markAsRead(notification.id);

    if (notification.routeId == null || notification.routeId!.isEmpty) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (notification.type == 'chat') {
        final chatDoc = await FirebaseFirestore.instance
            .collection('chats')
            .doc(notification.routeId)
            .get();

        if (context.mounted) Navigator.pop(context); // Pop loading

        if (chatDoc.exists && context.mounted) {
          final data = chatDoc.data()!;
          final studentId = data['studentId'] ?? '';
          final founderId = data['founderId'] ?? '';
          final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
          final otherUserId = currentUserId == studentId ? founderId : studentId;
          final chatTitle = currentUserId == studentId 
              ? (data['founderName'] ?? 'Founder') 
              : (data['studentName'] ?? 'Student');
          final chatSubtitle = data['listingTitle'] ?? 'Role Application';

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatConversationScreen(
                chatId: notification.routeId!,
                chatTitle: chatTitle,
                chatSubtitle: chatSubtitle,
                otherUserId: otherUserId,
              ),
            ),
          );
        }
      } else if (notification.type == 'application_status') {
        final appDoc = await FirebaseFirestore.instance
            .collection('applications')
            .doc(notification.routeId)
            .get();

        if (context.mounted) Navigator.pop(context); // Pop loading

        if (appDoc.exists && context.mounted) {
          final application = ApplicationModel.fromMap(appDoc.data()!, appDoc.id);
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentApplicationDetailScreen(application: application),
            ),
          );
        }
      } else {
        if (context.mounted) Navigator.pop(context); // Pop loading
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to navigate: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final user = ref.watch(userStreamProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (user != null)
            TextButton(
              onPressed: () => ref.read(notificationControllerProvider).markAllAsRead(user.userId),
              child: const Text(
                'Mark all read',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Error loading notifications: $err')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_outlined,
                    size: 64,
                    color: AppColors.textMutedLight.withOpacity(0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textMutedLight,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const Divider(
              color: AppColors.dividerDark,
              height: 1,
              indent: 72,
            ),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final iconColor = _getNotificationColor(notification.type);
              final icon = _getNotificationIcon(notification.type);

              return ListTile(
                onTap: () => _handleNotificationTap(context, ref, notification),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: iconColor.withOpacity(0.2)),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                title: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getRelativeTime(notification.timestamp),
                      style: const TextStyle(
                        color: AppColors.textMutedLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    notification.body,
                    style: TextStyle(
                      color: notification.isRead ? AppColors.textMutedLight : AppColors.textLight.withOpacity(0.8),
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                tileColor: notification.isRead ? Colors.transparent : AppColors.cardDark.withOpacity(0.2),
              );
            },
          );
        },
      ),
    );
  }
}
