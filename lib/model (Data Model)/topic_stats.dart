import 'package:cloud_firestore/cloud_firestore.dart';

/// Statistics for a specific topic — stored at:
/// users/{uid}/topicStats/{examType_subject_topic}
class TopicStats {
  final String topicId;
  final String userId;
  final int correctCount;
  final int wrongCount;
  final int totalAttempts;
  final int recentWrongStreak;
  final double masteryScore;
  final DateTime lastAttemptAt;
  final String examType;
  final String subject;
  final String topic;

  const TopicStats({
    required this.topicId,
    required this.userId,
    required this.correctCount,
    required this.wrongCount,
    required this.totalAttempts,
    required this.recentWrongStreak,
    required this.masteryScore,
    required this.lastAttemptAt,
    required this.examType,
    required this.subject,
    required this.topic,
  });

  /// Fraction of wrong answers (0.0–1.0). Defaults to 0.5 for unseen topics.
  double get wrongRate {
    if (totalAttempts == 0) return 0.5;
    return wrongCount / totalAttempts;
  }

  /// Adaptive weight: minimum 0.2, maximum ~1.0+
  /// weight = 0.2 + (wrongRate * 0.8) + (recentWrongStreak * 0.1)
  double get weight {
    final streakBoost = recentWrongStreak * 0.1;
    return 0.2 + (wrongRate * 0.8) + streakBoost;
  }

  Map<String, dynamic> toMap() {
    return {
      'topicId': topicId,
      'userId': userId,
      'correctCount': correctCount,
      'wrongCount': wrongCount,
      'totalAttempts': totalAttempts,
      'recentWrongStreak': recentWrongStreak,
      'masteryScore': masteryScore,
      'lastAttemptAt': Timestamp.fromDate(lastAttemptAt),
      'examType': examType,
      'subject': subject,
      'topic': topic,
    };
  }

  factory TopicStats.fromMap(String docId, Map<String, dynamic> map) {
    return TopicStats(
      topicId: map['topicId'] as String,
      userId: map['userId'] as String,
      correctCount: (map['correctCount'] as num).toInt(),
      wrongCount: (map['wrongCount'] as num).toInt(),
      totalAttempts: (map['totalAttempts'] as num).toInt(),
      recentWrongStreak: (map['recentWrongStreak'] as num).toInt(),
      masteryScore: (map['masteryScore'] as num).toDouble(),
      lastAttemptAt: (map['lastAttemptAt'] as Timestamp).toDate(),
      examType: map['examType'] as String,
      subject: map['subject'] as String,
      topic: map['topic'] as String,
    );
  }

  factory TopicStats.fromSnapshot(DocumentSnapshot doc) {
    return TopicStats.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  /// Create a blank record for a brand-new topic
  factory TopicStats.initial({
    required String topicId,
    required String userId,
    required String examType,
    required String subject,
    required String topic,
  }) {
    return TopicStats(
      topicId: topicId,
      userId: userId,
      correctCount: 0,
      wrongCount: 0,
      totalAttempts: 0,
      recentWrongStreak: 0,
      masteryScore: 0.0,
      lastAttemptAt: DateTime.now(),
      examType: examType,
      subject: subject,
      topic: topic,
    );
  }

  /// Return a new instance with updated counts after one attempt
  TopicStats updateWithAttempt(bool isCorrect) {
    final newCorrect = isCorrect ? correctCount + 1 : correctCount;
    final newWrong = isCorrect ? wrongCount : wrongCount + 1;
    final newTotal = totalAttempts + 1;
    final newStreak = isCorrect ? 0 : recentWrongStreak + 1;
    // masteryScore = correctCount / (correctCount + wrongCount + 1)
    final newMastery = newCorrect / (newCorrect + newWrong + 1);

    return TopicStats(
      topicId: topicId,
      userId: userId,
      correctCount: newCorrect,
      wrongCount: newWrong,
      totalAttempts: newTotal,
      recentWrongStreak: newStreak,
      masteryScore: newMastery,
      lastAttemptAt: DateTime.now(),
      examType: examType,
      subject: subject,
      topic: topic,
    );
  }
}