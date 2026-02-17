class Question {
  final String id;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String explanation;

  Question({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final optionsList = (json['options'] as List)
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();

    if (optionsList.length != 4) {
      throw Exception('Expected 4 options, got ${optionsList.length}');
    }

    final correctAnswer = json['correctAnswer'].toString().trim();
    if (!optionsList.contains(correctAnswer)) {
      throw Exception(
          'correctAnswer "$correctAnswer" not in options: $optionsList');
    }

    return Question(
      id: json['id'].toString(),
      question: json['question'].toString(),
      options: optionsList,
      correctAnswer: correctAnswer,
      explanation: json['explanation'].toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'options': options,
        'correctAnswer': correctAnswer,
        'explanation': explanation,
      };
}