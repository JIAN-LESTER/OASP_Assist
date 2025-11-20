import 'package:cloud_firestore/cloud_firestore.dart';

class Admissions {
  final String id;
  final List<String> steps;
  final List<String>? requirements;
  final String title;
  final String content;
  final List<String>? contact;
  final Map<String, int>? academicYear;
  final List<String>? links;
  final String source;
  final DateTime createdAt;
  final List<Map<String, dynamic>>? schedules; // ✅ NEW: Add schedules field

  Admissions({
    required this.id,
    required this.steps,
    this.requirements,
    required this.title,
    required this.content,
    this.contact,
    this.academicYear,
    this.links,
    required this.source,
    required this.createdAt,
    this.schedules, // ✅ NEW
  });

  factory Admissions.fromJson(Map<String, dynamic> json) {
    print("📥 Admissions.fromJson input: $json");

    // Helper to parse academic year string into start/end integers
    Map<String, int>? parseAcademicYear(String? yearStr) {
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
      // Parse steps
      List<String> stepsList = <String>[];
      if (json['steps'] is List<String>) {
        stepsList = json['steps'] as List<String>;
      } else if (json['steps'] is List) {
        stepsList = (json['steps'] as List).map((e) => e.toString()).toList();
      }

      // Parse requirements
      List<String>? requirementsList;
      if (json['requirements'] is List<String>) {
        requirementsList = json['requirements'] as List<String>;
      } else if (json['requirements'] is List) {
        requirementsList = (json['requirements'] as List).map((e) => e.toString()).toList();
      }

      // Parse links
      List<String>? linksList;
      if (json['links'] is List) {
        linksList = List<String>.from(json['links'].map((e) => e.toString()));
      }

      // Parse contacts
      List<String>? contactList = _parseStringList(json['contact']);

      // Parse academic year
      Map<String, int>? academicYearMap = parseAcademicYear(json['academicYear']?.toString());

      // ✅ NEW: Parse schedules
      List<Map<String, dynamic>>? schedulesList;
      if (json['schedules'] is List) {
        schedulesList = (json['schedules'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }

      return Admissions(
        id: json['id']?.toString() ?? 'unknown',
        steps: stepsList,
        requirements: requirementsList,
        title: json['title']?.toString() ?? 'No title',
        content: json['content']?.toString() ?? 'No content',
        contact: contactList ?? [],
        academicYear: academicYearMap,
        links: linksList,
        source: json['source']?.toString() ?? 'Unknown',
        createdAt: json['createdAt'] is String
            ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
            : (json['createdAt'] is Timestamp
                ? (json['createdAt'] as Timestamp).toDate()
                : DateTime.now()),
        schedules: schedulesList, // ✅ NEW
      );
    } catch (e) {
      print("❌ Error in Admissions.fromJson: $e");
      rethrow;
    }
  }

  static List<String>? _parseStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String) return [value];
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'steps': steps,
      'requirements': requirements,
      'title': title,
      'content': content,
      'contact': contact,
      'academicYear': academicYear,
      'links': links,
      'source': source,
      'createdAt': createdAt.toIso8601String(),
      'schedules': schedules, // ✅ NEW
    };
  }
}