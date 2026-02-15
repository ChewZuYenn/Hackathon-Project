import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model (Data Model)/question.dart';
import '../utils (Helper Function)/gemini_prompt_builder.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiQuestionService {
  static final String geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  static const String _baseUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent";

  Future<Question> generateQuestion({
    required String examType,
    required String subject,
    required String topic,
    required String difficulty,
  }) async {
    if (geminiApiKey == 'PASTE_YOUR_KEY_HERE' || geminiApiKey.isEmpty) {
      throw Exception(
        "Please add your Gemini API key to the .env file",
      );
    }

    try {
      final prompt = buildGeminiPrompt(
        examType: examType,
        subject: subject,
        topic: topic,
        difficulty: difficulty,
      );

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 1024,
          }
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'API request failed with status: ${response.statusCode}\nBody: ${response.body}');
      }

      final data = jsonDecode(response.body);
      
      if (data['candidates'] == null || data['candidates'].isEmpty) {
        throw Exception('No candidates in API response');
      }

      final textContent = data['candidates'][0]['parts'][0]['text'] as String;
      
      // Clean and parse the JSON with robust error handling
      final questionData = _parseQuestionJson(textContent);
      
      // Validate the parsed data before creating Question object
      _validateQuestionData(questionData);
      
      return Question.fromJson(questionData);
    } catch (e) {
      print('❌ Error generating question: $e');
      rethrow;
    }
  }

  /// Robust JSON parser that handles malformed responses from Gemini
  Map<String, dynamic> _parseQuestionJson(String text) {
    try {
      // Remove markdown code blocks if present
      String cleaned = text.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.replaceFirst('```json', '').trim();
      }
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceFirst('```', '').trim();
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3).trim();
      }

      // Try direct parsing first
      try {
        return jsonDecode(cleaned) as Map<String, dynamic>;
      } catch (e) {
        print('⚠️ Initial JSON parse failed, attempting repair...');
        
        // Attempt to repair common JSON issues
        String repaired = _repairJson(cleaned);
        
        try {
          return jsonDecode(repaired) as Map<String, dynamic>;
        } catch (e2) {
          print('❌ JSON repair failed: $e2');
          print('📄 Original text: $text');
          print('🔧 Repaired text: $repaired');
          
          // Last resort: try to extract JSON using regex
          return _extractJsonWithRegex(text);
        }
      }
    } catch (e) {
      throw Exception('Failed to parse question JSON: $e\nOriginal text: $text');
    }
  }

  /// Repairs common JSON formatting issues
  String _repairJson(String json) {
    String repaired = json;
    
    // Fix unescaped quotes in strings (common with math problems)
    // This regex finds text within quotes and escapes internal quotes
    repaired = _escapeQuotesInStrings(repaired);
    
    // Fix unescaped newlines
    repaired = repaired.replaceAll('\n', '\\n');
    
    // Fix unescaped backslashes (except for already escaped ones)
    repaired = repaired.replaceAllMapped(
      RegExp(r'\\(?!["\\/bfnrtu])'),
      (match) => '\\\\',
    );
    
    // Remove any trailing commas before closing braces/brackets
    repaired = repaired.replaceAll(RegExp(r',(\s*[}\]])'), r'$1');
    
    return repaired;
  }

  /// Escapes quotes within JSON string values
  String _escapeQuotesInStrings(String json) {
    StringBuffer result = StringBuffer();
    bool inString = false;
    bool escaped = false;
    
    for (int i = 0; i < json.length; i++) {
      String char = json[i];
      
      if (escaped) {
        result.write(char);
        escaped = false;
        continue;
      }
      
      if (char == '\\') {
        result.write(char);
        escaped = true;
        continue;
      }
      
      if (char == '"') {
        // Check if this is a key or value quote
        if (!inString) {
          // Starting a string
          result.write(char);
          inString = true;
        } else {
          // Could be ending string or internal quote
          // Check if followed by : or , or } or ] (end of string)
          int nextNonWhitespace = i + 1;
          while (nextNonWhitespace < json.length && 
                 json[nextNonWhitespace].trim().isEmpty) {
            nextNonWhitespace++;
          }
          
          if (nextNonWhitespace < json.length) {
            String nextChar = json[nextNonWhitespace];
            if (nextChar == ':' || nextChar == ',' || 
                nextChar == '}' || nextChar == ']') {
              // This is the closing quote
              result.write(char);
              inString = false;
            } else {
              // This is an internal quote - escape it
              result.write('\\"');
            }
          } else {
            // End of string at end of JSON
            result.write(char);
            inString = false;
          }
        }
      } else {
        result.write(char);
      }
    }
    
    return result.toString();
  }

  /// Last resort: extract JSON using regex pattern matching
  Map<String, dynamic> _extractJsonWithRegex(String text) {
    try {
      // Try to find JSON-like structure in the text
      final jsonPattern = RegExp(r'\{[\s\S]*\}');
      final match = jsonPattern.firstMatch(text);
      
      if (match != null) {
        final extracted = match.group(0)!;
        final repaired = _repairJson(extracted);
        return jsonDecode(repaired) as Map<String, dynamic>;
      }
      
      throw Exception('Could not extract JSON from text');
    } catch (e) {
      // If all else fails, throw with helpful error
      throw Exception(
        'Unable to parse question from Gemini response. '
        'The AI returned malformed JSON. Please try again.'
      );
    }
  }

  /// Validates that the parsed JSON contains all required fields
  void _validateQuestionData(Map<String, dynamic> data) {
    final requiredFields = ['id', 'question', 'options', 'correctAnswer', 'explanation'];
    
    for (final field in requiredFields) {
      if (!data.containsKey(field) || data[field] == null) {
        throw Exception('Missing required field: $field in question data: $data');
      }
    }
    
    // Validate options is a list
    if (data['options'] is! List) {
      throw Exception('options must be a list, got: ${data['options'].runtimeType}');
    }
    
    final options = data['options'] as List;
    if (options.isEmpty) {
      throw Exception('options list cannot be empty');
    }
    
    // Validate correctAnswer exists
    if (data['correctAnswer'].toString().isEmpty) {
      throw Exception('correctAnswer cannot be empty');
    }
    
    print('✅ Question data validation passed');
  }
}