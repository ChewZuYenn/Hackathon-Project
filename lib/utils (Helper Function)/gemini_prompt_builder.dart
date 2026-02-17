String buildGeminiPrompt({
  required String examType,
  required String subject,
  required String topic,
  required String difficulty,
}) {
  final difficultyGuide = _difficultyGuide(difficulty);

  return '''
You are an expert $examType exam question generator for $subject.

Generate ONE $difficulty-level multiple-choice question about the topic: "$topic".

SPECIAL CHARACTER RULES — use these Unicode characters freely in questions, options, and explanations:
- Superscripts: x², x³, xⁿ  (use actual Unicode: ², ³, ⁿ)
- Square root: √x, √(a+b), ∛x
- Fractions: use "/" notation e.g. 3/4, or Unicode fractions ½ ¼ ¾
- Pi: π
- Infinity: ∞
- Summation: Σ
- Integral signs: ∫ ∬ ∮
- Partial derivative: ∂
- Delta/nabla: Δ δ ∇
- Greek letters: α β γ θ λ μ ω φ ρ σ
- Inequalities: ≤ ≥ ≠ ≈ ≡
- Arrows: → ← ↔ ⇒ ⇔
- Chemical: subscripts using regular digits after element e.g. H2O, CO2
- Logical: ∧ ∨ ¬ ∀ ∃

$difficultyGuide

STRICT OUTPUT FORMAT — return ONLY the JSON object below, no extra text, no markdown:
{
  "id": "q_<unique_6_char_alphanumeric>",
  "question": "<the full question text, may include special characters>",
  "options": [
    "<option A full text>",
    "<option B full text>",
    "<option C full text>",
    "<option D full text>"
  ],
  "correctAnswer": "<must be the EXACT full text of the correct option, copied verbatim from the options array>",
  "explanation": "<detailed step-by-step explanation, at least 2 sentences, may include special characters>"
}

RULES:
1. "correctAnswer" must be the EXACT full text of one option — not A/B/C/D labels
2. All 4 options must be plausible but only one correct
3. Question must be appropriate for $examType $difficulty level
4. Never repeat the same question structure twice — vary the question style
5. Return ONLY the JSON — no preamble, no explanation outside JSON
''';
}

String _difficultyGuide(String difficulty) {
  switch (difficulty.toLowerCase()) {
    case 'beginner':
      return '''
BEGINNER LEVEL REQUIREMENTS:
- Test direct recall of definitions and basic facts
- Use simple, clear language — no complex sub-clauses
- One clearly correct answer — distractors should be obviously wrong on reflection
- Example question types: "What is X?", "Which of the following is Y?", "Calculate simple Z"
- Avoid multi-step problems
''';
    case 'intermediate':
      return '''
INTERMEDIATE LEVEL REQUIREMENTS:
- Require understanding and application, not just recall
- Include moderate calculations or reasoning (2–3 steps)
- Distractors should be common misconceptions or plausible mistakes
- Example question types: "Which best explains X?", "Calculate Y given Z", "Apply concept X to situation Y"
- May use special characters for math/science notation
''';
    case 'advance':
    case 'advanced':
      return '''
ADVANCED LEVEL REQUIREMENTS:
- Require deep analysis, synthesis, or multi-step problem solving (3+ steps)
- Use complex notation freely: integrals, summations, Greek letters, derivatives
- Distractors must be highly plausible — require careful reasoning to eliminate
- Include edge cases, proofs, or real-world complex applications
- Example question types: "Evaluate ∫₀¹ f(x)dx", "Prove that…", "Given complex scenario, determine…"
- Questions may involve multiple concepts from across the topic
''';
    default:
      return 'Generate a moderately challenging question appropriate for $difficulty level.';
  }
}