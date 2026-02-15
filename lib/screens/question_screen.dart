import 'package:flutter/material.dart';
import '../model (Data Model)/question.dart';
import '../services (API call etc)/gemini_service.dart';
import '../services (API call etc)/progress_tracking_service.dart';

class QuestionScreen extends StatefulWidget {
  final String country;
  final String examType;
  final String subject;
  final String topic;
  final String difficulty;

  const QuestionScreen({
    super.key,
    required this.country,
    required this.examType,
    required this.subject,
    required this.topic,
    required this.difficulty,
  });

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  final TextEditingController _workingSpaceController = TextEditingController();
  final GeminiQuestionService _geminiService = GeminiQuestionService();
  final ProgressTrackingService _progressService = ProgressTrackingService();

  String? _selectedAnswer;
  bool _isListening = false;
  String _spokenText = '';
  Question? _currentQuestion;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _showExplanation = false;

  @override
  void initState() {
    super.initState();
    _loadNextQuestion();
  }

  @override
  void dispose() {
    _workingSpaceController.dispose();
    super.dispose();
  }

  Future<void> _loadNextQuestion() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showExplanation = false;
      _selectedAnswer = null;
      _workingSpaceController.clear();
    });

    try {
      final question = await _geminiService.generateQuestion(
        examType: widget.examType,
        subject: widget.subject,
        topic: widget.topic,
        difficulty: widget.difficulty,
      );
      setState(() {
        _currentQuestion = question;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// Submit the selected answer and record the attempt in Firebase
  Future<void> _submitAnswer() async {
    if (_selectedAnswer == null || _currentQuestion == null) return;

    final isCorrect = _selectedAnswer == _currentQuestion!.correctAnswer;

    setState(() {
      _showExplanation = true;
      _isSubmitting = true;
    });

    // Record to Firebase (fire-and-forget; errors are swallowed gracefully)
    try {
      await _progressService.recordAttempt(
        examType: widget.examType,
        subject: widget.subject,
        topic: widget.topic,
        difficulty: widget.difficulty,
        isCorrect: isCorrect,
        questionId: _currentQuestion!.id,
      );
    } catch (e) {
      // Non-fatal — don't break the UX if Firebase is unreachable
      debugPrint('Progress tracking error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCorrect
                ? '✓ Correct!'
                : '✗ Incorrect. Answer: ${_currentQuestion!.correctAnswer}',
          ),
          backgroundColor: isCorrect ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _toggleListening() => setState(() => _isListening = !_isListening);

  void _sendToAI() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sending to AI: $_spokenText')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          '${widget.topic} - ${widget.difficulty}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Question Card ──────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : _errorMessage != null
                          ? _buildErrorState()
                          : _currentQuestion == null
                              ? const Center(
                                  child: Text('Loading your first question…'),
                                )
                              : _buildQuestionContent(),
                ),

                const SizedBox(height: 20),

                // ── Working Space ──────────────────────────────
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Working Space',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextField(
                          controller: _workingSpaceController,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            hintText: 'Write your working here…',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.all(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── AI Voice Help ──────────────────────────────
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.psychology, color: Colors.purple.shade700),
                            const SizedBox(width: 8),
                            const Text(
                              'Ask AI with Voice',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            if (_spokenText.isNotEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(_spokenText),
                              ),
                            GestureDetector(
                              onTap: _toggleListening,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                decoration: BoxDecoration(
                                  color: _isListening
                                      ? Colors.red.shade50
                                      : Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _isListening
                                        ? Colors.red
                                        : Colors.purple.shade300,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: _isListening
                                            ? Colors.red
                                            : Colors.purple,
                                        shape: BoxShape.circle,
                                        boxShadow: _isListening
                                            ? [
                                                BoxShadow(
                                                  color: Colors.red
                                                      .withOpacity(0.4),
                                                  blurRadius: 20,
                                                  spreadRadius: 5,
                                                )
                                              ]
                                            : [],
                                      ),
                                      child: Icon(
                                        _isListening
                                            ? Icons.mic
                                            : Icons.mic_none,
                                        size: 40,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _isListening
                                          ? 'Listening… Tap to stop'
                                          : 'Tap to speak',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: _isListening
                                            ? Colors.red.shade700
                                            : Colors.purple.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_spokenText.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          setState(() => _spokenText = ''),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade300,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text(
                                        'Clear',
                                        style: TextStyle(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton(
                                      onPressed: _sendToAI,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.purple,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text(
                                        'Get AI Help',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Next / Submit Buttons ──────────────────────
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (_isLoading || _isSubmitting)
                            ? null
                            : _loadNextQuestion,
                        icon: const Icon(Icons.skip_next, color: Colors.white),
                        label: Text(
                          _isLoading ? 'Loading…' : 'Next Question',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (_selectedAnswer != null &&
                                !_isLoading &&
                                !_isSubmitting &&
                                !_showExplanation)
                            ? _submitAnswer
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Submit',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Column(
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 16),
        Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.red),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _loadNextQuestion,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
        ),
      ],
    );
  }

  Widget _buildQuestionContent() {
    final q = _currentQuestion!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Question',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: widget.difficulty == 'Beginner'
                    ? Colors.green.shade100
                    : widget.difficulty == 'Intermediate'
                        ? Colors.orange.shade100
                        : Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.difficulty,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: widget.difficulty == 'Beginner'
                      ? Colors.green.shade700
                      : widget.difficulty == 'Intermediate'
                          ? Colors.orange.shade700
                          : Colors.red.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          q.question,
          style: const TextStyle(
              fontSize: 16, color: Colors.black87, height: 1.5),
        ),
        const SizedBox(height: 20),
        ...List.generate(q.options.length, (i) {
          final label = String.fromCharCode(65 + i);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildOption(label, q.options[i]),
          );
        }),
        if (_showExplanation && q.explanation.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Explanation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  q.explanation,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black87, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOption(String label, String text) {
    final isSelected = _selectedAnswer == label;
    return InkWell(
      onTap: _showExplanation
          ? null // Lock after submission
          : () => setState(() => _selectedAnswer = label),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}