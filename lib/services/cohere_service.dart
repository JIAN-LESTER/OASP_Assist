import 'dart:convert';

import 'package:http/http.dart' as http;

class CohereService {
  // 🔐 Use environment variable in production
  // final String apiKey ="IhyfOnMhPrpfgiDSqf3c0ayCmGpHAicG1JqbGVOY";
  final String apiKey1 ="jGVDZpXJocGrUpJkP2YAMrQAIkcCQu7YITqcRr5h";
  final String apiKey ="AIzaSyBEsKofC_0dTYRNwFhjnnY8jzuhmQqbHQI";
  // final embedUrl = Uri.parse('https://api.cohere.ai/v1/embed');
  final chatUrl1 = Uri.parse('https://api.cohere.ai/v1/chat'); 

    final String embedModel = "models/text-embedding-004";


  String get embedUrl => "https://generativelanguage.googleapis.com/v1beta/$embedModel:embedContent?key=$apiKey";
  // Future<List<double>> embedText(
  //   String text, {
  //   String inputType = 'search_document',
  // }) async {
  //   final res = await http.post(
  //     embedUrl,
  //     headers: {
  //       'Authorization': 'Bearer $apiKey',
  //       'Content-Type': 'application/json',
  //     },
  //     body: jsonEncode({
  //       'texts': [text],
  //       'model': 'embed-multilingual-v3.0',
  //       'input_type': inputType,
  //     }),
  //   );

  //   if (res.statusCode != 200) {
  //     print('Embed API error response: ${res.body}');
  //     throw Exception('Failed to embed text: ${res.body}');
  //   }

  //   final data = jsonDecode(res.body);
  //   return List<double>.from(data['embeddings'][0]);
  // }

  Future<List<double>> embedText(
    String text, {
    String taskType = 'RETRIEVAL_DOCUMENT',
  }) async {
    try {
      final response = await http.post(
        Uri.parse(embedUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': embedModel,
          'content': {
            'parts': [
              {'text': text}
            ]
          },
          'taskType': taskType, // RETRIEVAL_DOCUMENT or RETRIEVAL_QUERY
        }),
      );

      if (response.statusCode != 200) {
        print('❌ Gemini Embed API error: ${response.body}');
        throw Exception('Failed to generate embedding: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final embedding = data['embedding']['values'] as List;
      final embeddingList = embedding.map((e) => (e as num).toDouble()).toList();
      
      return embeddingList;
    } catch (e) {
      print('❌ Error generating Gemini embedding: $e');
      rethrow;
    }
  }


  Future<String> generateResponse(String prompt) async {
    final res = await http.post(
      chatUrl1, // Using Chat API instead of deprecated Generate API
      headers: {
        'Authorization': 'Bearer $apiKey1',
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

  //   Future<String> generateResponse(String prompt) async {
  //   try {
  //     final response = await http.post(
  //       Uri.parse(chatUrl),
  //       headers: {
  //         'Content-Type': 'application/json',
  //       },
  //       body: jsonEncode({
  //         'contents': [
  //           {
  //             'parts': [
  //               {'text': prompt}
  //             ]
  //           }
  //         ],
  //         'generationConfig': {
  //           'temperature': 0.3,
  //           'maxOutputTokens': 1024,
  //         }
  //       }),
  //     );

  //     if (response.statusCode != 200) {
  //       print('❌ Gemini Chat API error: ${response.body}');
  //       throw Exception('Failed to generate response: ${response.body}');
  //     }

  //     final data = jsonDecode(response.body);
  //     return data['candidates'][0]['content']['parts'][0]['text'] ?? '';
  //   } catch (e) {
  //     print('❌ Error generating Gemini response: $e');
  //     rethrow;
  //   }
  // }

Future<Map<String, dynamic>> analyzeAdmission(String message) async {
  Map<String, int>? parseAcademicYear(String? yearStr, String fallbackText) {
    if ((yearStr == null || yearStr.trim().isEmpty) && fallbackText.isNotEmpty) {
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

  try {
    if (message.trim().isEmpty) {
      print("❌ Empty message provided to analyzeAdmission");
      return _fallbackAdmissionExtraction(message);
    }

    print("📄 Admission input message length: ${message.length}");

    final prompt = '''
Analyze the following admission document and extract the academic year, ALL contact information, ALL admission steps, ALL requirements, ALL links, and ANY schedules if present.

Admission Document: "$message"

CRITICAL INSTRUCTIONS:
- Extract EVERY SINGLE step mentioned (usually numbered [1] to [11])
- Extract ALL requirements (documents needed: Form 137, Form 138, NSO Birth Certificate, Certificate of Good Moral, Medical Certificate, ID Pictures, etc.)
- Preserve the original order and numbering
- For academic year, find "S.Y." or "A.Y." followed by a year range like "2024-2025" or "2026-2027"
- Extract only valid contact information (emails, phone numbers)
- Extract all valid websites separately into the "links" field
- If there are schedules with dates and locations (like exam schedules), extract them in the schedules array

Return valid JSON only in this exact format:
{
  "contacts": [
    {"type": "email", "value": "admissions@cmu.edu.ph"},
    {"type": "phone", "value": "+639123456789"}
  ],
  "steps": [
    "Step 1: Fill out the online application form",
    "Step 2: Submit all required documents"
  ],
  "requirements": [
    "Form 137 (Original Copy)",
    "Form 138 (Original Copy)",
    "NSO Birth Certificate",
    "Certificate of Good Moral Character",
    "Medical Certificate",
    "2x2 ID Pictures (2 copies)"
  ],
  "academicYear": "2024-2025",
  "links": [
    "https://cmu.edu.ph",
    "https://devops.cmu.edu.ph/doorstep/"
  ],
  "schedules": [
    {
      "date": "OCT 4, 2025",
      "dayOfWeek": "SATURDAY",
      "locations": ["Kalilangan, Bukidnon", "Impasug-ong, Bukidnon"]
    },
    {
      "date": "OCT 11, 2025",
      "dayOfWeek": "SATURDAY",
      "locations": ["Quezon, Bukidnon", "Malaybalay City, Bukidnon"]
    }
  ]
}

If no schedules are found, return an empty schedules array.
''';

    final response = await http.post(
      chatUrl1,
      headers: {
        'Authorization': 'Bearer $apiKey1',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'command-r-08-2024',
        'message': prompt,
        'max_tokens': 3500, // Increased for schedules
        'temperature': 0.0,
      }),
    );

    
      // final response = await http.post(
      //   Uri.parse(chatUrl),
      //   headers: {
      //     'Content-Type': 'application/json',
      //   },
      //   body: jsonEncode({
      //     'contents': [
      //       {
      //         'parts': [
      //           {'text': prompt}
      //         ]
      //       }
      //     ],
      //     'generationConfig': {
      //       'temperature': 0.0,
      //       'maxOutputTokens': 3500,
      //     }
      //   }),
      // );

    print("📡 Cohere API Response Status: ${response.statusCode}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String generatedText = data['text']?.toString().trim() ?? '';

      if (generatedText.isEmpty) {
        print("❌ Empty response from Cohere API");
        return _fallbackAdmissionExtraction(message);
      }

      print("🔍 Generated Text: $generatedText");

      String cleanedResponse = _extractJsonFromResponse(generatedText);
      print("🧹 Cleaned response: $cleanedResponse");

      Map<String, dynamic> result;
      try {
        result = jsonDecode(cleanedResponse);
      } catch (e) {
        print("❌ JSON decode error: $e");
        return _fallbackAdmissionExtraction(message);
      }

      List<Map<String, dynamic>> contacts = _processContacts(result['contacts']);
      List<String> steps = _processSteps(result['steps']);
      List<String> requirements = _processStringList(result['requirements']);
      List<String> links = (result['links'] is List)
          ? List<String>.from(result['links'].map((e) => e.toString()))
          : [];
      
      // ✅ NEW: Process schedules
      List<Map<String, dynamic>> schedules = [];
      if (result['schedules'] is List) {
        for (var schedule in result['schedules']) {
          if (schedule is Map) {
            schedules.add({
              'date': schedule['date']?.toString() ?? '',
              'dayOfWeek': schedule['dayOfWeek']?.toString() ?? '',
              'locations': schedule['locations'] is List
                  ? List<String>.from(schedule['locations'].map((e) => e.toString()))
                  : [],
            });
          }
        }
      }

      // Convert academic year to numeric map
      Map<String, int>? academicYearMap = parseAcademicYear(
        result['academicYear']?.toString(),
        message,
      );

      if (steps.isEmpty) {
        print("⚠️ No steps extracted, using fallback");
        final fallbackResult = _fallbackAdmissionExtraction(message);
        steps = fallbackResult['steps'] as List<String>;
      }

      if (requirements.isEmpty) {
        print("⚠️ No requirements extracted, using fallback");
        final fallbackResult = _fallbackAdmissionExtraction(message);
        requirements = fallbackResult['requirements'] as List<String>;
      }

      if (contacts.isEmpty && links.isEmpty) {
        print("⚠️ No valid contacts or links extracted, using fallback");
        final fallbackResult = _fallbackAdmissionExtraction(message);
        contacts = fallbackResult['contacts'] as List<Map<String, dynamic>>;
        links = fallbackResult['links'] as List<String>;
      }

      // ✅ NEW: If no schedules from AI, try fallback extraction
      if (schedules.isEmpty) {
        final fallbackResult = _fallbackAdmissionExtraction(message);
        schedules = fallbackResult['schedules'] as List<Map<String, dynamic>>? ?? [];
      }

      print("✅ Extracted: ${steps.length} steps, ${requirements.length} requirements, ${contacts.length} contacts, ${schedules.length} schedules");

      return {
        'contacts': contacts,
        'steps': steps,
        'requirements': requirements,
        'academicYear': academicYearMap,
        'links': links,
        'schedules': schedules, // ✅ NEW
      };
    } else {
      print("❌ Cohere API error: ${response.statusCode}");
      print("📄 Error response: ${response.body}");
      return _fallbackAdmissionExtraction(message);
    }
  } catch (e) {
    print('❌ Error analyzing admission with Cohere: $e');
    return _fallbackAdmissionExtraction(message);
  }
}

// Updated fallback extraction
Map<String, dynamic> _fallbackAdmissionExtraction(String text) {
  print("🔧 Using fallback admission extraction");

  List<String> steps = <String>[];
  List<String> requirements = <String>[];
  List<Map<String, dynamic>> contacts = <Map<String, dynamic>>[];
  List<String> links = <String>[];
  List<Map<String, dynamic>> schedules = <Map<String, dynamic>>[]; // ✅ NEW
  Map<String, int>? academicYear;

  final requirementKeywords = [
    'Form 137', 'Form 138', 'NSO Birth Certificate', 'Birth Certificate',
    'Certificate of Good Moral', 'Good Moral Character', 'Medical Certificate',
    'ID Picture', 'Transcript of Records', 'TOR', 'Diploma',
    'Certificate of Registration', 'Marriage Certificate', 'Police Clearance',
    '2x2', 'ID Photo', 'Passport Size'
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

  final emailRegex = RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b');
  final phoneRegex = RegExp(r'(?<!\d)(?:\+63|63|0)?[89]\d{9}(?!\d)');
  final websiteRegex = RegExp(r'https?:\/\/[\w\.-]+\.[\w]{2,}(?:\/[\w\.-]*)*');

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

  // Extract academic year as numeric map
  final yearRegex = RegExp(r'(?:S\.Y\.|A\.Y\.)\s*(20\d{2}\s*[-–]?\s*20\d{2}?)', caseSensitive: false);
  final yearMatch = yearRegex.firstMatch(text);
  if (yearMatch != null) {
    final rangeRegex = RegExp(r'(\d{4})\s*[-–]\s*(\d{4})');
    final singleRegex = RegExp(r'(\d{4})');
    final yearStr = yearMatch.group(1) ?? '';
    
    final rangeMatch = rangeRegex.firstMatch(yearStr);
    if (rangeMatch != null) {
      academicYear = {
        'start': int.parse(rangeMatch.group(1)!),
        'end': int.parse(rangeMatch.group(2)!),
      };
    } else {
      final singleMatch = singleRegex.firstMatch(yearStr);
      if (singleMatch != null) {
        academicYear = {'start': int.parse(singleMatch.group(1)!)};
      }
    }
  }

  // ✅ NEW: Extract schedules
  final monthRegex = RegExp(r'(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)\s+(\d{1,2})', caseSensitive: false);
  final dayRegex = RegExp(r'(MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY|SUNDAY)', caseSensitive: false);
  
  String? currentDate;
  String? currentDay;
  List<String> currentLocations = [];

  for (String line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    // Check for date pattern
    final dateMatch = monthRegex.firstMatch(trimmed);
    if (dateMatch != null) {
      // Save previous schedule if exists
      if (currentDate != null && currentLocations.isNotEmpty) {
        schedules.add({
          'date': currentDate,
          'dayOfWeek': currentDay ?? '',
          'locations': List<String>.from(currentLocations),
        });
        currentLocations = [];
      }
      
      currentDate = '${dateMatch.group(1)!.toUpperCase()} ${dateMatch.group(2)}';
      
      // Check for day of week
      final dayMatch = dayRegex.firstMatch(trimmed);
      if (dayMatch != null) {
        currentDay = dayMatch.group(1)!.toUpperCase();
      }
    } else if (currentDate != null && trimmed.isNotEmpty && !trimmed.contains('2025') && !trimmed.contains('2026')) {
      // This might be a location
      if (trimmed.length > 3 && !trimmed.toLowerCase().contains('schedule')) {
        currentLocations.add(trimmed);
      }
    }
  }

  // Add last schedule if exists
  if (currentDate != null && currentLocations.isNotEmpty) {
    schedules.add({
      'date': currentDate,
      'dayOfWeek': currentDay ?? '',
      'locations': List<String>.from(currentLocations),
    });
  }

  print("🔧 Fallback extracted ${steps.length} steps, ${requirements.length} requirements, ${contacts.length} contacts, ${schedules.length} schedules");

  return {
    'contacts': contacts,
    'steps': steps,
    'requirements': requirements,
    'academicYear': academicYear,
    'links': links,
    'schedules': schedules, // ✅ NEW
  };
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


  Future<Map<String, dynamic>> analyzeScholarship(String message) async {
  try {
    if (message.trim().isEmpty) {
      print("❌ Empty message provided to analyzeScholarship");
      return {"scholarships": [], "deadline": null};
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
- deadline: Application deadline (YYYY-MM-DD format if found, be very careful to extract accurate dates)
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

Extract every scholarship mentioned. Use null for missing deadline.
''';


      


    final response = await http.post(
      chatUrl1,
      headers: {
        'Authorization': 'Bearer $apiKey1',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'command-r-08-2024',
        'message': prompt,
        'max_tokens': 3500, // Increased for schedules
        'temperature': 0.0,
      }),
    );


    print("📡 Cohere Scholarship API Response Status: ${response.statusCode}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String generatedText = data['text']?.toString().trim() ?? '';

      if (generatedText.isEmpty) {
        return {"scholarships": [], "deadline": null};
      }

      try {
        String cleaned = _extractJsonFromResponse(generatedText);
        final result = jsonDecode(cleaned);

        List<Map<String, dynamic>> scholarships = [];
        DateTime? extractedDeadline;

        if (result['scholarships'] is List) {
          for (var s in result['scholarships']) {
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
                "scholarshipProvider": s["scholarshipProvider"]?.toString().trim() ?? "",
                "eligibilityRequirements": _processStringList(s["eligibilityRequirements"]),
                "privileges": _processStringList(s["privileges"]),
                "deadline": s["deadline"]?.toString().trim() ?? "",
                "application_link": s["application_link"]?.toString().trim() ?? "",
              });
            }
          }
        }

        print("✅ Successfully parsed ${scholarships.length} scholarships with deadline: $extractedDeadline");
        return {"scholarships": scholarships, "deadline": extractedDeadline};
      } catch (e) {
        print("❌ JSON parsing error: $e");
        return {"scholarships": [], "deadline": null};
      }
    } else {
      print("❌ Cohere API error: ${response.statusCode}");
      return {"scholarships": [], "deadline": null};
    }
  } catch (e) {
    print('❌ Error analyzing scholarship with Cohere: $e');
    return {"scholarships": [], "deadline": null};
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
- deadline: Application deadline (YYYY-MM-DD format if found)
- createdAt: Current timestamp in ISO 8601 format

Respond in valid JSON format only:
{
  "placements": [
    {
      "placementID": "unique-id",
      "partnerCompany": "Company Name",
      "contacts": ["contact@company.com", "09123456789"],
      "positions": ["Position 1", "Position 2"],
      "deadline": "2024-12-31",
      "createdAt": "2025-09-08T10:15:30Z"
    }
  ]
}
''';


     

    final response = await http.post(
      chatUrl1,
      headers: {
        'Authorization': 'Bearer $apiKey1',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'command-r-08-2024',
        'message': prompt,
        'max_tokens': 3500, // Increased for schedules
        'temperature': 0.0,
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

  
}