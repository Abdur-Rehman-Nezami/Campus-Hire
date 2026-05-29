import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String eventId;
  final String startupId;
  final String founderId;
  final String title;
  final String description;
  final String type; // "workshop" | "seminar" | "networking" | "hackathon"
  final DateTime dateTime;
  final String location; // e.g. "Hall A, NUST" or "Zoom"
  final bool isOnline;
  final String? meetingUrl;
  final List<String> speakers;
  final List<String> attendees; // UIDs of registered students
  final DateTime createdAt;
  
  // Transient/Joined fields
  final String? startupName;
  final String? logoUrl;

  EventModel({
    required this.eventId,
    required this.startupId,
    required this.founderId,
    required this.title,
    required this.description,
    required this.type,
    required this.dateTime,
    required this.location,
    required this.isOnline,
    this.meetingUrl,
    required this.speakers,
    required this.attendees,
    required this.createdAt,
    this.startupName,
    this.logoUrl,
  });

  factory EventModel.fromMap(Map<String, dynamic> map, String id) {
    return EventModel(
      eventId: id,
      startupId: map['startupId'] ?? '',
      founderId: map['founderId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: map['type'] ?? 'workshop',
      dateTime: (map['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      location: map['location'] ?? '',
      isOnline: map['isOnline'] ?? false,
      meetingUrl: map['meetingUrl'],
      speakers: List<String>.from(map['speakers'] ?? []),
      attendees: List<String>.from(map['attendees'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startupName: map['startupName'],
      logoUrl: map['logoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startupId': startupId,
      'founderId': founderId,
      'title': title,
      'description': description,
      'type': type,
      'dateTime': Timestamp.fromDate(dateTime),
      'location': location,
      'isOnline': isOnline,
      'meetingUrl': meetingUrl,
      'speakers': speakers,
      'attendees': attendees,
      'createdAt': Timestamp.fromDate(createdAt),
      if (startupName != null) 'startupName': startupName,
      if (logoUrl != null) 'logoUrl': logoUrl,
    };
  }
}
