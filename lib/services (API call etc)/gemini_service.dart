import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../model (Data Model)/question.dart';
import '../utils (Helper Function)/gemini_prompt_builder.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiQuestionService {
  static final String geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  static const String _baseUrl =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

  Future<Question> generateQuestion({
    required String examType,
    required String subject,
    required String topic,
    required String difficulty,
  }) async {
    if (geminiApiKey.isEmpty || geminiApiKey == 'PASTE_YOUR_KEY_HERE') {
      throw Exception('Please add your Gemini API key to the .env file');
    }

    Exception? lastError;

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        return await _fetchQuestion(
          examType: examType,
          subject: subject,
          topic: topic,
          difficulty: difficulty,
        );
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());

        if (e.toString().contains('Rate limit') ||
            e.toString().contains('429')) {
          debugPrint('[GeminiService] Rate limited — stopping retries');
          break;
        }

        if (attempt < 3) {
          final waitSeconds = 3 * attempt;
          debugPrint(
              '[GeminiService] Attempt $attempt failed: $e — retrying in ${waitSeconds}s…');
          await Future.delayed(Duration(seconds: waitSeconds));
        }
      }
    }

    throw lastError!;
  }

  Future<Question> _fetchQuestion({
    required String examType,
    required String subject,
    required String topic,
    required String difficulty,
  }) async {
    final prompt = buildGeminiPrompt(
      examType: examType,
      subject: subject,
      topic: topic,
      difficulty: difficulty,
    );

    final uri = Uri.parse('$_baseUrl?key=$geminiApiKey');

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.75,
              'topK': 40,
              'topP': 0.95,
              'maxOutputTokens': 2048,
             
            },
            'safetySettings': [
              {
                'category': 'HARM_CATEGORY_HARASSMENT',
                'threshold': 'BLOCK_NONE'
              },
              {
                'category': 'HARM_CATEGORY_HATE_SPEECH',
                'threshold': 'BLOCK_NONE'
              },
              {
                'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
                'threshold': 'BLOCK_NONE'
              },
              {
                'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
                'threshold': 'BLOCK_NONE'
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 429) {
      throw Exception(
          'Rate limit reached. Please wait 30 seconds and try again.');
    }
    if (response.statusCode == 403) {
      throw Exception(
          'API key invalid or Gemini API not enabled on your Google Cloud project.');
    }
    if (response.statusCode != 200) {
      final snippet = response.body.length > 400
          ? response.body.substring(0, 400)
          : response.body;
      throw Exception('Gemini API error ${response.statusCode}: $snippet');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final promptFeedback = data['promptFeedback'] as Map<String, dynamic>?;
    if (promptFeedback?['blockReason'] != null) {
      throw Exception('Request blocked: ${promptFeedback!['blockReason']}');
    }

    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No response from Gemini API. Please try again.');
    }

    final finishReason =
        candidates[0]['finishReason'] as String? ?? '';
    if (finishReason == 'SAFETY') {
      throw Exception(
          'Response blocked by safety filter. Please try again.');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    final rawText = (parts != null && parts.isNotEmpty)
        ? (parts[0]['text'] as String? ?? '')
        : '';

    if (rawText.trim().isEmpty) {
      throw Exception('Empty response from Gemini. Please try again.');
    }

    debugPrint(
        '[GeminiService] Raw (first 300): ${rawText.substring(0, rawText.length.clamp(0, 300))}');

    final questionData = _parseQuestionJson(rawText);
    _validateQuestionData(questionData);
    return Question.fromJson(questionData);
  }

  // JSON Parsing

  Map<String, dynamic> _parseQuestionJson(String text) {
    String cleaned = text.trim();

    // Strip markdown code fences
    for (final fence in ['```json', '```JSON', '```dart', '```']) {
      if (cleaned.startsWith(fence)) {
        cleaned = cleaned.substring(fence.length).trim();
        break;
      }
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3).trim();
    }

    // Attempt 1: direct parse
    try {
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {}

    // Attempt 2: extract first {...} block
    try {
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
      if (match != null) {
        return jsonDecode(match.group(0)!) as Map<String, dynamic>;
      }
    } catch (_) {}

    // Attempt 3: manual field extraction
    return _extractFieldsManually(cleaned);
  }

  Map<String, dynamic> _extractFieldsManually(String text) {
    String extractString(String key) {
      final pattern =
          RegExp('"$key"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)"');
      return pattern.firstMatch(text)?.group(1)?.replaceAll('\\"', '"') ??
          '';
    }

    List<String> extractArray(String key) {
      final pattern =
          RegExp('"$key"\\s*:\\s*\\[(.*?)\\]', dotAll: true);
      final match = pattern.firstMatch(text);
      if (match == null) return [];
      return RegExp('"((?:[^"\\\\]|\\\\.)*)"')
          .allMatches(match.group(1)!)
          .map((m) => m.group(1)!.replaceAll('\\"', '"'))
          .toList();
    }

    final question = extractString('question');
    final options = extractArray('options');
    final correctAnswer = extractString('correctAnswer');
    final explanation = extractString('explanation');

    if (question.isEmpty || options.length != 4) {
      throw Exception(
          'Manual extraction failed — options found: ${options.length}');
    }

    return {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
    };
  }

  //Validation

  void _validateQuestionData(Map<String, dynamic> data) {
    for (final field in [
      'question',
      'options',
      'correctAnswer',
      'explanation'
    ]) {
      if (!data.containsKey(field) || data[field] == null) {
        throw Exception('Missing required field: $field');
      }
    }

    // Ensure id exists
    if (!data.containsKey('id') || data['id'] == null) {
      data['id'] = DateTime.now().millisecondsSinceEpoch.toString();
    }

    final options = data['options'] as List;
    if (options.length != 4) {
      throw Exception('Expected 4 options, got ${options.length}');
    }

    final correctAnswer = data['correctAnswer'].toString().trim();
    final optionStrings =
        options.map((o) => o.toString().trim()).toList();

    if (!optionStrings.contains(correctAnswer)) {
      
      final labelMap = {'A': 0, 'B': 1, 'C': 2, 'D': 3};
      final idx = labelMap[correctAnswer.toUpperCase()];
      if (idx != null && idx < optionStrings.length) {
        debugPrint(
            '[GeminiService] Auto-repairing correctAnswer label "$correctAnswer" → "${optionStrings[idx]}"');
        data['correctAnswer'] = optionStrings[idx];
      } else {
        throw Exception(
            'correctAnswer "$correctAnswer" not found in options: $optionStrings');
      }
    }

    debugPrint('[GeminiService] ✅ Question validated successfully');
  }
}