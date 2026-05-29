import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SkillCategory {
  final String name;
  final List<String> skills;

  SkillCategory({required this.name, required this.skills});

  factory SkillCategory.fromMap(Map<String, dynamic> map) {
    return SkillCategory(
      name: map['name'] ?? '',
      skills: List<String>.from(map['skills'] ?? []),
    );
  }
}

final skillsConfigProvider = FutureProvider<List<SkillCategory>>((ref) async {
  try {
    final doc = await FirebaseFirestore.instance.collection('config').doc('skills').get();
    
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      final categoriesData = data['categories'] as List<dynamic>? ?? [];
      return categoriesData.map((c) => SkillCategory.fromMap(c as Map<String, dynamic>)).toList();
    }
  } catch (e) {
    // If there is any network error, fallback to default
  }

  // Default fallback categories from project specification
  return [
    SkillCategory(name: 'Programming', skills: [
      'Python', 'JavaScript', 'Flutter/Dart', 'React', 'Node.js', 'MongoDB', 'Firebase', 'REST APIs', 'Git'
    ]),
    SkillCategory(name: 'Design', skills: [
      'Figma', 'UI/UX Design', 'Canva', 'Prototyping'
    ]),
    SkillCategory(name: 'Data & AI', skills: [
      'Machine Learning', 'Computer Vision', 'Data Analysis', 'SQL'
    ]),
    SkillCategory(name: 'Business', skills: [
      'Marketing', 'Social Media', 'Content Writing', 'Sales', 'Finance'
    ]),
    SkillCategory(name: 'Other', skills: [
      'Project Management', 'Public Speaking', 'Research', 'Video Editing'
    ]),
  ];
});
