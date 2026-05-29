import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import 'user_provider.dart';
import '../services/notification_service.dart';

final firestoreProvider = Provider((ref) => FirebaseFirestore.instance);

// Stream of all chats for the current user
final userChatsStreamProvider = StreamProvider<List<ChatModel>>((ref) {
  final userAsync = ref.watch(userStreamProvider);
  final firestore = ref.watch(firestoreProvider);
  
  final user = userAsync.value;
  if (user == null) return const Stream.empty();
  
  final queryField = user.role == 'student' ? 'studentId' : 'founderId';
  
  return firestore
      .collection('chats')
      .where(queryField, isEqualTo: user.userId)
      .snapshots()
      .map((snapshot) {
    final chats = snapshot.docs
        .map((doc) => ChatModel.fromMap(doc.data(), doc.id))
        .toList();
    chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    return chats;
  });
});

// Stream of messages for a specific chat ID
final chatMessagesStreamProvider = StreamProvider.family<List<MessageModel>, String>((ref, chatId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
          .toList());
});

class ChatService {
  final FirebaseFirestore _firestore;
  ChatService(this._firestore);

  // Checks or creates a chat session for a specific application
  Future<String> getOrCreateChat({
    required String applicationId,
    required String listingId,
    required String studentId,
    required String founderId,
    required String studentName,
    required String founderName,
    required String listingTitle,
    String? studentPhotoUrl,
    String? founderPhotoUrl,
  }) async {
    final chatDoc = _firestore.collection('chats').doc(applicationId);
    final docSnapshot = await chatDoc.get();
    
    if (docSnapshot.exists) {
      return applicationId;
    }
    
    // Create new chat
    final newChat = ChatModel(
      id: applicationId,
      applicationId: applicationId,
      listingId: listingId,
      studentId: studentId,
      founderId: founderId,
      studentName: studentName,
      founderName: founderName,
      listingTitle: listingTitle,
      studentPhotoUrl: studentPhotoUrl,
      founderPhotoUrl: founderPhotoUrl,
      lastMessage: 'Chat started',
      lastMessageTime: DateTime.now(),
      lastSenderId: '',
      unreadCount: {
        studentId: 0,
        founderId: 0,
      },
    );
    
    await chatDoc.set(newChat.toMap());
    return applicationId;
  }

  // Send a message in a conversation
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String recipientId,
    required String text,
  }) async {
    final timestamp = DateTime.now();
    final messageDoc = _firestore.collection('chats').doc(chatId).collection('messages').doc();
    
    final message = MessageModel(
      id: messageDoc.id,
      senderId: senderId,
      text: text,
      timestamp: timestamp,
    );

    // Write message
    await messageDoc.set(message.toMap());

    // Update conversation metadata and increment recipient's unread counter
    final chatRef = _firestore.collection('chats').doc(chatId);
    await _firestore.runTransaction((transaction) async {
      final freshSnapshot = await transaction.get(chatRef);
      if (!freshSnapshot.exists) return;
      
      final currentUnread = Map<String, int>.from(freshSnapshot.data()?['unreadCount'] ?? {});
      currentUnread[recipientId] = (currentUnread[recipientId] ?? 0) + 1;
      
      transaction.update(chatRef, {
        'lastMessage': text,
        'lastMessageTime': Timestamp.fromDate(timestamp),
        'lastSenderId': senderId,
        'unreadCount': currentUnread,
      });
    });

    // Send fire-and-forget notification
    await NotificationService.sendNotification(
      userId: recipientId,
      title: 'New Message',
      body: text,
      type: 'chat',
      routeId: chatId,
    );
  }

  // Reset unread count for a user in a specific chat
  Future<void> resetUnreadCount(String chatId, String userId) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    await _firestore.runTransaction((transaction) async {
      final freshSnapshot = await transaction.get(chatRef);
      if (!freshSnapshot.exists) return;
      
      final currentUnread = Map<String, int>.from(freshSnapshot.data()?['unreadCount'] ?? {});
      currentUnread[userId] = 0;
      
      transaction.update(chatRef, {
        'unreadCount': currentUnread,
      });
    });
  }
}

final chatServiceProvider = Provider((ref) {
  final firestore = ref.watch(firestoreProvider);
  return ChatService(firestore);
});
