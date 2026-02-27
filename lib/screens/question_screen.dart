import 'package:flutter/material.dart';
import '../model (Data Model)/question.dart';
import '../services (API call etc)/gemini_service.dart';
import '../services (API call etc)/progress_tracking_service.dart';
import '../controller/voice_tutor_controller.dart';
import '../widgets/voice_tutor_panel.dart';
import '../widgets/drawing_canvas.dart';
import '../utils (Helper Function)/app_theme.dart';

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
    _voiceTutorController = VoiceTutorController()
      ..examContext = {
        'examType': widget.examType,
        'subject':  widget.subject,
        'topic':    widget.topic,
      };
    _voiceTutorController.loadHistory();
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
          content: Row(
            children: [
              Text(isCorrect ? '✅' : '❌', style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isCorrect
                      ? 'Correct! Well done.'
                      : 'Incorrect — correct answer: ${_currentQuestion!.correctAnswer}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: isCorrect ? AppTheme.success : AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusSm),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Build 

  @override
  Widget build(BuildContext context) {
    final diffColor = AppTheme.difficultyColor(widget.difficulty);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          '${widget.topic}  ·  ${widget.difficulty}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question Card 
              _card(
                child: _isLoading
                    ? const _LoadingWidget()
                    : _errorMessage != null
                        ? _buildErrorState()
                        : _currentQuestion == null
                            ? const Center(child: Text('Loading your first question…'))
                            : _buildQuestionContent(diffColor),
              ),

              const SizedBox(height: 16),

              // Working Space 
              _card(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.only(
                          topLeft:  Radius.circular(14),
                          topRight: Radius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.edit_note, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Working Space',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          _modeToggle(),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: _isHandwritingMode
                          ? const DrawingCanvas(height: 180)
                          : TextField(
                              controller: _workingSpaceController,
                              maxLines: 7,
                              style: const TextStyle(fontSize: 14, height: 1.5),
                              decoration: InputDecoration(
                                hintText: 'Write your working here…',
                                hintStyle: TextStyle(color: Colors.grey.shade400),
                                border: OutlineInputBorder(
                                  borderRadius: AppTheme.radiusSm,
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: AppTheme.radiusSm,
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: AppTheme.radiusSm,
                                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFFAFAFF),
                                contentPadding: const EdgeInsets.all(12),
                              ),
                            ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Voice AI Tutor Panel 
              VoiceTutorPanel(controller: _voiceTutorController),

              const SizedBox(height: 20),

              //Action Buttons 
              Row(
                children: [
                  Expanded(
                    child: _GradientButton(
                      label: _isLoading ? 'Loading…' : 'Next Question',
                      icon: Icons.skip_next,
                      onPressed: (_isLoading || _isSubmitting) ? null : _loadNextQuestion,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OutlineButton(
                      label: 'Submit',
                      onPressed: (_selectedAnswer != null &&
                              !_isLoading &&
                              !_isSubmitting &&
                              !_showExplanation)
                          ? _submitAnswer
                          : null,
                      isLoading: _isSubmitting,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Helpers 

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration,
      child: child,
    );
  }

  Widget _modeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleBtn(Icons.keyboard, 'Type', !_isHandwritingMode),
          _toggleBtn(Icons.draw, 'Draw', _isHandwritingMode),
        ],
      ),
    );
  }

  Widget _toggleBtn(IconData icon, String label, bool active) {
    return GestureDetector(
      onTap: () => setState(
        () => _isHandwritingMode = (label == 'Draw'),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? AppTheme.primary : Colors.white70),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? AppTheme.primary : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Column(
      children: [
        const Text('⚠️', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 16),
        _GradientButton(
          label: 'Try Again',
          icon: Icons.refresh,
          onPressed: _loadNextQuestion,
        ),
      ],
    );
  }

  Widget _buildQuestionContent(Color diffColor) {
    final q = _currentQuestion!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Question',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
                letterSpacing: 0.8,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: diffColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppTheme.difficultyEmoji(widget.difficulty),
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.difficulty,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: diffColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),
        // Question text
        Text(q.question, style: AppTheme.body),
        const SizedBox(height: 20),

        // Options
        ...List.generate(q.options.length, (i) {
          final label = String.fromCharCode(65 + i);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildOption(label, q.options[i]),
          );
        }),

        // Explanation
        if (_showExplanation && q.explanation.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: AppTheme.radiusSm,
              border: Border.all(
                color: AppTheme.primary.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('💡', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Text(
                      'Explanation',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  q.explanation,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                    height: 1.5,
                  ),
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
      borderColor = AppTheme.success;
      bgColor     = AppTheme.success.withOpacity(0.07);
      circleColor = AppTheme.success;
    } else if (isWrongSelection) {
      borderColor = AppTheme.error;
      bgColor     = AppTheme.error.withOpacity(0.07);
      circleColor = AppTheme.error;
    } else if (isSelected) {
      borderColor = AppTheme.primary;
      bgColor     = AppTheme.primaryLight;
      circleColor = AppTheme.primary;
    } else {
      borderColor = const Color(0xFFE8E8F0);
      bgColor     = Colors.white;
      circleColor = const Color(0xFFD0D0E8);
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
      borderRadius: AppTheme.radiusSm,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: AppTheme.radiusSm,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 30,
              height: 30,
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
                        : AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Shared button widgets

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppTheme.radiusSm,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            gradient: disabled
                ? null
                : AppTheme.primaryGradient,
            color: disabled ? Colors.grey.shade200 : null,
            borderRadius: AppTheme.radiusSm,
            boxShadow: disabled ? null : [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: disabled ? Colors.grey : Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: disabled ? Colors.grey : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _OutlineButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppTheme.radiusSm,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppTheme.radiusSm,
            border: Border.all(
              color: disabled
                  ? Colors.grey.shade300
                  : AppTheme.success,
              width: 1.5,
            ),
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.success,
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: disabled ? Colors.grey.shade400 : AppTheme.success,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          CircularProgressIndicator(color: AppTheme.primary),
          SizedBox(height: 16),
          Text('Generating your question…', style: AppTheme.caption),
        ],
      ),
    );
  }
}