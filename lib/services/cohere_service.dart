import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class CohereService {
  // 🔐 Use environment variable in production
  final String apiKey ="IhyfOnMhPrpfgiDSqf3c0ayCmGpHAicG1JqbGVOY";
  final embedUrl = Uri.parse('https://api.cohere.ai/v1/embed');
  final chatUrl = Uri.parse('https://api.cohere.ai/v1/chat'); // Updated to Chat API

  Future<List<double>> embedText(
    String text, {
    String inputType = 'search_document',
  }) async {
    final res = await http.post(
      embedUrl,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'texts': [text],
        'model': 'embed-multilingual-v3.0',
        'input_type': inputType,
      }),
    );

    if (res.statusCode != 200) {
      print('Embed API error response: ${res.body}');
      throw Exception('Failed to embed text: ${res.body}');
    }

    final data = jsonDecode(res.body);
    return List<double>.from(data['embeddings'][0]);
  }

  Future<String> generateResponse(String prompt) async {
    final res = await http.post(
      chatUrl, // Using Chat API instead of deprecated Generate API
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'command-r-08-2024', 
        'message': prompt,
        'max_tokens': 1024,
        'temperature': 0.3,
      }),
    );

    if (res.statusCode != 200) {
      print('Chat API error response: ${res.body}');
      throw Exception('Failed to generate response: ${res.body}');
    }

    final data = jsonDecode(res.body);
    return data['text'] ?? '';
  }

 Future<Map<String, dynamic>> analyzeAdmission(String message) async {
  try {
    if (message.trim().isEmpty) {
      print("❌ Empty message provided to analyzeAdmission");
      return _fallbackStepExtraction(message);
    }

    print("📄 Admission input message length: ${message.length}");

    final prompt = '''
Analyze the following admission document and extract the academic year, ALL contact information, ALL admission steps, and ALL links.

Admission Document: "$message"

CRITICAL INSTRUCTIONS:
- Extract EVERY SINGLE step mentioned in the document (usually numbered [1] to [11] or similar)
- Preserve the original order and numbering
- Include ALL details for each step
- For academic year, find "S.Y." followed by a year range like "2024-2025"
- Extract only valid contact information (emails, phone numbers)
- Extract all valid websites separately into the "links" field

Return valid JSON only in this exact format:
{
  "contacts": [
    {"type": "email", "value": "admissions@cmu.edu.ph"},
    {"type": "phone", "value": "+639123456789"}
  ],
  "steps": [
    "Step 1: Fill out the online application form",
    "Step 2: Submit all required documents",
    "Step 3: Pay the application fee"
  ],
  "academicYear": "2024-2025",
  "links": [
    "https://cmu.edu.ph",
    "https://devops.cmu.edu.ph/doorstep/"
  ]
}
''';

    final response = await http.post(
      chatUrl,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'command-r-08-2024',
        'message': prompt,
        'max_tokens': 3000,
        'temperature': 0.0,
      }),
    );

    print("📡 Cohere API Response Status: ${response.statusCode}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String generatedText = data['text']?.toString().trim() ?? '';

      if (generatedText.isEmpty) {
        print("❌ Empty response from Cohere API");
        return _fallbackStepExtraction(message);
      }

      print("🔍 Generated Text: $generatedText");

      String cleanedResponse = _extractJsonFromResponse(generatedText);
      print("🧹 Cleaned response: $cleanedResponse");

      Map<String, dynamic> result;
      try {
        result = jsonDecode(cleanedResponse);
      } catch (e) {
        print("❌ JSON decode error: $e");
        return _fallbackStepExtraction(message);
      }

      List<Map<String, dynamic>> contacts = _processContacts(result['contacts']);
      List<String> steps = _processSteps(result['steps']);
      String academicYear = _extractAcademicYear(result['academicYear'], message);
      List<String> links = (result['links'] is List)
          ? List<String>.from(result['links'].map((e) => e.toString()))
          : [];

      if (steps.isEmpty) {
        print("⚠️ No steps extracted, using fallback");
        Map<String, dynamic> fallbackResult = _fallbackStepExtraction(message);
        steps = fallbackResult['steps'] as List<String>;
      }

      if (contacts.isEmpty && links.isEmpty) {
        print("⚠️ No valid contacts or links extracted, using fallback");
        Map<String, dynamic> fallbackResult = _fallbackStepExtraction(message);
        contacts = fallbackResult['contacts'] as List<Map<String, dynamic>>;
        links = fallbackResult['links'] as List<String>;
      }

      return {
        'contacts': contacts,
        'steps': steps,
        'academicYear': academicYear,
        'links': links,
      };
    } else {
      print("❌ Cohere API error: ${response.statusCode}");
      print("📄 Error response: ${response.body}");
      return _fallbackStepExtraction(message);
    }
  } catch (e) {
    print('❌ Error analyzing admission with Cohere: $e');
    return _fallbackStepExtraction(message);
  }
}

  String _extractJsonFromResponse(String response) {
    // Remove markdown code blocks and extra text
    String cleaned = response
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .replaceAll(RegExp(r'^[^{]*'), '') // Remove text before first {
        .replaceAll(RegExp(r'}[^}]*$'), '}') // Remove text after last }
        .trim();

    // Find JSON boundaries more precisely
    int startIndex = cleaned.indexOf('{');
    int endIndex = -1;
    
    if (startIndex != -1) {
      int braceCount = 0;
      for (int i = startIndex; i < cleaned.length; i++) {
        if (cleaned[i] == '{') braceCount++;
        if (cleaned[i] == '}') {
          braceCount--;
          if (braceCount == 0) {
            endIndex = i;
            break;
          }
        }
      }
    }

    if (startIndex != -1 && endIndex != -1) {
      return cleaned.substring(startIndex, endIndex + 1);
    }

    return cleaned;
  }

  List<Map<String, dynamic>> _processContacts(dynamic contactsData) {
    List<Map<String, dynamic>> contacts = [];

    if (contactsData is List) {
      for (var contact in contactsData) {
        if (contact is Map && contact['type'] != null && contact['value'] != null) {
          String type = contact['type'].toString().toLowerCase();
          String value = contact['value'].toString().trim();
          
          // Validate contact based on type
          if (_isValidContact(type, value)) {
            contacts.add({
              'type': type,
              'value': value,
            });
          }
        }
      }
    }

    return contacts;
  }

  bool _isValidContact(String type, String value) {
    switch (type) {
      case 'email':
        return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(value);
      case 'phone':
        // Remove common non-phone number patterns
        if (RegExp(r'^\d{4}-\d{4}$').hasMatch(value)) return false; // Academic years
        if (value.length < 7) return false; // Too short for phone
        return RegExp(r'^[\+\d\s\-\(\)]{7,}$').hasMatch(value);
      case 'website':
        return RegExp(r'^(https?:\/\/)?[\w\.-]+\.[\w]{2,}').hasMatch(value);
      default:
        return false;
    }
  }

  List<String> _processSteps(dynamic stepsData) {
    List<String> steps = <String>[];

    if (stepsData is List) {
      for (int i = 0; i < stepsData.length; i++) {
        String step = stepsData[i].toString().trim();
        if (step.isNotEmpty && step.length > 10) { // Filter out very short non-descriptive steps
          // Ensure step has proper numbering
          if (!RegExp(r'^\[\d+\]|\d+\.|\bStep\s+\d+').hasMatch(step)) {
            step = '[${i + 1}] $step';
          }
          steps.add(step);
        }
      }
    }

    return steps;
  }

  String _extractAcademicYear(dynamic yearData, String originalText) {
    String academicYear = '';
    
    if (yearData != null && yearData.toString().trim().isNotEmpty) {
      academicYear = yearData.toString().trim();
    }
    
    // Fallback: search in original text
    if (academicYear.isEmpty) {
      final regex = RegExp(r'S\.Y\.\s*(20\d{2}\s*[-–]\s*20\d{2})', caseSensitive: false);
      final match = regex.firstMatch(originalText);
      if (match != null) {
        academicYear = match.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
      }
    }
    
    return academicYear;
  }


Map<String, dynamic> _fallbackStepExtraction(String text) {
  print("🔧 Using fallback step extraction");

  List<String> steps = <String>[];
  List<Map<String, dynamic>> contacts = <Map<String, dynamic>>[];
  List<String> links = <String>[];
  String academicYear = '';

  // Extract steps...
  // (keep your existing stepPatterns extraction code here)

  // Extract contacts
  final emailRegex = RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b');
  final phoneRegex = RegExp(r'(?<!\d)(?:\+63|63|0)?[89]\d{9}(?!\d)');
  final websiteRegex = RegExp(r'https?:\/\/[\w\.-]+\.[\w]{2,}(?:\/[\w\.-]*)*');

  for (RegExpMatch match in emailRegex.allMatches(text)) {
    String email = match.group(0) ?? '';
    if (_isValidContact('email', email)) {
      contacts.add({'type': 'email', 'value': email});
    }
  }

  for (RegExpMatch match in phoneRegex.allMatches(text)) {
    String phone = match.group(0) ?? '';
    if (_isValidContact('phone', phone)) {
      contacts.add({'type': 'phone', 'value': phone});
    }
  }

  for (RegExpMatch match in websiteRegex.allMatches(text)) {
    String website = match.group(0) ?? '';
    if (_isValidContact('website', website)) {
      links.add(website);
    }
  }

  // Extract academic year
  final yearRegex = RegExp(r'S\.Y\.\s*(20\d{2}\s*[-–]\s*20\d{2})', caseSensitive: false);
  final yearMatch = yearRegex.firstMatch(text);
  if (yearMatch != null) {
    academicYear = yearMatch.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  }

  print("🔧 Fallback extracted ${steps.length} steps, ${contacts.length} contacts, ${links.length} links, academicYear: '$academicYear'");

  return {
    'contacts': contacts,
    'steps': steps,
    'academicYear': academicYear,
    'links': links,
  };
}

  Future<Map<String, dynamic>> analyzeScholarship(String message) async {
    try {
      if (message.trim().isEmpty) {
        print("❌ Empty message provided to analyzeScholarship");
        return {"scholarships": []};
      }

      print("📄 Scholarship input message length: ${message.length}");

      final prompt = '''
Analyze the following text and extract ALL scholarship information found.

Text: "$message"

Extract each scholarship with these exact fields:
- name: Official scholarship title
- description: Brief explanation 
- scholarshipProvider: Organization offering it
- eligibilityRequirements: Combined list of eligibility criteria and required documents
- privileges: Benefits provided (tuition, stipend, allowance, etc.)
- deadline: Application deadline (YYYY-MM-DD format if found)
- application_link: URL to apply

Respond in valid JSON format only:
{
  "scholarships": [
    {
      "name": "Scholarship Title",
      "description": "What the scholarship is about",
      "scholarshipProvider": "Organization name",
      "eligibilityRequirements": ["requirement 1", "requirement 2"],
      "privileges": ["benefit 1", "benefit 2"],
      "deadline": "2024-12-31",
      "application_link": "https://example.com" 
    } 
  ]
}

Extract every scholarship mentioned. Use empty strings for missing information.
''';

      final response = await http.post(
        chatUrl,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'command-r-08-2024',
          'message': prompt,
          'max_tokens': 4000,
          'temperature': 0.1,
        }),
      );

      print("📡 Cohere Scholarship API Response Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String generatedText = data['text']?.toString().trim() ?? '';

        if (generatedText.isEmpty) {
          return {"scholarships": []};
        }

        try {
          String cleaned = _extractJsonFromResponse(generatedText);
          final result = jsonDecode(cleaned);

          List<Map<String, dynamic>> scholarships = [];

          if (result['scholarships'] is List) {
            for (var s in result['scholarships']) {
              if (s is Map) {
                scholarships.add({
                  "name": s["name"]?.toString().trim() ?? "",
                  "description": s["description"]?.toString().trim() ?? "",
                  "scholarshipProvider": s["scholarshipProvider"]?.toString().trim() ?? "",
                  "eligibilityRequirements": _processStringList(s["eligibilityRequirements"]),
                  "privileges": _processStringList(s["privileges"]),
                  "deadline": s["deadline"]?.toString().trim() ?? "",
                  "application_link": s["application_link"]?.toString().trim() ?? "",
                });
              }
            }
          }

          print("✅ Successfully parsed ${scholarships.length} scholarships");
          return {"scholarships": scholarships};
        } catch (e) {
          print("❌ JSON parsing error: $e");
          return {"scholarships": []};
        }
      } else {
        print("❌ Cohere API error: ${response.statusCode}");
        return {"scholarships": []};
      }
    } catch (e) {
      print('❌ Error analyzing scholarship with Cohere: $e');
      return {"scholarships": []};
    }
  }

  List<String> _processStringList(dynamic data) {
    if (data is List) {
      return data.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    } else if (data is String && data.trim().isNotEmpty) {
      return data
          .split(RegExp(r'\n|,|•'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return <String>[];
  }

  Future<Map<String, dynamic>> analyzePlacement(String message) async {
    try {
      if (message.trim().isEmpty) {
        print("❌ Empty message provided to analyzePlacement");
        return {"placements": []};
      }

      print("📄 Placement input message length: ${message.length}");

      final prompt = '''
Analyze the following text and extract ALL placement information found.

Text: "$message"

Extract placement information with these fields:
- placementID: Generate unique ID or use existing reference
- partnerCompany: Company or organization name
- contacts: List of contact details (emails, phones)
- positions: List of available positions/roles
- createdAt: Current timestamp in ISO 8601 format

Respond in valid JSON format only:
{
  "placements": [
    {
      "placementID": "unique-id",
      "partnerCompany": "Company Name",
      "contacts": ["contact@company.com", "09123456789"],
      "positions": ["Position 1", "Position 2"],
      "createdAt": "2025-09-08T10:15:30Z"
    }
  ]
}
''';

      final response = await http.post(
        chatUrl,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'command-r-08-2024',
          'message': prompt,
          'max_tokens': 1500,
          'temperature': 0.1,
        }),
      );

      print("📡 Cohere Placement API Response Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String generatedText = data['text']?.toString().trim() ?? '';

        if (generatedText.isEmpty) {
          return {"placements": []};
        }

        try {
          String cleaned = _extractJsonFromResponse(generatedText);
          final result = jsonDecode(cleaned);

          List<Map<String, dynamic>> placements = [];

          if (result['placements'] is List) {
            for (var p in result['placements']) {
              if (p is Map) {
                placements.add({
                  "placementID": p["placementID"]?.toString().trim() ?? "",
                  "partnerCompany": p["partnerCompany"]?.toString().trim() ?? "",
                  "contacts": _processStringList(p["contacts"]),
                  "positions": _processStringList(p["positions"]),
                  "createdAt": p["createdAt"]?.toString().trim() ?? DateTime.now().toIso8601String(),
                });
              }
            }
          }

          print("✅ Successfully parsed ${placements.length} placements");
          return {"placements": placements};
        } catch (e) {
          print("❌ JSON parsing error: $e");
          return {"placements": []};
        }
      } else {
        print("❌ Cohere API error: ${response.statusCode}");
        return {"placements": []};
      }
    } catch (e) {
      print('❌ Error analyzing placement with Cohere: $e');
      return {"placements": []};
    }
  }

  Future<Map<String, dynamic>> analyzeAnnouncement(String message) async {
    try {
      final prompt = '''
Analyze this announcement and categorize it. Also extract any deadlines mentioned.

Announcement: "$message"

Categories:
- Admission: enrollment, registration, application, requirements, class schedule, semester, subjects, programs, exams, clearance
- Scholarship: scholarship, stipend, allowance, grantee, renewal, eligibility, screening, shortlisted, beneficiary, grant
- Placement: placement, hiring, job, employment, employer, resume, cv, interview, company, opportunity, deployment
- General: everything else

Respond in JSON format:
{
  "category": "category_name",
  "deadline": "extracted_date_or_null"
}

For deadlines, extract specific dates and times. Format them clearly. If no deadline found, use null.
''';

      final response = await http.post(
        chatUrl,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'command-r-08-2024',
          'message': prompt,
          'max_tokens': 200,
          'temperature': 0.3,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final generatedText = data['text']?.toString().trim() ?? '';

        try {
          String cleanedResponse = _extractJsonFromResponse(generatedText);
          final result = jsonDecode(cleanedResponse);
          
          String category = result['category']?.toString() ?? 'General';
          String? deadline = result['deadline']?.toString();

          category = _cleanCategory(category);
          if (deadline != null && (deadline.toLowerCase() == 'null' || deadline.trim().isEmpty)) {
            deadline = null;
          }

          return {'category': category, 'deadline': deadline};
        } catch (e) {
          return _fallbackAnalysis(message);
        }
      } else {
        throw Exception('Cohere API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error analyzing announcement with Cohere: $e');
      return _fallbackAnalysis(message);
    }
  }

  String _cleanCategory(String category) {
    final cleanedCategory = category.toLowerCase().trim();
    if (cleanedCategory.contains('admission') || cleanedCategory.contains('enroll')) {
      return 'Admission';
    } else if (cleanedCategory.contains('scholarship') || cleanedCategory.contains('financial aid')) {
      return 'Scholarship';
    } else if (cleanedCategory.contains('placement') || cleanedCategory.contains('job') || cleanedCategory.contains('career')) {
      return 'Placement';
    }
    return 'General';
  }

  Map<String, dynamic> _fallbackAnalysis(String message) {
    final messageLower = message.toLowerCase();
    String category = 'General';
    String? deadline;

    // Category detection
    if (messageLower.contains('enrollment') ||
        messageLower.contains('registration') ||
        messageLower.contains('application') ||
        messageLower.contains('requirements') ||
        messageLower.contains('class schedule') ||
        messageLower.contains('semester') ||
        messageLower.contains('subject') ||
        messageLower.contains('program') ||
        messageLower.contains('exam schedule') ||
        messageLower.contains('clearance') ||
        messageLower.contains('admission')) {
      category = 'Admission';
    } else if (messageLower.contains('scholarship') ||
        messageLower.contains('stipend') ||
        messageLower.contains('allowance') ||
        messageLower.contains('grantee') ||
        messageLower.contains('renewal') ||
        messageLower.contains('eligibility') ||
        messageLower.contains('screening') ||
        messageLower.contains('shortlisted') ||
        messageLower.contains('beneficiary') ||
        messageLower.contains('grant')) {
      category = 'Scholarship';
    } else if (messageLower.contains('placement') ||
        messageLower.contains('hiring') ||
        messageLower.contains('job') ||
        messageLower.contains('employment') ||
        messageLower.contains('employer') ||
        messageLower.contains('resume') ||
        messageLower.contains('cv') ||
        messageLower.contains('interview') ||
        messageLower.contains('company') ||
        messageLower.contains('opportunity') ||
        messageLower.contains('deployment')) {
      category = 'Placement';
    }

    deadline = _extractDeadlines(message);
    return {'category': category, 'deadline': deadline};
  }

  String? _extractDeadlines(String message) {
    final deadlinePatterns = [
      RegExp(r'(?<date>(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},?\s+\d{4}(?:,?\s+at\s+\d{1,2}:\d{2}\s?(?:AM|PM|am|pm))?)', caseSensitive: false),
      RegExp(r'(?<date>\d{1,2}:\d{2}\s?(?:AM|PM|am|pm))', caseSensitive: false),
      RegExp(r'by\s+(?<date>(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},?\s+\d{4})', caseSensitive: false),
    ];

    final List<String> extractedDates = [];

    for (final pattern in deadlinePatterns) {
      final matches = pattern.allMatches(message);
      for (final match in matches) {
        final found = match.namedGroup('date')?.trim();
        if (found != null && found.isNotEmpty) {
          extractedDates.add(found);
        }
      }
    }

    if (extractedDates.isEmpty) return null;
    return extractedDates.length == 1 ? extractedDates.first : extractedDates.join(' & ');
  }

  Future<void> reprocessExistingAnnouncements() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('announcements')
          .where('processed_by_cohere', isEqualTo: false)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final message = data['message'] ?? '';

        if (message.isNotEmpty) {
          try {
            final cohereResult = await analyzeAnnouncement(message);
            await doc.reference.update({
              'category': cohereResult['category'],
              'deadline': cohereResult['deadline'],
              'processed_by_cohere': true,
              'reprocessed_at': FieldValue.serverTimestamp(),
            });
          } catch (e) {
            print('Error reprocessing announcement ${doc.id}: $e');
          }
        }
      }
    } catch (e) {
      print('Error reprocessing existing announcements: $e');
    }
  }
}