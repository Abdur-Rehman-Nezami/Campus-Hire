import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';
import '../services/notification_service.dart';

final eventsStreamProvider = StreamProvider<List<EventModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('events')
      .snapshots()
      .map((snapshot) {
    final events = snapshot.docs
        .map((doc) => EventModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
    // Sort client-side: upcoming first (or by dateTime)
    events.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return events;
  });
});

final eventsServiceProvider = Provider((ref) => EventsService());

class EventsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createEvent(EventModel event) async {
    await _firestore.collection('events').doc(event.eventId.isEmpty ? null : event.eventId).set(event.toMap());
  }

  Future<void> rsvpToEvent({
    required String eventId,
    required String userId,
    required String studentName,
    required String eventTitle,
    required String founderId,
    required bool isRegistering,
  }) async {
    final batch = _firestore.batch();
    final eventRef = _firestore.collection('events').doc(eventId);
    final userRef = _firestore.collection('users').doc(userId);

    if (isRegistering) {
      batch.update(eventRef, {
        'attendees': FieldValue.arrayUnion([userId]),
      });
      batch.update(userRef, {
        'rsvpdEvents': FieldValue.arrayUnion([eventId]),
      });
      
      // Dispatch a notification to the founder that a student RSVP'd
      await NotificationService.sendNotification(
        userId: founderId,
        title: 'New RSVP for $eventTitle',
        body: '$studentName has registered for your event!',
        type: 'event',
        routeId: eventId,
      );
    } else {
      batch.update(eventRef, {
        'attendees': FieldValue.arrayRemove([userId]),
      });
      batch.update(userRef, {
        'rsvpdEvents': FieldValue.arrayRemove([eventId]),
      });
    }

    await batch.commit();
  }
}
