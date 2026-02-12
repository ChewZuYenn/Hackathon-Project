import 'package:flutter/material.dart';
import '../services (API call etc)/progress_tracking_service.dart';
import '../utils (Helper Function)/exam_data.dart';
import 'difficulty_selection_screen.dart';

class AdaptiveTopicScreen extends StatefulWidget {
  final String country;
  final String examType;
  final String subject;

  const AdaptiveTopicScreen({
    super.key,
    required this.country,
    required this.examType,
    required this.subject,
  });

  @override
  State<AdaptiveTopicScreen> createState() => _AdaptiveTopicScreenState();
}

class _AdaptiveTopicScreenState extends State<AdaptiveTopicScreen> {
  final ProgressTrackingService _progressService = ProgressTrackingService();
  bool _isLoading = false;

  Future<void> _selectAdaptiveTopic() async {
    setState(() => _isLoading = true);

    try {
      final topics = ExamDatabase.getTopics(widget.examType, widget.subject);

      if (topics.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No topics available for this subject.')),
          );
        }
        return;
      }

      final selectedTopic = await _progressService.selectNextTopicWeighted(
        examType: widget.examType,
        subject: widget.subject,
        availableTopics: topics,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DifficultySelectionScreen(
              country: widget.country,
              examType: widget.examType,
              subject: widget.subject,
              topic: selectedTopic,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting topic: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '${widget.subject} — Adaptive Practice',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.psychology, size: 100, color: Colors.blue),
              const SizedBox(height: 30),
              const Text(
                'Adaptive Learning',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'We analyse your past performance and pick the topic where you need the most practice.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _selectAdaptiveTopic,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Start Adaptive Practice',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}