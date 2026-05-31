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
  final List<Map<String, dynamic>>? schedules;
  final String? type; //  EXISTING: Type field for CMUCAT, GSAT, ULHSAT

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
    this.schedules,
    this.type, //  Already exists
  });

  factory Admissions.fromJson(Map<String, dynamic> json) {
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
      List<String> stepsList = <String>[];
      if (json['steps'] is List<String>) {
        stepsList = json['steps'] as List<String>;
      } else if (json['steps'] is List) {
        stepsList = (json['steps'] as List).map((e) => e.toString()).toList();
      }

      List<String>? requirementsList;
      if (json['requirements'] is List<String>) {
        requirementsList = json['requirements'] as List<String>;
      } else if (json['requirements'] is List) {
        requirementsList =
            (json['requirements'] as List).map((e) => e.toString()).toList();
      }

      List<String>? linksList;
      if (json['links'] is List) {
        linksList = List<String>.from(json['links'].map((e) => e.toString()));
      }

      List<String>? contactList = _parseStringList(json['contact']);

      Map<String, int>? academicYearMap = parseAcademicYear(
        json['academicYear']?.toString(),
      );

      List<Map<String, dynamic>>? schedulesList;
      if (json['schedules'] is List) {
        schedulesList =
            (json['schedules'] as List)
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
        createdAt:
            json['createdAt'] is String
                ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
                : (json['createdAt'] is Timestamp
                    ? (json['createdAt'] as Timestamp).toDate()
                    : DateTime.now()),
        schedules: schedulesList,
        type: json['type']?.toString(), //  Parse type field
      );
    } catch (e) {
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
      'schedules': schedules,
      'type': type, //  Include type in JSON
    };
  }

  //  Helper method to display type in UI
  String get displayType {
    if (type == null || type!.isEmpty) return 'General Admission';
    return type!; // Returns CMUCAT, GSAT, or ULHSAT
  }

  //  Helper to check if this is a specific test type
  bool isCMUCAT() => type?.toUpperCase() == 'CMUCAT';
  bool isGSAT() => type?.toUpperCase() == 'GSAT';
  bool isULHSAT() => type?.toUpperCase() == 'ULHSAT';
}
