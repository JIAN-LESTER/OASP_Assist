import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CohereService {
  final FirebaseFunctions functions = FirebaseFunctions.instance;
  final bool _isDesktop = false;

  // Desktop-only fields
  late final String _cohereApiKey;
  late final String _geminiApiKey;
  late final Uri _chatUrl;
  late final String _embedUrl;

  CohereService() {
    if (_isDesktop) {
      _cohereApiKey = '';
      _geminiApiKey = '';

      if (_cohereApiKey.isEmpty || _geminiApiKey.isEmpty) {
        throw Exception('Cohere/Gemini API keys not found in .env file');
      }

      _chatUrl = Uri.parse('https://api.cohere.ai/v1/chat');
      _embedUrl =
          "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=$_geminiApiKey";

      if (kDebugMode) {
        print('🖥️ Using desktop Cohere implementation');
      }
    } else {
      if (kDebugMode) {
        print(' Using Cloud Functions Cohere implementation');
      }
    }
  }

  static bool _checkIfDesktop() {
    if (kIsWeb) return false;

    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (e) {
      return false;
    }
  }

  // =========================================================================
  // Embed Text (using Gemini)
  // =========================================================================

  Future<List<double>> embedText(
    String text, {
    String taskType = 'RETRIEVAL_DOCUMENT',
  }) async {
    if (_isDesktop) {
      return _embedTextDesktop(text, taskType: taskType);
    } else {
      return _embedTextCloudFunction(text, taskType: taskType);
    }
  }

  Future<List<double>> _embedTextDesktop(
    String text, {
    String taskType = 'RETRIEVAL_DOCUMENT',
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_embedUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'models/gemini-embedding-001',
          'content': {
            'parts': [
              {'text': text},
            ],
          },
        }),
      );

      if (response.statusCode != 200) {
        print(' Gemini Embed API error: ${response.body}');
        throw Exception('Failed to generate embedding: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final embedding = data['embedding']['values'] as List;
      return embedding.map((e) => (e as num).toDouble()).toList();
    } catch (e) {
      print(' Error generating Gemini embedding: $e');
      rethrow;
    }
  }

  Future<List<double>> _embedTextCloudFunction(
    String text, {
    String taskType = 'RETRIEVAL_DOCUMENT',
  }) async {
    try {
      final callable = functions.httpsCallable('generateGeminiEmbedding');
      final result = await callable.call({'text': text, 'taskType': taskType});

      final embedding = result.data['embedding'] as List;
      return embedding.map((e) => (e as num).toDouble()).toList();
    } catch (e) {
      print(' Error generating embedding: $e');
      rethrow;
    }
  }

  // =========================================================================
  // Generate Response
  // =========================================================================

  Future<String> generateResponse(String prompt) async {
    if (_isDesktop) {
      return _generateResponseDesktop(prompt);
    } else {
      return _generateResponseCloudFunction(prompt);
    }
  }

  Future<String> _generateResponseDesktop(String prompt) async {
    try {
      final response = await http.post(
        _chatUrl,
        headers: {
          'Authorization': 'Bearer $_cohereApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'command-r-08-2024',
          'message': prompt,
          'max_tokens': 1024,
          'temperature': 0.3,
        }),
      );

      if (response.statusCode != 200) {
        print('Chat API error response: ${response.body}');
        throw Exception('Failed to generate response: ${response.body}');
      }

      final data = jsonDecode(response.body);
      return data['text'] ?? '';
    } catch (e) {
      print(' Error generating Cohere response: $e');
      rethrow;
    }
  }

  Future<String> _generateResponseCloudFunction(String prompt) async {
    try {
      final callable = functions.httpsCallable('generateCohereResponse');
      final result = await callable.call({'prompt': prompt});
      return result.data['text'] ?? '';
    } catch (e) {
      print(' Error generating Cohere response: $e');
      rethrow;
    }
  }

  // =========================================================================
  // Analyze Admission
  // =========================================================================

  Future<Map<String, dynamic>> analyzeAdmission(String message) async {
    if (_isDesktop) {
      return _analyzeAdmissionDesktop(message);
    } else {
      return _analyzeAdmissionCloudFunction(message);
    }
  }

  Future<Map<String, dynamic>> _analyzeAdmissionDesktop(String message) async {
    try {
      if (message.trim().isEmpty) {
        return _fallbackAdmissionExtraction(message);
      }

      final prompt = '''
Analyze the following admission document and extract the admission type, academic year, ALL contact information, ALL admission steps, ALL requirements, ALL links, and ANY schedules if present.

Admission Document: "$message"

CRITICAL INSTRUCTIONS:
- First, identify the TYPE of admission test:
  * CMUCAT (Central Mindanao University College Admission Test)
  * GSAT (Graduate School Admission Test)
  * ULHSAT (School of Law and Hospitality Studies Admission Test)
  * If no specific test is mentioned, set type to null

- Extract EVERY SINGLE step mentioned
- Extract ALL requirements
- Extract academic year, contact information, links, and schedules

Return valid JSON only in this format:
{
  "type": "CMUCAT",
  "contacts": [{"type": "email", "value": "admissions@cmu.edu.ph"}],
  "steps": ["Step 1: ...", "Step 2: ..."],
  "requirements": ["Form 137", "Form 138"],
  "academicYear": "2024-2025",
  "links": ["https://cmu.edu.ph"],
  "schedules": [{"date": "OCT 4, 2025", "dayOfWeek": "SATURDAY", "locations": ["Location 1"]}]
}
''';

      final response = await http.post(
        _chatUrl,
        headers: {
          'Authorization': 'Bearer $_cohereApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'command-r-08-2024',
          'message': prompt,
          'max_tokens': 3500,
          'temperature': 0.0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String generatedText = data['text']?.toString().trim() ?? '';

        if (generatedText.isEmpty) {
          return _fallbackAdmissionExtraction(message);
        }

        String cleanedResponse = _extractJsonFromResponse(generatedText);

        try {
          final result = jsonDecode(cleanedResponse);
          return _processAdmissionResult(result, message);
        } catch (e) {
          return _fallbackAdmissionExtraction(message);
        }
      } else {
        return _fallbackAdmissionExtraction(message);
      }
    } catch (e) {
      print(' Error analyzing admission: $e');
      return _fallbackAdmissionExtraction(message);
    }
  }

  Future<Map<String, dynamic>> _analyzeAdmissionCloudFunction(
    String message,
  ) async {
    try {
      if (message.trim().isEmpty) {
        return _fallbackAdmissionExtraction(message);
      }

      final callable = functions.httpsCallable('analyzeCohereAdmission');
      final result = await callable.call({'message': message});

      if (result.data['success'] == false) {
        return _fallbackAdmissionExtraction(message);
      }

      return _processAdmissionResult(result.data, message);
    } catch (e) {
      print(' Error analyzing admission: $e');
      return _fallbackAdmissionExtraction(message);
    }
  }

  // =========================================================================
  // Analyze Scholarship
  // =========================================================================

  Future<Map<String, dynamic>> analyzeScholarship(String message) async {
    if (_isDesktop) {
      return _analyzeScholarshipDesktop(message);
    } else {
      return _analyzeScholarshipCloudFunction(message);
    }
  }

  Future<Map<String, dynamic>> _analyzeScholarshipDesktop(
    String message,
  ) async {
    try {
      if (message.trim().isEmpty) {
        return {"scholarships": [], "deadline": null};
      }

      final prompt = '''
Analyze the following text and extract ALL scholarship information.

Text: "$message"

Extract each scholarship with these fields:
- name, description, scholarshipProvider, eligibilityRequirements, privileges, deadline, application_link

Return valid JSON:
{
  "scholarships": [{
    "name": "...",
    "description": "...",
    "scholarshipProvider": "...",
    "eligibilityRequirements": [...],
    "privileges": [...],
    "deadline": "2024-12-31",
    "application_link": "..."
  }]
}
''';

      final response = await http.post(
        _chatUrl,
        headers: {
          'Authorization': 'Bearer $_cohereApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'command-r-08-2024',
          'message': prompt,
          'max_tokens': 3500,
          'temperature': 0.0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String generatedText = data['text']?.toString().trim() ?? '';

        if (generatedText.isEmpty) {
          return {"scholarships": [], "deadline": null};
        }

        try {
          String cleaned = _extractJsonFromResponse(generatedText);
          final result = jsonDecode(cleaned);
          return _processScholarshipResult(result);
        } catch (e) {
          return {"scholarships": [], "deadline": null};
        }
      } else {
        return {"scholarships": [], "deadline": null};
      }
    } catch (e) {
      print(' Error analyzing scholarship: $e');
      return {"scholarships": [], "deadline": null};
    }
  }

  Future<Map<String, dynamic>> _analyzeScholarshipCloudFunction(
    String message,
  ) async {
    try {
      if (message.trim().isEmpty) {
        return {"scholarships": [], "deadline": null};
      }

      final callable = functions.httpsCallable('analyzeCohereScholarship');
      final result = await callable.call({'message': message});

      return _processScholarshipResult(result.data);
    } catch (e) {
      print(' Error analyzing scholarship: $e');
      return {"scholarships": [], "deadline": null};
    }
  }

  // =========================================================================
  // Analyze Placement
  // =========================================================================

  Future<Map<String, dynamic>> analyzePlacement(String message) async {
    if (_isDesktop) {
      return _analyzePlacementDesktop(message);
    } else {
      return _analyzePlacementCloudFunction(message);
    }
  }

  Future<Map<String, dynamic>> _analyzePlacementDesktop(String message) async {
    try {
      if (message.trim().isEmpty) {
        return {"placements": []};
      }

      final prompt = '''
Analyze the following text and extract ALL placement information.

Text: "$message"

Extract: placementID, partnerCompany, contacts, positions, deadline, createdAt

Return valid JSON:
{
  "placements": [{
    "placementID": "...",
    "partnerCompany": "...",
    "contacts": [...],
    "positions": [...],
    "deadline": "2024-12-31",
    "createdAt": "2025-01-13T10:00:00Z"
  }]
}
''';

      final response = await http.post(
        _chatUrl,
        headers: {
          'Authorization': 'Bearer $_cohereApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'command-r-08-2024',
          'message': prompt,
          'max_tokens': 3500,
          'temperature': 0.0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String generatedText = data['text']?.toString().trim() ?? '';

        if (generatedText.isEmpty) {
          return {"placements": []};
        }

        try {
          String cleaned = _extractJsonFromResponse(generatedText);
          final result = jsonDecode(cleaned);
          return _processPlacementResult(result);
        } catch (e) {
          return {"placements": []};
        }
      } else {
        return {"placements": []};
      }
    } catch (e) {
      print(' Error analyzing placement: $e');
      return {"placements": []};
    }
  }

  Future<Map<String, dynamic>> _analyzePlacementCloudFunction(
    String message,
  ) async {
    try {
      if (message.trim().isEmpty) {
        return {"placements": []};
      }

      final callable = functions.httpsCallable('analyzeCoherePlacement');
      final result = await callable.call({'message': message});

      return _processPlacementResult(result.data);
    } catch (e) {
      print(' Error analyzing placement: $e');
      return {"placements": []};
    }
  }

  // =========================================================================
  // Helper Methods
  // =========================================================================

  Map<String, dynamic> _processAdmissionResult(
    Map<String, dynamic> data,
    String message,
  ) {
    String? admissionType = data['type']?.toString();
    if (admissionType == null ||
        admissionType.isEmpty ||
        admissionType == 'null') {
      admissionType = _detectAdmissionType(message);
    }

    List<Map<String, dynamic>> contacts = _processContacts(data['contacts']);
    List<String> steps = _processSteps(data['steps']);
    List<String> requirements = _processStringList(data['requirements']);
    List<String> links =
        (data['links'] is List)
            ? List<String>.from(data['links'].map((e) => e.toString()))
            : [];

    List<Map<String, dynamic>> schedules = [];
    if (data['schedules'] is List) {
      for (var schedule in data['schedules']) {
        if (schedule is Map) {
          schedules.add({
            'date': schedule['date']?.toString() ?? '',
            'dayOfWeek': schedule['dayOfWeek']?.toString() ?? '',
            'locations':
                schedule['locations'] is List
                    ? List<String>.from(
                      schedule['locations'].map((e) => e.toString()),
                    )
                    : [],
          });
        }
      }
    }

    Map<String, int>? academicYearMap;
    if (data['academicYear'] != null) {
      academicYearMap = _parseAcademicYear(
        data['academicYear'].toString(),
        message,
      );
    }

    if (steps.isEmpty ||
        requirements.isEmpty ||
        (contacts.isEmpty && links.isEmpty)) {
      final fallback = _fallbackAdmissionExtraction(message);
      if (steps.isEmpty) steps = fallback['steps'] as List<String>;
      if (requirements.isEmpty)
        requirements = fallback['requirements'] as List<String>;
      if (contacts.isEmpty && links.isEmpty) {
        contacts = fallback['contacts'] as List<Map<String, dynamic>>;
        links = fallback['links'] as List<String>;
      }
      if (schedules.isEmpty) {
        schedules = fallback['schedules'] as List<Map<String, dynamic>>? ?? [];
      }
    }

    return {
      'type': admissionType,
      'contacts': contacts,
      'steps': steps,
      'requirements': requirements,
      'academicYear': academicYearMap,
      'links': links,
      'schedules': schedules,
    };
  }

  Map<String, dynamic> _processScholarshipResult(Map<String, dynamic> data) {
    List<Map<String, dynamic>> scholarships = [];
    DateTime? extractedDeadline;

    if (data['scholarships'] is List) {
      for (var s in data['scholarships']) {
        if (s is Map) {
          DateTime? deadline;
          if (s["deadline"] != null && s["deadline"].toString().isNotEmpty) {
            deadline = DateTime.tryParse(s["deadline"].toString());
            if (deadline != null && extractedDeadline == null) {
              extractedDeadline = deadline;
            }
          }

          scholarships.add({
            "name": s["name"]?.toString().trim() ?? "",
            "description": s["description"]?.toString().trim() ?? "",
            "scholarshipProvider":
                s["scholarshipProvider"]?.toString().trim() ?? "",
            "eligibilityRequirements": _processStringList(
              s["eligibilityRequirements"],
            ),
            "privileges": _processStringList(s["privileges"]),
            "deadline": s["deadline"]?.toString().trim() ?? "",
            "application_link": s["application_link"]?.toString().trim() ?? "",
          });
        }
      }
    }

    return {"scholarships": scholarships, "deadline": extractedDeadline};
  }

  Map<String, dynamic> _processPlacementResult(Map<String, dynamic> data) {
    List<Map<String, dynamic>> placements = [];

    if (data['placements'] is List) {
      for (var p in data['placements']) {
        if (p is Map) {
          DateTime? deadline;
          if (p["deadline"] != null && p["deadline"].toString().isNotEmpty) {
            deadline = DateTime.tryParse(p["deadline"].toString());
          }

          placements.add({
            "placementID": p["placementID"]?.toString().trim() ?? "",
            "partnerCompany": p["partnerCompany"]?.toString().trim() ?? "",
            "contacts": _processStringList(p["contacts"]),
            "positions": _processStringList(p["positions"]),
            "deadline": deadline?.toIso8601String(),
            "createdAt":
                p["createdAt"]?.toString().trim() ??
                DateTime.now().toIso8601String(),
          });
        }
      }
    }

    return {"placements": placements};
  }

  String? _detectAdmissionType(String text) {
    final upperText = text.toUpperCase();
    if (upperText.contains('CMUCAT')) return 'CMUCAT';
    if (upperText.contains('GSAT')) return 'GSAT';
    if (upperText.contains('ULHSAT')) return 'ULHSAT';
    return null;
  }

  Map<String, int>? _parseAcademicYear(String? yearStr, String fallbackText) {
    if ((yearStr == null || yearStr.trim().isEmpty) &&
        fallbackText.isNotEmpty) {
      yearStr = fallbackText;
    }
    if (yearStr == null || yearStr.trim().isEmpty) return null;

    final rangeRegex = RegExp(r'(\d{4})\s*[-–]\s*(\d{4})');
    final singleRegex = RegExp(r'(\d{4})');

    final rangeMatch = rangeRegex.firstMatch(yearStr);
    if (rangeMatch != null) {
      return {
        'start': int.parse(rangeMatch.group(1)!),
        'end': int.parse(rangeMatch.group(2)!),
      };
    }

    final singleMatch = singleRegex.firstMatch(yearStr);
    if (singleMatch != null) {
      return {'start': int.parse(singleMatch.group(1)!)};
    }

    return null;
  }

  Map<String, dynamic> _fallbackAdmissionExtraction(String text) {
    String? detectedType = _detectAdmissionType(text);
    List<String> steps = <String>[];
    List<String> requirements = <String>[];
    List<Map<String, dynamic>> contacts = <Map<String, dynamic>>[];
    List<String> links = <String>[];
    List<Map<String, dynamic>> schedules = <Map<String, dynamic>>[];
    Map<String, int>? academicYear;

    final requirementKeywords = [
      'Form 137',
      'Form 138',
      'NSO Birth Certificate',
      'Birth Certificate',
      'Certificate of Good Moral',
      'Medical Certificate',
      'ID Picture',
      'Transcript of Records',
      'TOR',
      '2x2',
    ];

    final lines = text.split('\n');
    for (String line in lines) {
      final trimmed = line.trim();
      for (String keyword in requirementKeywords) {
        if (trimmed.toLowerCase().contains(keyword.toLowerCase())) {
          if (!requirements.contains(trimmed) && trimmed.length < 200) {
            requirements.add(trimmed);
          }
          break;
        }
      }
    }

    final emailRegex = RegExp(
      r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
    );
    final phoneRegex = RegExp(r'(?<!\d)(?:\+63|63|0)?[89]\d{9}(?!\d)');
    final websiteRegex = RegExp(
      r'https?:\/\/[\w\.-]+\.[\w]{2,}(?:\/[\w\.-]*)*',
    );

    for (final match in emailRegex.allMatches(text)) {
      String email = match.group(0) ?? '';
      if (_isValidContact('email', email)) {
        contacts.add({'type': 'email', 'value': email});
      }
    }

    for (final match in phoneRegex.allMatches(text)) {
      String phone = match.group(0) ?? '';
      if (_isValidContact('phone', phone)) {
        contacts.add({'type': 'phone', 'value': phone});
      }
    }

    for (final match in websiteRegex.allMatches(text)) {
      String website = match.group(0) ?? '';
      if (_isValidContact('website', website)) {
        links.add(website);
      }
    }

    return {
      'type': detectedType,
      'contacts': contacts,
      'steps': steps,
      'requirements': requirements,
      'academicYear': academicYear,
      'links': links,
      'schedules': schedules,
    };
  }

  String _extractJsonFromResponse(String response) {
    String cleaned =
        response
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .replaceAll(RegExp(r'^[^{]*'), '')
            .replaceAll(RegExp(r'}[^}]*$'), '}')
            .trim();

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
        if (contact is Map &&
            contact['type'] != null &&
            contact['value'] != null) {
          String type = contact['type'].toString().toLowerCase();
          String value = contact['value'].toString().trim();

          if (_isValidContact(type, value)) {
            contacts.add({'type': type, 'value': value});
          }
        }
      }
    }

    return contacts;
  }

  bool _isValidContact(String type, String value) {
    switch (type) {
      case 'email':
        return RegExp(
          r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
        ).hasMatch(value);
      case 'phone':
        if (RegExp(r'^\d{4}-\d{4}$').hasMatch(value)) return false;
        if (value.length < 7) return false;
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
        if (step.isNotEmpty && step.length > 10) {
          if (!RegExp(r'^\[\d+\]|\d+\.|\bStep\s+\d+').hasMatch(step)) {
            step = '[${i + 1}] $step';
          }
          steps.add(step);
        }
      }
    }

    return steps;
  }

  List<String> _processStringList(dynamic data) {
    if (data is List) {
      return data
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (data is String && data.trim().isNotEmpty) {
      return data
          .split(RegExp(r'\n|,|•'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return <String>[];
  }
}
