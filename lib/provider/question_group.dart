class QuestionGroup {
  final List<String> questions = [];
  final List<Map<String, dynamic>> questionData = [];
  final List<double> similarities = [];

  int get questionCount => questions.length;
  double get averageSimilarity =>
      similarities.isEmpty
          ? 0.0
          : similarities.reduce((a, b) => a + b) / similarities.length;

  void addQuestion(
    String question,
    Map<String, dynamic> data,
    double similarity,
  ) {
    questions.add(question);
    questionData.add(data);
    similarities.add(similarity);
  }

  String getMostRepresentativeQuestion() {
    if (questions.isEmpty) return '';

    double bestScore = 0.0;
    String bestQuestion = questions.first;

    for (int i = 0; i < questions.length; i++) {
      final question = questions[i];
      final similarity = similarities[i];
      final qualityScore = _calculateQuestionQuality(question);
      final combinedScore = similarity * 0.7 + qualityScore * 0.3;

      if (combinedScore > bestScore) {
        bestScore = combinedScore;
        bestQuestion = question;
      }
    }

    return bestQuestion;
  }
}

// Helper function to calculate question quality
double _calculateQuestionQuality(String question) {
  double score = 0.0;
  final cleanQuestion = question.trim().toLowerCase();

  // Length bonus (up to 1.0)
  score += (cleanQuestion.length / 100).clamp(0.0, 1.0);

  // Question word bonus
  final questionWords = ['what', 'how', 'when', 'where', 'why', 'who'];
  if (questionWords.any((qw) => cleanQuestion.startsWith(qw))) {
    score += 0.5;
  }

  // Academic/domain words bonus
  final domainWords = [
    'admission',
    'scholarship',
    'placement',
    'course',
    'program',
    'requirement',
    'deadline',
    'fee',
    'exam',
  ];
  final domainMatches =
      domainWords.where((dw) => cleanQuestion.contains(dw)).length;
  score += (domainMatches * 0.3);

  return score.clamp(0.0, 5.0);
}

extension DoubleExtension on double {
  String toFixed(int decimals) {
    return toStringAsFixed(decimals);
  }
}
