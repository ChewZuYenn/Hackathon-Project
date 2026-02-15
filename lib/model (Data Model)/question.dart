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
    try {
      // Validate required fields exist
      if (json['id'] == null) {
        throw Exception('Missing required field: id');
      }
      if (json['question'] == null) {
        throw Exception('Missing required field: question');
      }
      if (json['options'] == null) {
        throw Exception('Missing required field: options');
      }
      if (json['correctAnswer'] == null) {
        throw Exception('Missing required field: correctAnswer');
      }
      if (json['explanation'] == null) {
        throw Exception('Missing required field: explanation');
      }

      // Parse options list safely
      List<String> optionsList;
      if (json['options'] is List) {
        optionsList = (json['options'] as List)
            .map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
      } else {
        throw Exception('options must be a list');
      }

      // Validate we have exactly 4 options
      if (optionsList.length != 4) {
        throw Exception('Question must have exactly 4 options, got ${optionsList.length}');
      }

      // Validate correctAnswer is one of the options
      final correctAnswer = json['correctAnswer'].toString();
      if (!optionsList.contains(correctAnswer)) {
        throw Exception('correctAnswer "$correctAnswer" not found in options: $optionsList');
      }

      return Question(
        id: json['id'].toString(),
        question: json['question'].toString(),
        options: optionsList,
        correctAnswer: correctAnswer,
        explanation: json['explanation'].toString(),
      );
    } catch (e) {
      print('❌ Error parsing Question from JSON: $e');
      print('📄 JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
    };
  }

  @override
  String toString() {
    return 'Question(id: $id, question: $question, options: $options, correctAnswer: $correctAnswer)';
  }
}