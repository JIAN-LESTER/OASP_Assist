import 'package:cloud_firestore/cloud_firestore.dart';

class Scholarship {
  final String scholarshipID;
  final String name;
  final String description;
  final String scholarshipProvider;
  final List<String> eligibilityRequirements;
  final List<String> privileges;
  final DateTime? deadline;
  final String applicationLink;
  final String sourceId;
  final DateTime createdAt;

  Scholarship({
    required this.scholarshipID,
    required this.name,
    required this.description,
    required this.scholarshipProvider,
    required this.eligibilityRequirements,
    required this.privileges,
    required this.sourceId,
    required this.deadline,
    required this.applicationLink,
    required this.createdAt,
  });

  factory Scholarship.fromJson(Map<String, dynamic> json) {
    print(" Scholarship.fromJson input: $json");

    try {
      final scholarship = Scholarship(
        scholarshipID: json['scholarshipID']?.toString() ?? 'unknown',
        sourceId: json['sourceId']?.toString() ?? 'unknown',
        name: json['name']?.toString() ?? 'No name',
        description: json['description']?.toString() ?? 'No description',
        scholarshipProvider:
            json['scholarshipProvider']?.toString() ?? 'Unknown provider',
        eligibilityRequirements:
            json['eligibilityRequirements'] is List
                ? List<String>.from(
                  json['eligibilityRequirements'].map((e) => e.toString()),
                )
                : <String>[],
        privileges:
            json['privileges'] is List
                ? List<String>.from(json['privileges'].map((e) => e.toString()))
                : <String>[],
        deadline: _parseDate(json['deadline']),
        createdAt:
            json['createdAt'] is String
                ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
                : (json['createdAt'] is Timestamp
                    ? (json['createdAt'] as Timestamp).toDate()
                    : DateTime.now()),
        applicationLink: json['applicationLink']?.toString() ?? '',
      );

      print(" Scholarship.fromJson created: ${scholarship.toJson()}");
      return scholarship;
    } catch (e) {
      print(" Error in Scholarship.fromJson: $e");
      rethrow;
    }
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;

    if (value is String) {
      return DateTime.tryParse(value);
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'scholarshipID': scholarshipID,
      'sourceId': sourceId,
      'name': name,
      'description': description,
      'scholarshipProvider': scholarshipProvider,
      'eligibilityRequirements': eligibilityRequirements,
      'privileges': privileges,
      //   Store as Firestore Timestamp instead of ISO string
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'applicationLink': applicationLink,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
