import 'package:flutter/material.dart';
import '../model (Data Model)/question.dart';
import '../services (API call etc)/gemini_service.dart';
import '../services (API call etc)/progress_tracking_service.dart';
import '../controller/voice_tutor_controller.dart';
import '../widgets/voice_tutor_panel.dart';
import '../widgets/drawing_canvas.dart';

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
  final GeminiQuestionService  _geminiService         = GeminiQuestionService();
  final ProgressTrackingService _progressService      = ProgressTrackingService();

  // Voice tutor controller (owns mic, STT, AI, TTS)
  late final VoiceTutorController _voiceTutorController;

  String? _selectedAnswer;
  Question? _currentQuestion;
  bool _isLoading     = false;
  bool _isSubmitting  = false;
  String? _errorMessage;
  bool _showExplanation = false;
  bool _isHandwritingMode = false;

  @override
  void initState() {
    super.initState();

    // Create controller first so listeners and questionText can be set
    _voiceTutorController = VoiceTutorController()
      ..examContext = {
        'examType': widget.examType,
        'subject':  widget.subject,
        'topic':    widget.topic,
      };

    // Load persisted conversation history from local storage
    _voiceTutorController.loadHistory();

    // Keep working space in sync with the controller at all times
    _workingSpaceController.addListener(() {
      _voiceTutorController.workingSpaceText = _workingSpaceController.text;
    });

    _loadNextQuestion();
  }

  @override
  void dispose() {
    _workingSpaceController.dispose();
    _voiceTutorController.dispose();
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
        examType:   widget.examType,
        subject:    widget.subject,
        topic:      widget.topic,
        difficulty: widget.difficulty,
      );
      setState(() {
        _currentQuestion = question;
        _isLoading = false;
        // Update controller with the new question text so AI has full context
        _voiceTutorController.questionText = question.question;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _submitAnswer() async {
    if (_selectedAnswer == null || _currentQuestion == null) return;

    final isCorrect =
        _selectedAnswer!.trim() == _currentQuestion!.correctAnswer.trim();

    setState(() {
      _showExplanation = true;
      _isSubmitting = true;
    });

    try {
      await _progressService.recordAttempt(
        examType:   widget.examType,
        subject:    widget.subject,
        topic:      widget.topic,
        difficulty: widget.difficulty,
        isCorrect:  isCorrect,
        questionId: _currentQuestion!.id,
      );
    } catch (e) {
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
                : '✗ Incorrect. Correct answer: ${_currentQuestion!.correctAnswer}',
          ),
          backgroundColor: isCorrect ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
                // Question Card 
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
                              ? const Center(child: Text('Loading your first question…'))
                              : _buildQuestionContent(),
                ),

                const SizedBox(height: 20),

                //Working Space
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: const BorderRadius.only(
                            topLeft:  Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Working Space',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(value: false, icon: Icon(Icons.keyboard), label: Text('Type')),
                                ButtonSegment(value: true, icon: Icon(Icons.draw), label: Text('Draw')),
                              ],
                              selected: {_isHandwritingMode},
                              onSelectionChanged: (Set<bool> newSelection) {
                                setState(() {
                                  _isHandwritingMode = newSelection.first;
                                });
                              },
                              style: SegmentedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _isHandwritingMode
                            ? const DrawingCanvas(height: 180)
                            : TextField(
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

                //Voice AI Tutor Panel
                VoiceTutorPanel(controller: _voiceTutorController),

                const SizedBox(height: 20),

                //Next / Submit Buttons
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

  //Helpers

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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    Icon(Icons.lightbulb_outline, color: Colors.blue.shade700),
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
    final isSelected = _selectedAnswer == text;
    final isCorrectOption = _showExplanation &&
        text.trim() == _currentQuestion?.correctAnswer.trim();
    final isWrongSelection =
        _showExplanation && isSelected && !isCorrectOption;

    Color borderColor;
    Color bgColor;
    Color circleColor;

    if (isCorrectOption) {
      borderColor = Colors.green;
      bgColor     = Colors.green.shade50;
      circleColor = Colors.green;
    } else if (isWrongSelection) {
      borderColor = Colors.red;
      bgColor     = Colors.red.shade50;
      circleColor = Colors.red;
    } else if (isSelected) {
      borderColor = Colors.blue;
      bgColor     = Colors.blue.shade50;
      circleColor = Colors.blue;
    } else {
      borderColor = Colors.grey.shade300;
      bgColor     = Colors.grey.shade50;
      circleColor = Colors.grey.shade300;
    }

    final String circleLabel = isCorrectOption
        ? '✓'
        : isWrongSelection
            ? '✗'
            : label;

    return InkWell(
      onTap: _showExplanation
          ? null
          : () => setState(() => _selectedAnswer = text),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  circleLabel,
                  style: TextStyle(
                    color: (isSelected || isCorrectOption || isWrongSelection)
                        ? Colors.white
                        : Colors.black87,
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