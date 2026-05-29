Map<String, dynamic> computeMatch(
  List<String> studentSkills,
  List<String> requiredSkills,
) {
  if (requiredSkills.isEmpty) {
    return {
      'score': 1.0,
      'matchedSkills': <String>[],
      'missingSkills': <String>[],
    };
  }
  
  final student = studentSkills.map((s) => s.toLowerCase()).toSet();
  final required = requiredSkills.map((s) => s.toLowerCase()).toSet();
  
  // To preserve original casing, we map lowercased matches back to original required skills
  final matched = requiredSkills.where((s) => student.contains(s.toLowerCase())).toList();
  final missing = requiredSkills.where((s) => !student.contains(s.toLowerCase())).toList();
  
  final score = matched.length / requiredSkills.length;
  
  return {
    'score': score,
    'matchedSkills': matched,
    'missingSkills': missing,
  };
}
