import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model (Data Model)/question.dart';
import '../utils (Helper Function)/gemini_prompt_builder.dart';

class GeminiQuestionService {
  // PASTE YOUR GEMINI API KEY HERE
  static const String geminiApiKey = "PASTE_YOUR_KEY_HERE";

  static const String _baseUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";
  Future<Question> generateQuestion({
    required String examType,
    required String subject,
    required String topic,
    required String difficulty,
  }) async {
    if (geminiApiKey == "PASTE_YOUR_KEY") {
      throw Exception(
          "Please add your Gemini API key in lib/services (API call etc)/gemini_service.dart");
    }

    try {
      final prompt = buildGeminiPrompt(
        examType: examType,
        subject: subject,
        topic: topic,
        difficulty: difficulty,
      );

      final response = await http
          .post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': geminiApiKey,
        },
            body: jsonEncode({
              "contents": [
                {
                  "parts": [
                    {"text": prompt}
                  ]
                }
              ],
              "generationConfig": {
                "temperature": 0.7,
                "maxOutputTokens": 1024,
              }
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Extract text from Gemini response
        final generatedText = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
        
        if (generatedText == null || generatedText.isEmpty) {
          throw Exception("Empty response from Gemini API");
        }

        // Clean and extract JSON
        String jsonText = _extractJson(generatedText);
        
        // Parse JSON to Question
        final questionJson = jsonDecode(jsonText) as Map<String, dynamic>;
        return Question.fromJson(questionJson);
        
      } else if (response.statusCode == 429) {
        throw Exception("Rate limit exceeded. Please wait a moment and try again.");
      } else if (response.statusCode == 400) {
        throw Exception("Invalid request. Please check your API key.");
      } else {
        throw Exception("Failed to generate question: ${response.statusCode}");
      }
    } catch (e) {
      if (e.toString().contains("SocketException")) {
        throw Exception("No internet connection. Please check your network.");
      } else if (e.toString().contains("TimeoutException")) {
        throw Exception("Request timed out. Please try again.");
      }
      rethrow;
    }
  }

  // Helper to extract JSON from text that might have markdown or extra content
  String _extractJson(String text) {
    // Remove markdown code blocks if present
    text = text.replaceAll('```json', '').replaceAll('```', '').trim();
    
    // Find JSON object boundaries
    final startIndex = text.indexOf('{');
    final endIndex = text.lastIndexOf('}');
    
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      return text.substring(startIndex, endIndex + 1);
    }
    
    return text;
  }
}