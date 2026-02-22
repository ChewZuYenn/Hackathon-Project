import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Calls Google Gemini directly from Flutter for the AI tutor chat turn.
/// Separate from [GeminiQuestionService] so the two can use different
/// API keys / quotas. Load GEMINI_TUTOR_API_KEY in your Flutter .env file.
class TutorGeminiService {
  // Constants 

  static const String _model = 'gemini-2.0-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';
  static const Duration _timeout = Duration(seconds: 30);
  static const int _maxRetries = 2;

  //Key 

  static String get _apiKey {
    // Fall back to the question generator key if tutor key isn't set
    final key = dotenv.env['GEMINI_TUTOR_API_KEY'] ??
        dotenv.env['GEMINI_API_KEY'] ??
        '';
    if (key.isEmpty) {
      throw Exception(
          'GEMINI_TUTOR_API_KEY (or GEMINI_API_KEY) not found in .env');
    }
    return key;
  }

  //Public API

  /// Sends one tutor turn to Gemini and returns the assistant reply text.
  /// [userTranscript]   The final STT text from the student.
  /// [workingSpaceText] Full text currently in the Working Space box.
  /// [questionText]     The question the student is working on.
  /// [history]          Previous turns (user/assistant pairs) for context.
  /// [examContext]      Optional map with examType, subject, topic, difficulty.
  Future<String> askTutor({
    required String userTranscript,
    required String workingSpaceText,
    String questionText = '',
    List<Map<String, String>> history = const [],
    Map<String, String> examContext = const {},
  }) async {
    Exception? lastError;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        return await _doRequest(
          userTranscript: userTranscript,
          workingSpaceText: workingSpaceText,
          questionText: questionText,
          history: history,
          examContext: examContext,
        );
      } on SocketException catch (e) {
        lastError = Exception('Network error reaching Gemini: $e');
      } on http.ClientException catch (e) {
        lastError = Exception('HTTP error: $e');
      } on Exception catch (e) {
        lastError = e;
        // Don't retry on client errors (quota, bad key, etc.)
        final msg = e.toString();
        if (msg.contains('429') || msg.contains('403') || msg.contains('400')) break;
      }

      if (attempt < _maxRetries) {
        debugPrint(
            '[TutorGemini] Attempt $attempt failed — retrying in ${2 * attempt}s…');
        await Future.delayed(Duration(seconds: 2 * attempt));
      }
    }

    throw lastError!;
  }

  ///Private

  Future<String> _doRequest({
    required String userTranscript,
    required String workingSpaceText,
    required String questionText,
    required List<Map<String, String>> history,
    required Map<String, String> examContext,
  }) async {
    final uri = Uri.parse('$_baseUrl?key=${_apiKey}');

    // Build Gemini multiturn content array
    final contents = <Map<String, dynamic>>[];

    // System turn: set the tutor persona 
    final systemPrompt = buildTutorPrompt(
      userTranscript: userTranscript,
      workingSpaceText: workingSpaceText,
      questionText: questionText,
      examContext: examContext,
      historyLength: history.length,
    );

    // Gemini REST doesn't support a "system" role for all models, so we use
    // a user ,model handshake to establish the persona robustly.
    contents.add({
      'role': 'user',
      'parts': [{'text': systemPrompt}],
    });
    contents.add({
      'role': 'model',
      'parts': [{'text': "Understood! I'm ready to help as your AI tutor."}],
    });

    //Previous conversation turns 
    for (final turn in history) {
      if (turn['user']?.isNotEmpty == true) {
        contents.add({'role': 'user', 'parts': [{'text': turn['user']!}]});
      }
      if (turn['assistant']?.isNotEmpty == true) {
        contents.add({'role': 'model', 'parts': [{'text': turn['assistant']!}]});
      }
    }

    //Current student message
    contents.add({
      'role': 'user',
      'parts': [{'text': userTranscript}],
    });

    final body = jsonEncode({
      'contents': contents,
      'generationConfig': {
        'temperature': 0.65,
        'maxOutputTokens': 256, // Keep responses concise for voice
        'topP': 0.95,
      },
      'safetySettings': [
        {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_NONE'},
      ],
    });

    debugPrint('[TutorGemini] POST to $_baseUrl (model: $_model)');
    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(_timeout);

    //Error handling
    if (response.statusCode == 429) {
      throw Exception('Tutor API rate limit — wait a moment and try again.');
    }
    if (response.statusCode == 403) {
      throw Exception('GEMINI_TUTOR_API_KEY is invalid or Gemini API is not enabled.');
    }
    if (response.statusCode != 200) {
      final snippet = response.body.length > 300
          ? response.body.substring(0, 300)
          : response.body;
      throw Exception('Gemini tutor error ${response.statusCode}: $snippet');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // Safety block check
    final feedback = data['promptFeedback'] as Map<String, dynamic>?;
    if (feedback?['blockReason'] != null) {
      throw Exception('Tutor response blocked: ${feedback!['blockReason']}');
    }

    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Empty response from Gemini tutor. Please try again.');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    final text = (parts != null && parts.isNotEmpty)
        ? (parts[0]['text'] as String? ?? '').trim()
        : '';

    if (text.isEmpty) {
      throw Exception('Gemini tutor returned an empty reply. Please try again.');
    }

    debugPrint('[TutorGemini] Reply (${text.length} chars): "${text.substring(0, text.length.clamp(0, 120))}…"');
    return text;
  }
}

//Prompt Builder

/// Builds a structured system-level prompt for the tutor persona.
/// Exported as a top-level function so it can be unit-tested independently.
String buildTutorPrompt({
  required String userTranscript,
  required String workingSpaceText,
  required String questionText,
  Map<String, String> examContext = const {},
  int historyLength = 0,
}) {
  final examType = examContext['examType'] ?? 'their exam';
  final subject = examContext['subject'] ?? 'the subject';
  final topic = examContext['topic'] ?? 'the topic';
  final difficulty = examContext['difficulty'];

  final sb = StringBuffer();
  sb.writeln(
    'You are a friendly, encouraging AI tutor helping a student study for '
    '$examType — $subject, topic: $topic'
    '${difficulty != null ? ", difficulty: $difficulty" : ""}.',
  );
  sb.writeln();

  if (questionText.isNotEmpty) {
    sb.writeln('The student is currently working on this question:');
    sb.writeln('"$questionText"');
    sb.writeln();
  }

  if (workingSpaceText.isNotEmpty) {
    sb.writeln("The student's working space (their notes/calculations) shows:");
    sb.writeln('"$workingSpaceText"');
    sb.writeln();
  } else {
    sb.writeln('The student has not written anything in their working space yet.');
    sb.writeln();
  }

  sb.writeln('INSTRUCTIONS:');
  sb.writeln('1. Acknowledge what the student said.');
  sb.writeln('2. If their working space shows mistakes, gently correct them.');
  sb.writeln('3. Give a clear, SHORT explanation (2-3 sentences maximum).');
  sb.writeln('4. Suggest 1 concrete next step they can take.');
  sb.writeln('5. Be encouraging and warm.');
  sb.writeln('6. NEVER use markdown, bullet symbols, asterisks, or special characters.');
  sb.writeln('7. Write in plain prose only — your response will be spoken aloud.');
  sb.writeln('8. Keep total response under 60 words.');

  return sb.toString();
}
