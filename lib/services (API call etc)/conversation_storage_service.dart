import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single chat turn in conversation history.
class ConversationTurn {
  final String user;
  final String assistant;
  final DateTime timestamp;

  const ConversationTurn({
    required this.user,
    required this.assistant,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'user': user,
        'assistant': assistant,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ConversationTurn.fromJson(Map<String, dynamic> json) =>
      ConversationTurn(
        user: json['user'] as String? ?? '',
        assistant: json['assistant'] as String? ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Persists conversation history to local device storage using SharedPreferences.
class ConversationStorageService {
  static const String _keyPrefix = 'voice_tutor_history_';
  static const int _maxStoredTurns = 50;

  /// Returns a storage key scoped to a specific topic/session.
  static String _key(String sessionId) => '$_keyPrefix$sessionId';

  /// Load history for a session from local storage.
  static Future<List<ConversationTurn>> load(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(sessionId));
      if (raw == null || raw.isEmpty) return [];

      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ConversationTurn.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ConversationStorage] Load error: $e');
      return [];
    }
  }

  /// Save history for a session to local storage.
  static Future<void> save(
      String sessionId, List<ConversationTurn> turns) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Only keep the last N turns to avoid unbounded storage growth
      final toSave = turns.length > _maxStoredTurns
          ? turns.sublist(turns.length - _maxStoredTurns)
          : turns;

      final encoded = jsonEncode(toSave.map((t) => t.toJson()).toList());
      await prefs.setString(_key(sessionId), encoded);
      debugPrint('[ConversationStorage] Saved ${toSave.length} turns for "$sessionId"');
    } catch (e) {
      debugPrint('[ConversationStorage] Save error: $e');
    }
  }

  /// Clear history for a session.
  static Future<void> clear(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(sessionId));
      debugPrint('[ConversationStorage] Cleared history for "$sessionId"');
    } catch (e) {
      debugPrint('[ConversationStorage] Clear error: $e');
    }
  }
}
