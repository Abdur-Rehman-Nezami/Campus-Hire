import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import 'user_provider.dart';

final unreadNotificationsCountStreamProvider = StreamProvider<int>((ref) {
  final userAsync = ref.watch(userStreamProvider);
  final user = userAsync.value;
  if (user == null) return Stream.value(0);

  return FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: user.userId)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .where((doc) => (doc.data()['isRead'] ?? false) == false)
          .length);
});

final notificationsStreamProvider = StreamProvider<List<NotificationModel>>((ref) {
  final userAsync = ref.watch(userStreamProvider);
  final user = userAsync.value;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: user.userId)
      .snapshots()
      .map((snapshot) {
    final list = snapshot.docs
        .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
        .toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  });
});

class NotificationController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllAsRead(String userId) async {
    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .get();

    for (var doc in snapshot.docs) {
      if ((doc.data()['isRead'] ?? false) == false) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    await batch.commit();
  }
}

final notificationControllerProvider = Provider((ref) => NotificationController());
