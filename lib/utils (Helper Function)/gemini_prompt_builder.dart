String buildGeminiPrompt({
  required String examType,
  required String subject,
  required String topic,
  required String difficulty,
}) {
  return '''
You are an expert exam question generator. Generate a ${difficulty.toLowerCase()} difficulty $examType question about $topic in $subject.

CRITICAL JSON FORMATTING RULES:
1. Return ONLY valid JSON - no markdown, no code blocks, no extra text
2. ALL special characters in strings MUST be properly escaped:
   - Use \\" for quotes inside strings
   - Use \\\\ for backslashes
   - Use \\n for newlines
   - Mathematical symbols like ², ³, √, ∫, ∂, π, Σ are allowed and do NOT need escaping
3. Ensure all strings are properly quoted
4. Do not include trailing commas
5. Test that your JSON is valid before returning it

Return your response in this exact JSON format:
{
  "id": "unique_id_here",
  "question": "The question text (properly escaped)",
  "options": ["Option A", "Option B", "Option C", "Option D"],
  "correctAnswer": "The correct option (exactly as it appears in options array)",
  "explanation": "Detailed explanation (properly escaped)"
}

DIFFICULTY REQUIREMENTS:
- Beginner: Simple, straightforward questions that test basic understanding
- Intermediate: More complex questions requiring analysis and application
- Advanced: Challenging questions requiring deep understanding and problem-solving

QUESTION REQUIREMENTS:
- Must be clear, unambiguous, and grammatically correct
- Must have exactly 4 options (A, B, C, D)
- Only ONE option must be correct
- All incorrect options must be plausible but clearly wrong
- Explanation must be detailed and educational

TOPIC: $topic
SUBJECT: $subject
EXAM TYPE: $examType
DIFFICULTY: $difficulty

Generate the question now in valid JSON format:
''';
}