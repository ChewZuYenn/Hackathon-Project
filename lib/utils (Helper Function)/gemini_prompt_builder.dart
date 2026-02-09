String buildGeminiPrompt({
  required String examType,
  required String subject,
  required String topic,
  required String difficulty,
}) {
  return '''
You are an expert exam question generator for ${examType} exams.

Generate ONE multiple-choice question with the following specifications:
- Exam Type: ${examType}
- Subject: ${subject}
- Topic: ${topic}
- Difficulty: ${difficulty}

Requirements:
1. Create a realistic, exam-style question appropriate for ${examType} ${subject}
2. Provide exactly 4 options labeled A, B, C, D
3. One correct answer
4. Brief explanation (2-3 sentences max)
5. Question should test understanding, not just memorization

CRITICAL: Respond ONLY with valid JSON in this EXACT format (no markdown, no backticks, no extra text):

{
  "id": "q_${DateTime.now().millisecondsSinceEpoch}",
  "question": "Your question text here",
  "options": ["A) First option", "B) Second option", "C) Third option", "D) Fourth option"],
  "answer": "A",
  "explanation": "Brief explanation of why this is correct",
  "topic": "${topic}",
  "difficulty": "${difficulty}"
}

DO NOT include any text before or after the JSON. Output ONLY the JSON object.
''';
}