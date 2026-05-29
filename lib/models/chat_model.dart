import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id; // usually applicationId
  final String applicationId;
  final String listingId;
  final String studentId;
  final String founderId;
  final String studentName;
  final String founderName;
  final String listingTitle;
  final String? studentPhotoUrl;
  final String? founderPhotoUrl;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastSenderId;
  final Map<String, int> unreadCount; // key: userId, value: count

  ChatModel({
    required this.id,
    required this.applicationId,
    required this.listingId,
    required this.studentId,
    required this.founderId,
    required this.studentName,
    required this.founderName,
    required this.listingTitle,
    this.studentPhotoUrl,
    this.founderPhotoUrl,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastSenderId,
    required this.unreadCount,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map, String id) {
    return ChatModel(
      id: id,
      applicationId: map['applicationId'] ?? '',
      listingId: map['listingId'] ?? '',
      studentId: map['studentId'] ?? '',
      founderId: map['founderId'] ?? '',
      studentName: map['studentName'] ?? '',
      founderName: map['founderName'] ?? '',
      listingTitle: map['listingTitle'] ?? '',
      studentPhotoUrl: map['studentPhotoUrl'],
      founderPhotoUrl: map['founderPhotoUrl'],
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: (map['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSenderId: map['lastSenderId'] ?? '',
      unreadCount: Map<String, int>.from(map['unreadCount'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'applicationId': applicationId,
      'listingId': listingId,
      'studentId': studentId,
      'founderId': founderId,
      'studentName': studentName,
      'founderName': founderName,
      'listingTitle': listingTitle,
      'studentPhotoUrl': studentPhotoUrl,
      'founderPhotoUrl': founderPhotoUrl,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'lastSenderId': lastSenderId,
      'unreadCount': unreadCount,
    };
  }
}
