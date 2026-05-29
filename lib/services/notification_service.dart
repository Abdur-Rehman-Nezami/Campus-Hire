import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationService {
  static final _firestore = FirebaseFirestore.instance;

  // Send a fire-and-forget notification to Firestore
  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? routeId,
  }) async {
    try {
      final docRef = _firestore.collection('notifications').doc();
      final notification = NotificationModel(
        id: docRef.id,
        userId: userId,
        title: title,
        body: body,
        type: type,
        routeId: routeId,
        timestamp: DateTime.now(),
        isRead: false,
      );
      await docRef.set(notification.toMap());
    } catch (e) {
      // Clean fire-and-forget catch block
    }
  }
}
