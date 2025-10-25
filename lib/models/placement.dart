import 'package:cloud_firestore/cloud_firestore.dart';

class Placement {
  final String placementID;
  final String partnerCompany;
  final List<String> contacts;
  final List<String> positions;
  final DateTime createdAt;

  Placement({
    required this.placementID,
    required this.partnerCompany,
    required this.positions,
    required this.contacts,
    required this.createdAt,
  });

  factory Placement.fromJson(Map<String, dynamic> json) {
    return Placement(
      placementID: json['placementID'],
      partnerCompany: json['partnerCompany'],
      contacts:
          json['contacts'] is List
              ? List<String>.from(json['contacts'].map((e) => e.toString()))
              : <String>[],
      positions:
          json['positions'] is List
              ? List<String>.from(json['positions'].map((e) => e.toString()))
              : <String>[],

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
      'contacts': contacts,
      'positions': positions,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
