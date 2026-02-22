import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model (Data Model)/attempt.dart';
import '../model (Data Model)/topic_stats.dart';
import 'firebase_service.dart';

/// Tracks user progress and drives adaptive topic selection.
class ProgressTrackingService {
  final FirebaseService _firebaseService = FirebaseService();

  FirebaseFirestore get _firestore => _firebaseService.firestore;
  String? get _userId => _firebaseService.currentUserId;


  /// Record one question attempt and update topic stats atomically.
  /// Returns the new Firestore document ID.
  Future<String> recordAttempt({
    required String examType,
    required String subject,
    required String topic,
    required String difficulty,
    required bool isCorrect,
    String? questionId,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    final attempt = Attempt(
      id: '',
      userId: _userId!,
      examType: examType,
      subject: subject,
      topic: topic,
      difficulty: difficulty,
      isCorrect: isCorrect,
      timestamp: DateTime.now(),
      questionId: questionId,
    );

    // Write the attempt document
    final docRef = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('attempts')
        .add(attempt.toMap());

    // Update aggregated topic stats
    await updateTopicStats(
      examType: examType,
      subject: subject,
      topic: topic,
      isCorrect: isCorrect,
    );

    return docRef.id;
  }

  /// Atomically update (or create) the topicStats document for one topic.
  Future<void> updateTopicStats({
    required String examType,
    required String subject,
    required String topic,
    required bool isCorrect,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    final topicId = '${examType}_${subject}_$topic';
    final docRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('topicStats')
        .doc(topicId);

    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);

      final TopicStats updated;
      if (snapshot.exists) {
        updated = TopicStats.fromSnapshot(snapshot).updateWithAttempt(isCorrect);
      } else {
        updated = TopicStats.initial(
          topicId: topicId,
          userId: _userId!,
          examType: examType,
          subject: subject,
          topic: topic,
        ).updateWithAttempt(isCorrect);
      }

      tx.set(docRef, updated.toMap());
    });
  }


  /// Fetch stats for a single topic. Returns null if never attempted.
  Future<TopicStats?> getTopicStats(String topicId) async {
    if (_userId == null) return null;

    final doc = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('topicStats')
        .doc(topicId)
        .get();

    if (!doc.exists) return null;
    return TopicStats.fromSnapshot(doc);
  }

  /// Fetch all topic stats for the current user.
  Future<List<TopicStats>> getAllTopicStats() async {
    if (_userId == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('topicStats')
        .get();

    return snapshot.docs.map(TopicStats.fromSnapshot).toList();
  }

  /// Return the [limit] weakest topics (lowest mastery score).
  Future<List<TopicStats>> getWeakTopics({int limit = 5}) async {
    if (_userId == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('topicStats')
        .orderBy('masteryScore', descending: false)
        .limit(limit)
        .get();

    return snapshot.docs.map(TopicStats.fromSnapshot).toList();
  }

  /// Fetch stats filtered by exam type + subject.
  Future<List<TopicStats>> getStatsForSubject({
    required String examType,
    required String subject,
  }) async {
    if (_userId == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('topicStats')
        .where('examType', isEqualTo: examType)
        .where('subject', isEqualTo: subject)
        .get();

    return snapshot.docs.map(TopicStats.fromSnapshot).toList();
  }

  /// Recent attempt history (newest first).
  Future<List<Attempt>> getRecentAttempts({int limit = 20}) async {
    if (_userId == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('attempts')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map(Attempt.fromSnapshot).toList();
  }


  /// Compute a weight for every topic in [availableTopics].
  /// New/unseen topics receive a default weight of 0.7 to encourage exploration.
  Future<Map<String, double>> computeTopicWeights({
    required String examType,
    required String subject,
    required List<String> availableTopics,
  }) async {
    final Map<String, double> weights = {};

    for (final topic in availableTopics) {
      final topicId = '${examType}_${subject}_$topic';
      final stats = await getTopicStats(topicId);
      weights[topic] = stats?.weight ?? 0.7;
    }

    return weights;
  }

  /// Weighted-random selection across [availableTopics].
  /// Weak topics are chosen more often; no topic is fully excluded.
  Future<String> selectNextTopicWeighted({
    required String examType,
    required String subject,
    required List<String> availableTopics,
  }) async {
    if (availableTopics.isEmpty) throw Exception('No available topics');

    final weights = await computeTopicWeights(
      examType: examType,
      subject: subject,
      availableTopics: availableTopics,
    );

    final totalWeight = weights.values.fold(0.0, (a, b) => a + b);
    double roll = Random().nextDouble() * totalWeight;

    for (final topic in availableTopics) {
      roll -= weights[topic] ?? 0.7;
      if (roll <= 0) return topic;
    }

    // Fallback — should never happen
    return availableTopics.last;
  }
}