class Question {
  final String id;
  final String question;
  final List<String> options;
  final String answer;
  final String explanation;
  final String topic;
  final String difficulty;

  Question({
    required this.id,
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
    required this.topic,
    required this.difficulty,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String? ?? '',
      question: json['question'] as String? ?? '',
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      answer: json['answer'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'answer': answer,
      'explanation': explanation,
      'topic': topic,
      'difficulty': difficulty,
    };
  }
}