import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Response from a single voice turn (STT → AI chat → TTS).
class VoiceTurnResult {
  final String transcript;
  final String replyText;

  /// Base64-encoded MP3 audio bytes.
  final String audioBase64;

  const VoiceTurnResult({
    required this.transcript,
    required this.replyText,
    required this.audioBase64,
  });
}

/// One turn of conversation history.
class ChatTurn {
  final String user;
  final String assistant;

  const ChatTurn({required this.user, required this.assistant});

  Map<String, dynamic> toJson() => {'user': user, 'assistant': assistant};
}

/// Service that communicates with the Voice Tutor backend.
class VoiceTutorService {
  /// Base URL from .env
  /// Android emulator default: http://10.0.2.2:3000
  /// Real device: set to your computer's local IP, e.g. http://192.168.1.5:3000
  static String get _baseUrl {
    final url = dotenv.env['VOICE_TUTOR_BACKEND_URL'];
    if (url == null || url.isEmpty) {
      debugPrint(
          '[VoiceTutorService] WARNING: VOICE_TUTOR_BACKEND_URL not set in .env — defaulting to emulator address');
      return 'http://10.0.2.2:3000';
    }
    return url;
  }

  static const Duration _timeout = Duration(seconds: 60);
  static const int _maxRetries = 2;

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<VoiceTurnResult> sendVoiceTurn({
    required File audioFile,
    required List<ChatTurn> history,
    Map<String, String>? examContext,
  }) async {
    Exception? lastError;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        return await _doVoiceTurn(
          audioFile: audioFile,
          history: history,
          examContext: examContext ?? {},
        );
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());

        final msg = e.toString();
        // Don't retry on non-transient errors
        if (msg.contains('Permission') || msg.contains('400')) break;

        if (attempt < _maxRetries) {
          debugPrint(
              '[VoiceTutorService] Attempt $attempt failed: $msg — retrying in ${2 * attempt}s…');
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
      }
    }

    throw lastError!;
  }

  // ── Private ────────────────────────────────────────────────────────────────

  Future<VoiceTurnResult> _doVoiceTurn({
    required File audioFile,
    required List<ChatTurn> history,
    required Map<String, String> examContext,
  }) async {
    final baseUrl = _baseUrl;
    debugPrint('[VoiceTutorService] Sending to $baseUrl/voice-turn');

    final uri = Uri.parse('$baseUrl/voice-turn');

    final request = http.MultipartRequest('POST', uri)
      ..fields['mimeType'] = 'audio/m4a'
      ..fields['history'] =
          jsonEncode(history.map((t) => t.toJson()).toList())
      ..fields['examContext'] = jsonEncode(examContext)
      ..files
          .add(await http.MultipartFile.fromPath('audio', audioFile.path));

    final http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await request.send().timeout(_timeout);
    } on SocketException catch (e) {
      throw Exception(
          'Network error connecting to $baseUrl — is the backend running? ($e)');
    } on http.ClientException catch (e) {
      throw Exception('HTTP client error: $e');
    }

    final response = await http.Response.fromStream(streamedResponse);
    _assertOk(response, '/voice-turn');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return VoiceTurnResult(
      transcript: data['transcript'] as String? ?? '',
      replyText: data['replyText'] as String? ?? '',
      audioBase64: data['audioBase64'] as String? ?? '',
    );
  }

  void _assertOk(http.Response response, String endpoint) {
    if (response.statusCode == 200) return;

    String message;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      message = body['error']?.toString() ?? response.body;
    } catch (_) {
      message = response.body.length > 300
          ? response.body.substring(0, 300)
          : response.body;
    }

    throw Exception(
      'Backend $endpoint error ${response.statusCode}: $message',
    );
  }
}