import 'package:cloud_firestore/cloud_firestore.dart';

class ApplicationModel {
  final String applicationId;
  final String listingId;
  final String startupId;
  final String studentId;
  final String coverNote;
  final double matchScore;
  final List<String> matchedSkills;
  final List<String> missingSkills;
  final String status; // "pending" | "shortlisted" | "rejected" | "hired"
  final DateTime createdAt;
  final String? resumeUrl;

  // Transient fields for client-side rendering
  String? listingTitle;
  String? startupName;
  String? startupSector;
  String? compensationDetails;

  ApplicationModel({
    required this.applicationId,
    required this.listingId,
    required this.startupId,
    required this.studentId,
    required this.coverNote,
    required this.matchScore,
    required this.matchedSkills,
    required this.missingSkills,
    required this.status,
    required this.createdAt,
    this.resumeUrl,
    this.listingTitle,
    this.startupName,
    this.startupSector,
    this.compensationDetails,
  });

  factory ApplicationModel.fromMap(Map<String, dynamic> map, String id) {
    return ApplicationModel(
      applicationId: id,
      listingId: map['listingId'] ?? '',
      startupId: map['startupId'] ?? '',
      studentId: map['studentId'] ?? '',
      coverNote: map['coverNote'] ?? '',
      matchScore: (map['matchScore'] as num?)?.toDouble() ?? 0.0,
      matchedSkills: List<String>.from(map['matchedSkills'] ?? []),
      missingSkills: List<String>.from(map['missingSkills'] ?? []),
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resumeUrl: map['resumeUrl'],
      listingTitle: map['listingTitle'],
      startupName: map['startupName'],
      startupSector: map['startupSector'],
      compensationDetails: map['compensationDetails'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'listingId': listingId,
      'startupId': startupId,
      'studentId': studentId,
      'coverNote': coverNote,
      'matchScore': matchScore,
      'matchedSkills': matchedSkills,
      'missingSkills': missingSkills,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      if (resumeUrl != null) 'resumeUrl': resumeUrl,
      if (listingTitle != null) 'listingTitle': listingTitle,
      if (startupName != null) 'startupName': startupName,
      if (startupSector != null) 'startupSector': startupSector,
      if (compensationDetails != null) 'compensationDetails': compensationDetails,
    };
  }
}
