import 'package:cloud_firestore/cloud_firestore.dart';

class StartupModel {
  final String startupId;
  final String founderId;
  final String name;
  final String? logoUrl;
  final String tagline;
  final String description;
  final String sector;
  final String stage; // "idea" | "mvp" | "revenue"
  final String university;
  final int followerCount;
  final DateTime createdAt;

  StartupModel({
    required this.startupId,
    required this.founderId,
    required this.name,
    this.logoUrl,
    required this.tagline,
    required this.description,
    required this.sector,
    required this.stage,
    required this.university,
    this.followerCount = 0,
    required this.createdAt,
  });

  factory StartupModel.fromMap(Map<String, dynamic> map, String id) {
    return StartupModel(
      startupId: id,
      founderId: map['founderId'] ?? '',
      name: map['name'] ?? '',
      logoUrl: map['logoUrl'],
      tagline: map['tagline'] ?? '',
      description: map['description'] ?? '',
      sector: map['sector'] ?? '',
      stage: map['stage'] ?? 'idea',
      university: map['university'] ?? '',
      followerCount: map['followerCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'founderId': founderId,
      'name': name,
      'logoUrl': logoUrl,
      'tagline': tagline,
      'description': description,
      'sector': sector,
      'stage': stage,
      'university': university,
      'followerCount': followerCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
