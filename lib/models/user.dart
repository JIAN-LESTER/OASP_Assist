import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String name;
  final String role;
  final String year;
  final String? program;
  final bool? isEnrolled;
  final bool isActive;
  final bool isVerified;
  final bool profileCompleted;
  final String? affiliation;
  final String? scholarship;
  final String? provider;
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    required this.role,
    required this.year,
    this.affiliation,
    this.scholarship,
    this.isEnrolled,
    this.program,
    this.isActive = true,
    this.isVerified = false,
    this.profileCompleted = false,
    this.provider,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      role: json['role'],
      year: json['year'],
      program: json['program'],
      isActive: json['isActive'] ?? true,
      isVerified: json['isVerified'] ?? false,
      isEnrolled: json['isEnrolled'] ?? false,
      profileCompleted: json['profileCompleted'] ?? false,
      affiliation: json['affiliation'],
      scholarship: json['scholarship'],
      provider: json['provider'],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }
}
