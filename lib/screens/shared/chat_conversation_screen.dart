import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/message_model.dart';
import 'package:intl/intl.dart';
import 'user_public_profile_screen.dart';

class ChatConversationScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String chatTitle;
  final String chatSubtitle;
  final String otherUserId;

  const ChatConversationScreen({
    super.key,
    required this.chatId,
    required this.chatTitle,
    required this.chatSubtitle,
    required this.otherUserId,
  });

  @override
  ConsumerState<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends ConsumerState<ChatConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String currentUserId) {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    ref.read(chatServiceProvider).sendMessage(
      chatId: widget.chatId,
      senderId: currentUserId,
      recipientId: widget.otherUserId,
      text: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userStreamProvider);
    final messagesAsync = ref.watch(chatMessagesStreamProvider(widget.chatId));

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (user) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text('Please log in to chat.')));
        }

        final currentUserId = user.userId;

        // Reset unread count when viewing
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(chatServiceProvider).resetUnreadCount(widget.chatId, currentUserId);
        });

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            backgroundColor: AppColors.scaffoldBackground,
            titleSpacing: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            title: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserPublicProfileScreen(userId: widget.otherUserId),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.chatTitle,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textLight,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.open_in_new, size: 12, color: AppColors.textMutedLight),
                      ],
                    ),
                    Text(
                      widget.chatSubtitle,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              // Message List
              Expanded(
                child: messagesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (err, stack) => Center(child: Text('Error loading messages: $err')),
                  data: (messages) {
                    if (messages.isEmpty) {
                      return Center(
                        child: Text(
                          'No messages yet. Say hello!',
                          style: TextStyle(color: AppColors.textMutedLight.withOpacity(0.5)),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      reverse: true,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == currentUserId;
                        
                        // Sequence checks for grouping visuals (optional metadata)
                        final showTime = index == 0 || 
                            messages[index - 1].timestamp.difference(message.timestamp).inMinutes > 5;

                        return Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (showTime) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Center(
                                  child: Text(
                                    DateFormat('hh:mm a').format(message.timestamp),
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppColors.textMutedLight.withOpacity(0.4),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            _MessageBubble(
                              message: message,
                              isMe: isMe,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              // Bottom Sticky Input
              Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 12,
                  top: 12,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.cardDark,
                  border: Border(
                    top: BorderSide(color: AppColors.dividerDark, width: 1.2),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.scaffoldBackground,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.dividerDark),
                        ),
                        child: TextField(
                          controller: _messageController,
                          style: const TextStyle(color: AppColors.textLight, fontSize: 15),
                          maxLines: 4,
                          minLines: 1,
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: AppColors.textMutedLight),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _sendMessage(currentUserId),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      onPressed: () => _sendMessage(currentUserId),
                      mini: true,
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      child: const Icon(Icons.send, color: Colors.black, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _MessageBubble({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.cardDark,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe ? null : Border.all(color: AppColors.dividerDark, width: 1),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Text(
          message.text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isMe ? Colors.black : AppColors.textLight,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}
