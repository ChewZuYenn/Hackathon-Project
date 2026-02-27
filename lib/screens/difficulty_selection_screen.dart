import 'package:flutter/material.dart';
import '../utils (Helper Function)/app_theme.dart';
import 'question_screen.dart';

class DifficultySelectionScreen extends StatelessWidget {
  final String country;
  final String examType;
  final String subject;
  final String topic;

  const DifficultySelectionScreen({
    super.key,
    required this.country,
    required this.examType,
    required this.subject,
    required this.topic,
  });

  static const _difficulties = ['Beginner', 'Intermediate', 'Advance'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppTheme.gradientAppBar(title: topic),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text('Choose your difficulty level', style: AppTheme.caption),
              const SizedBox(height: 24),
              Expanded(
                child: Column(
                  children: _difficulties.map((level) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _DifficultyCard(
                        level: level,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuestionScreen(
                              country: country,
                              examType: examType,
                              subject: subject,
                              topic: topic,
                              difficulty: level,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final String level;
  final VoidCallback onTap;

  const _DifficultyCard({required this.level, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.difficultyColor(level);
    final emoji = AppTheme.difficultyEmoji(level);
    final desc  = AppTheme.difficultyDescription(level);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.radiusLg,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: AppTheme.radiusLg,
            boxShadow: AppTheme.cardShadow,
            border: Border.all(
              color: color.withOpacity(0.25),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
          child: Row(
            children: [
              // Emoji badge
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      level,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: AppTheme.caption,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.chevron_right, color: color, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}