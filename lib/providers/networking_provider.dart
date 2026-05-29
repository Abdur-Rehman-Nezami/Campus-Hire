import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import 'user_provider.dart';
import '../services/notification_service.dart';

// Stream of user IDs that the current user is following
final followingIdsStreamProvider = StreamProvider<List<String>>((ref) {
  final userAsync = ref.watch(userStreamProvider);
  final user = userAsync.value;
  if (user == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('follows')
      .where('followerId', isEqualTo: user.userId)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => doc.data()['followingId'] as String).toList();
  });
});

// Stream of startup IDs that the current user is following
final followedStartupIdsStreamProvider = StreamProvider<List<String>>((ref) {
  final userAsync = ref.watch(userStreamProvider);
  final user = userAsync.value;
  if (user == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('startup_follows')
      .where('userId', isEqualTo: user.userId)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => doc.data()['startupId'] as String).toList();
  });
});

// Stream of user IDs that are following the current user
final followerIdsStreamProvider = StreamProvider<List<String>>((ref) {
  final userAsync = ref.watch(userStreamProvider);
  final user = userAsync.value;
  if (user == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('follows')
      .where('followingId', isEqualTo: user.userId)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => doc.data()['followerId'] as String).toList();
  });
});

// Stream of detailed UserModels for a list of user IDs
final usersListStreamProvider = StreamProvider.family<List<UserModel>, List<String>>((ref, userIds) {
  if (userIds.isEmpty) return Stream.value([]);
  
  // Firestore whereIn has a limit of 10 items. We take up to 10 for safety/performance in lists.
  final limitedIds = userIds.take(10).toList();

  return FirebaseFirestore.instance
      .collection('users')
      .where(FieldPath.documentId, whereIn: limitedIds)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();
  });
});

// Provider for peer recommendations (People you may know)
final peerRecommendationsProvider = StreamProvider<List<UserModel>>((ref) {
  final userAsync = ref.watch(userStreamProvider);
  final followingIdsAsync = ref.watch(followingIdsStreamProvider);

  if (userAsync.isLoading || followingIdsAsync.isLoading) {
    return const Stream.empty();
  }

  final user = userAsync.value;
  final followingIds = followingIdsAsync.value ?? [];

  if (user == null) return const Stream.empty();

  // Fetch users from the same university
  return FirebaseFirestore.instance
      .collection('users')
      .where('university', isEqualTo: user.university)
      .where('role', isEqualTo: 'student')
      .snapshots()
      .map((snapshot) {
    final peers = snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .where((peer) => peer.userId != user.userId && !followingIds.contains(peer.userId))
        .toList();
    // Sort peers randomly or by registration date
    peers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return peers;
  });
});

final networkingServiceProvider = Provider((ref) => NetworkingService());

class NetworkingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> followUser({
    required String currentUserId,
    required String currentUserName,
    required String targetUserId,
  }) async {
    final followId = '${currentUserId}_$targetUserId';
    final followDocRef = _firestore.collection('follows').doc(followId);

    // Use a transaction to ensure atomic count updates
    await _firestore.runTransaction((transaction) async {
      final followDoc = await transaction.get(followDocRef);
      if (followDoc.exists) return; // Already following

      final currentUserRef = _firestore.collection('users').doc(currentUserId);
      final targetUserRef = _firestore.collection('users').doc(targetUserId);

      transaction.set(followDocRef, {
        'followerId': currentUserId,
        'followingId': targetUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.update(currentUserRef, {
        'followingCount': FieldValue.increment(1),
      });

      transaction.update(targetUserRef, {
        'followerCount': FieldValue.increment(1),
      });
    });

    // Notify the target user that someone followed them
    await NotificationService.sendNotification(
      userId: targetUserId,
      title: 'New Follower! 👤',
      body: '$currentUserName is now following you.',
      type: 'follow',
      routeId: currentUserId,
    );
  }

  Future<void> unfollowUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    final followId = '${currentUserId}_$targetUserId';
    final followDocRef = _firestore.collection('follows').doc(followId);

    await _firestore.runTransaction((transaction) async {
      final followDoc = await transaction.get(followDocRef);
      if (!followDoc.exists) return; // Not following

      final currentUserRef = _firestore.collection('users').doc(currentUserId);
      final targetUserRef = _firestore.collection('users').doc(targetUserId);

      transaction.delete(followDocRef);

      transaction.update(currentUserRef, {
        'followingCount': FieldValue.increment(-1),
      });

      transaction.update(targetUserRef, {
        'followerCount': FieldValue.increment(-1),
      });
    });
  }

  Future<void> followStartup({
    required String userId,
    required String startupId,
  }) async {
    final followId = '${userId}_$startupId';
    final followDocRef = _firestore.collection('startup_follows').doc(followId);

    await _firestore.runTransaction((transaction) async {
      final followDoc = await transaction.get(followDocRef);
      if (followDoc.exists) return; // Already following

      final startupRef = _firestore.collection('startups').doc(startupId);

      transaction.set(followDocRef, {
        'userId': userId,
        'startupId': startupId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.update(startupRef, {
        'followerCount': FieldValue.increment(1),
      });
    });
  }

  Future<void> unfollowStartup({
    required String userId,
    required String startupId,
  }) async {
    final followId = '${userId}_$startupId';
    final followDocRef = _firestore.collection('startup_follows').doc(followId);

    await _firestore.runTransaction((transaction) async {
      final followDoc = await transaction.get(followDocRef);
      if (!followDoc.exists) return; // Not following

      final startupRef = _firestore.collection('startups').doc(startupId);

      transaction.delete(followDocRef);

      transaction.update(startupRef, {
        'followerCount': FieldValue.increment(-1),
      });
    });
  }
}
