import 'package:cloud_firestore/cloud_firestore.dart';

class Admissions {
  final String id;
  final String title;
  final String content;
  final String source;
  final String? academicYear;
  final List<String>? contact;
  final List<String> steps;
  final List<String>? links;
  final DateTime createdAt;

  Admissions({
    required this.id,
    required this.title,
    required this.content,
    required this.source,
    this.academicYear,
    this.contact,
    this.links,
    required this.steps,
    required this.createdAt,
  });

  factory Admissions.fromJson(Map<String, dynamic> json) {
    return Admissions(
      id: json['id'] ?? json['ibID'] ?? 'unknown',
      title: json['title'] ?? json['ib_title'] ?? 'No title',
      content: json['content'] ?? 'No content',
      source: json['source'] ?? 'Unknown source',
      academicYear: json['academicYear'] ?? 'Unknown Year',
      contact: _parseStringList(json['contact'])?? <String>[],
      steps: _parseStringList(json['steps']) ?? <String>[],
      links: _parseStringList(json['links']) ?? <String>[],
      createdAt:
          json['createdAt'] is String
              ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
              : (json['createdAt'] is Timestamp
                  ? (json['createdAt'] as Timestamp).toDate()
                  : DateTime.now()),
    );
  }

  // Helper method to safely parse List<String>
  static List<String>? _parseStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String) {
      return [value];
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'source': source,
      'academicYear': academicYear,
      'contact': contact,
      'steps': steps,
      'links':links,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
