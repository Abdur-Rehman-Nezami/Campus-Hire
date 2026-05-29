import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent';

  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static Future<String?> _call(String prompt, {bool jsonMode = false}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 1024,
            if (jsonMode) 'responseMimeType': 'application/json',
          }
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'] as String;
      }
      print('Gemini API Error status code: ${response.statusCode}');
      print('Gemini API Error body: ${response.body}');
      return null;
    } catch (e) {
      print('Gemini API Exception: $e');
      return null;
    }
  }

  // Feature 1 — cover note generator
  static Future<String?> generateCoverNote({
    required String studentName,
    required List<String> studentSkills,
    required String listingTitle,
    required String listingDescription,
    required String startupName,
    required String startupTagline,
    required List<String> matchedSkills,
    required List<String> missingSkills,
    required int matchPercent,
  }) async {
    final prompt = '''
You are helping a university student write a cover note for a startup job application on a campus hiring platform.

Student name: $studentName
Student skills: ${studentSkills.join(', ')}
Applying for: $listingTitle at $startupName
Startup tagline: $startupTagline
Role description: $listingDescription
Skill match: $matchPercent% — matched skills: ${matchedSkills.join(', ')}
${missingSkills.isNotEmpty ? 'Missing skills: ${missingSkills.join(', ')}' : ''}

Write a compelling, genuine cover note in exactly 1-3 sentences, maximum 280 characters total. Write in first person. Be specific to this role and startup. Sound like a motivated university student, not a corporate professional. Do not use buzzwords like "passionate" or "synergy". Do not include a greeting or sign-off. Return only the cover note text, nothing else.
''';
    return await _call(prompt);
  }

  // Feature 2 — startup pitch analyzer
  static Future<Map<String, dynamic>?> analyzeStartupPitch({
    required String startupName,
    required String tagline,
    required String description,
    required String sector,
    required String stage,
  }) async {
    final prompt = '''
You are analyzing a university student's startup pitch on a campus hiring platform. Be constructive and encouraging but honest.

Startup name: $startupName
Tagline: $tagline
Description: $description
Sector: $sector
Stage: $stage

Return a JSON object with exactly this structure, no markdown, no code block, just raw JSON:
{
  "clarityScore": <integer 0-100>,
  "strengths": [<string>, <string>],
  "weaknesses": [<string>, <string>],
  "suggestedTagline": "<string under 80 chars>",
  "improvedDescription": "<string under 300 chars>"
}

Strengths and weaknesses should each have 2-3 items. Be specific to what they wrote, not generic advice.
''';

    print('--- ANALYZE STARTUP PITCH PROMPT ---');
    print(prompt);
    final result = await _call(prompt, jsonMode: true);
    print('--- ANALYZE STARTUP PITCH RAW RESULT ---');
    print(result);
    if (result == null) return null;
    try {
      final cleaned = result
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      print('analyzeStartupPitch JSON Parse Error: $e');
      return null;
    }
  }

  // Feature 3 — skill gap recommendations
  static Future<List<Map<String, String>>?> getSkillRecommendations({
    required List<String> studentSkills,
    required List<String> allAppliedRequiredSkills,
    required double averageMatchScore,
  }) async {
    final prompt = '''
You are advising a university student on which skills to learn next based on their job applications on a campus startup hiring platform.

Student current skills: ${studentSkills.join(', ')}
Skills required in listings they applied to: ${allAppliedRequiredSkills.join(', ')}
Their average skill match score: ${(averageMatchScore * 100).toInt()}%

Return a JSON array of exactly 3 skill recommendations, no markdown, no code block, raw JSON only:
[
  { "skill": "<skill name>", "reason": "<one sentence, under 80 chars, specific reason why this skill helps them>" },
  { "skill": "<skill name>", "reason": "<reason>" },
  { "skill": "<skill name>", "reason": "<reason>" }
]

Prioritize skills that appear most frequently in their applications and complement what they already know. Do not recommend skills they already have.
''';

    print('--- GET SKILL RECOMMENDATIONS PROMPT ---');
    print(prompt);
    final result = await _call(prompt, jsonMode: true);
    print('--- GET SKILL RECOMMENDATIONS RAW RESULT ---');
    print(result);
    if (result == null) return null;
    try {
      final cleaned = result
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final list = jsonDecode(cleaned) as List;
      return list.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (e) {
      print('getSkillRecommendations JSON Parse Error: $e');
      return null;
    }
  }

  // Feature 4 — listing quality checker
  static Future<Map<String, dynamic>?> checkListingQuality({
    required String title,
    required String type,
    required String description,
    required List<String> requiredSkills,
    required String compensationType,
    required String locationType,
    required DateTime deadline,
  }) async {
    final daysUntilDeadline = deadline.difference(DateTime.now()).inDays;
    final prompt = '''
You are reviewing a job listing posted by a university student founder on a campus hiring platform. Be constructive.

Title: $title
Type: $type
Description: $description
Required skills: ${requiredSkills.join(', ')} (${requiredSkills.length} total)
Compensation: $compensationType
Location: $locationType
Days until deadline: $daysUntilDeadline

Return a JSON object with exactly this structure, no markdown, no code block, raw JSON only:
{
  "qualityScore": <integer 0-100>,
  "issues": [
    { "field": "<title|description|requiredSkills|compensation|deadline>", "severity": "<high|medium|low>", "message": "<specific actionable message under 100 chars>" }
  ],
  "suggestedTitle": "<improved title under 60 chars>"
}

Issues array can be empty if the listing is good. Only flag real problems. A description under 100 characters is always a high severity issue. More than 7 required skills is a medium severity issue for a student startup. A deadline under 5 days is a low severity issue.
''';

    print('--- CHECK LISTING QUALITY PROMPT ---');
    print(prompt);
    final result = await _call(prompt, jsonMode: true);
    print('--- CHECK LISTING QUALITY RAW RESULT ---');
    print(result);
    if (result == null) return null;
    try {
      final cleaned = result
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      print('checkListingQuality JSON Parse Error: $e');
      return null;
    }
  }

  // Feature 5 — conversational listing discovery
  static Future<List<Map<String, dynamic>>?> findMatchingListings({
    required String userQuery,
    required List<String> studentSkills,
    required List<Map<String, dynamic>> listings,
  }) async {
    final listingsSummary = listings.map((l) => {
      'id': l['listingId'],
      'title': l['title'],
      'type': l['type'],
      'startup': l['startupName'] ?? '',
      'skills': (l['requiredSkills'] as List?)?.join(', ') ?? '',
      'compensationType': l['compensationType'] ?? 'negotiable',
      'compensationDetails': l['compensationDetails'] ?? '',
      'locationType': l['locationType'] ?? 'remote',
      'description': (l['description'] as String?)?.substring(
            0,
            ((l['description'] as String?)?.length ?? 0) > 150 ? 150 : ((l['description'] as String?)?.length ?? 0),
          ) ?? '',
    }).toList();

    final prompt = '''
A university student is searching for opportunities on a campus startup hiring platform using natural language.

Student query: "$userQuery"
Student skills: ${studentSkills.join(', ')}

Available listings:
${jsonEncode(listingsSummary)}

Return a JSON array of the top 3 most relevant listing IDs and a short reason for each. Raw JSON only, no markdown:
[
  { "listingId": "<id>", "reason": "<one sentence under 80 chars why this matches their query>" },
  { "listingId": "<id>", "reason": "<reason>" },
  { "listingId": "<id>", "reason": "<reason>" }
]

If fewer than 3 listings are relevant, return only the relevant ones. Match based on the student's intent, their skills, and listing content. Return an empty array if nothing is relevant.
''';

    print('--- FIND MATCHING LISTINGS PROMPT ---');
    print(prompt);
    final result = await _call(prompt, jsonMode: true);
    print('--- FIND MATCHING LISTINGS RAW RESULT ---');
    print(result);
    if (result == null) return null;
    try {
      final cleaned = result
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final list = jsonDecode(cleaned) as List;
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      print('findMatchingListings JSON Parse Error: $e');
      return null;
    }
  }
}
