import 'package:cloud_firestore/cloud_firestore.dart';

class FAQ {
  final String id;
  final String question;
  final String answer;
  final String category;
  final bool isPredefined;
  final Timestamp createdAt;
  final List<double> embedding;
  final int count;
  final Timestamp lastAsked;

  FAQ({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
    required this.isPredefined,
    required this.createdAt,
    required this.embedding,
    required this.count,
    required this.lastAsked,
  });

  /// Factory constructor for creating a FAQ from Firestore
  factory FAQ.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return FAQ(
      id: doc.id,
      question: data['question'] ?? '',
      answer: data['answer'] ?? '',
      category: data['category'] ?? 'General',
      isPredefined: data['isPredefined'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      embedding: (data['embedding'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      count: data['count'] ?? 0,
      lastAsked: data['lastAsked'] ?? Timestamp.now(),
    );
  }

  /// Convert model to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'answer': answer,
      'category': category,
      'isPredefined': isPredefined,
      'createdAt': createdAt,
      'embedding': embedding,
      'count': count,
      'lastAsked': lastAsked,
    };
  }
}
