import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single question attempt by a user
class Attempt {
  final String id;
  final String userId;
  final String examType;
  final String subject;
  final String topic;
  final String difficulty;
  final bool isCorrect;
  final DateTime timestamp;
  final String? questionId;

  Attempt({
    required this.id,
    required this.userId,
    required this.examType,
    required this.subject,
    required this.topic,
    required this.difficulty,
    required this.isCorrect,
    required this.timestamp,
    this.questionId,
  });

  /// Composite topic ID used as Firestore document key
  String get topicId => '${examType}_${subject}_$topic';

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'examType': examType,
      'subject': subject,
      'topic': topic,
      'difficulty': difficulty,
      'isCorrect': isCorrect,
      'timestamp': Timestamp.fromDate(timestamp),
      'topicId': topicId,
      if (questionId != null) 'questionId': questionId,
    };
  }

  factory Attempt.fromMap(String id, Map<String, dynamic> map) {
    return Attempt(
      id: id,
      userId: map['userId'] as String,
      examType: map['examType'] as String,
      subject: map['subject'] as String,
      topic: map['topic'] as String,
      difficulty: map['difficulty'] as String,
      isCorrect: map['isCorrect'] as bool,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      questionId: map['questionId'] as String?,
    );
  }

  factory Attempt.fromSnapshot(DocumentSnapshot doc) {
    return Attempt.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }
}