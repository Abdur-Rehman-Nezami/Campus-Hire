import 'package:cloud_firestore/cloud_firestore.dart';

class ListingModel {
  final String listingId;
  final String startupId;
  final String founderId;
  final String type; // "job" | "internship" | "cofounding" | "partnership"
  final String title;
  final String description;
  final List<String> requiredSkills;
  final String compensationType; // "paid" | "equity" | "unpaid" | "negotiable"
  final String? compensationDetails; // e.g. "Rs 15,000" or "Equity + Stipend"
  final String locationType; // "remote" | "on-site" | "hybrid"
  final DateTime deadline;
  final String status; // "open" | "paused" | "closed"
  final DateTime createdAt;
  
  // Transient fields (fetched/computed client-side)
  String? startupName;
  String? startupSector;
  String? university;

  ListingModel({
    required this.listingId,
    required this.startupId,
    required this.founderId,
    required this.type,
    required this.title,
    required this.description,
    required this.requiredSkills,
    required this.compensationType,
    this.compensationDetails,
    required this.locationType,
    required this.deadline,
    required this.status,
    required this.createdAt,
    this.startupName,
    this.startupSector,
    this.university,
  });

  factory ListingModel.fromMap(Map<String, dynamic> map, String id) {
    return ListingModel(
      listingId: id,
      startupId: map['startupId'] ?? '',
      founderId: map['founderId'] ?? '',
      type: map['type'] ?? 'job',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      requiredSkills: List<String>.from(map['requiredSkills'] ?? []),
      compensationType: map['compensationType'] ?? 'negotiable',
      compensationDetails: map['compensationDetails'],
      locationType: map['locationType'] ?? 'remote',
      deadline: (map['deadline'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'open',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startupName: map['startupName'],
      startupSector: map['startupSector'],
      university: map['university'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startupId': startupId,
      'founderId': founderId,
      'type': type,
      'title': title,
      'description': description,
      'requiredSkills': requiredSkills,
      'compensationType': compensationType,
      'compensationDetails': compensationDetails,
      'locationType': locationType,
      'deadline': Timestamp.fromDate(deadline),
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      if (startupName != null) 'startupName': startupName,
      if (startupSector != null) 'startupSector': startupSector,
      if (university != null) 'university': university,
    };
  }
}
