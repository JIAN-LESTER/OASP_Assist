import 'package:cloud_firestore/cloud_firestore.dart';

class FAQCandidate {
  final String id;
  final String question;
  final String answer;
  final String category;
  final List<double> embedding;
  final int occurrenceCount;
  final Timestamp firstSeen;
  final Timestamp lastSeen;
  final String status; // 'pending' | 'promoted' | 'dismissed'

  FAQCandidate({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
    required this.embedding,
    required this.occurrenceCount,
    required this.firstSeen,
    required this.lastSeen,
    required this.status,
  });

  factory FAQCandidate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FAQCandidate(
      id: doc.id,
      question: data['question'] ?? '',
      answer: data['answer'] ?? '',
      category: data['category'] ?? 'General',
      embedding: (data['embedding'] as List<dynamic>? ?? [])
          .map((e) => (e as num).toDouble())
          .toList(),
      occurrenceCount: data['occurrenceCount'] ?? 0,
      firstSeen: data['firstSeen'] ?? Timestamp.now(),
      lastSeen: data['lastSeen'] ?? Timestamp.now(),
      status: data['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'answer': answer,
      'category': category,
      'embedding': embedding,
      'occurrenceCount': occurrenceCount,
      'firstSeen': firstSeen,
      'lastSeen': lastSeen,
      'status': status,
    };
  }
}