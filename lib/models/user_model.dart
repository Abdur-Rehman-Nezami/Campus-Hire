import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String userId;
  final String name;
  final String email;
  final String university;
  final String? department;
  final String? yearOfStudy;
  final String? bio;
  final String? profilePhotoUrl;
  final String? resumeUrl;
  final int followerCount;
  final int followingCount;
  final List<String> skills;
  final List<String> rsvpdEvents;
  final String role; // "student" | "founder"
  final String? startupId;
  final DateTime createdAt;

  UserModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.university,
    this.department,
    this.yearOfStudy,
    this.bio,
    this.profilePhotoUrl,
    this.resumeUrl,
    this.followerCount = 0,
    this.followingCount = 0,
    required this.skills,
    this.rsvpdEvents = const [],
    required this.role,
    this.startupId,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      userId: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      university: map['university'] ?? '',
      department: map['department'],
      yearOfStudy: map['yearOfStudy'],
      bio: map['bio'],
      profilePhotoUrl: map['profilePhotoUrl'],
      resumeUrl: map['resumeUrl'],
      followerCount: map['followerCount'] ?? 0,
      followingCount: map['followingCount'] ?? 0,
      skills: List<String>.from(map['skills'] ?? []),
      rsvpdEvents: List<String>.from(map['rsvpdEvents'] ?? []),
      role: map['role'] ?? 'student',
      startupId: map['startupId'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'university': university,
      'department': department,
      'yearOfStudy': yearOfStudy,
      'bio': bio,
      'profilePhotoUrl': profilePhotoUrl,
      'resumeUrl': resumeUrl,
      'followerCount': followerCount,
      'followingCount': followingCount,
      'skills': skills,
      'rsvpdEvents': rsvpdEvents,
      'role': role,
      'startupId': startupId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? university,
    String? department,
    String? yearOfStudy,
    String? bio,
    String? profilePhotoUrl,
    String? resumeUrl,
    int? followerCount,
    int? followingCount,
    List<String>? skills,
    List<String>? rsvpdEvents,
    String? role,
    String? startupId,
  }) {
    return UserModel(
      userId: userId,
      name: name ?? this.name,
      email: email ?? this.email,
      university: university ?? this.university,
      department: department ?? this.department,
      yearOfStudy: yearOfStudy ?? this.yearOfStudy,
      bio: bio ?? this.bio,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      resumeUrl: resumeUrl ?? this.resumeUrl,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      skills: skills ?? this.skills,
      rsvpdEvents: rsvpdEvents ?? this.rsvpdEvents,
      role: role ?? this.role,
      startupId: startupId ?? this.startupId,
      createdAt: createdAt,
    );
  }
}
