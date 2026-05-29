import 'package:cloud_firestore/cloud_firestore.dart';

class Placement {
  final String placementID;
  final String partnerCompany;
  final List<String> contacts;
  final List<String> positions;
  final bool isRecruiting;
  final DateTime? deadline;
  final DateTime createdAt;

  Placement({
    required this.placementID,
    required this.partnerCompany,
    required this.positions,
    required this.contacts,
    required this.isRecruiting,
    this.deadline,
    required this.createdAt,
  });

  factory Placement.fromJson(Map<String, dynamic> json) {
    return Placement(
      placementID: json['placementID'] ?? '',
      partnerCompany: json['partnerCompany'] ?? '',
      isRecruiting: json['isRecruiting'] ?? true,
      contacts:
          json['contacts'] is List
              ? List<String>.from(json['contacts'].map((e) => e.toString()))
              : <String>[],
      positions:
          json['positions'] is List
              ? List<String>.from(json['positions'].map((e) => e.toString()))
              : <String>[],
      deadline:
          json['deadline'] != null
              ? (json['deadline'] is String
                  ? DateTime.tryParse(json['deadline'])
                  : (json['deadline'] is Timestamp
                      ? (json['deadline'] as Timestamp).toDate()
                      : null))
              : null,
      createdAt:
          json['createdAt'] is String
              ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
              : (json['createdAt'] is Timestamp
                  ? (json['createdAt'] as Timestamp).toDate()
                  : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'placementID': placementID,
      'partnerCompany': partnerCompany,
      'isRecruiting': isRecruiting,
      'contacts': contacts,
      'positions': positions,
      //  FIX: Store as Firestore Timestamp instead of ISO string
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
