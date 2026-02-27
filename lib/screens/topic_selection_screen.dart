import 'package:flutter/material.dart';
import '../utils (Helper Function)/app_theme.dart';
import '../utils (Helper Function)/exam_data.dart';
import 'difficulty_selection_screen.dart';

class TopicSelectionScreen extends StatelessWidget {
  final String country;
  final String examType;
  final String subject;

  const TopicSelectionScreen({
    super.key,
    required this.country,
    required this.examType,
    required this.subject,
  });

  @override
  Widget build(BuildContext context) {
    final topics = ExamDatabase.getTopics(examType, subject);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppTheme.gradientAppBar(title: subject),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'Select a topic to practise',
                style: AppTheme.caption,
              ),
            ),
            Expanded(
              child: topics.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: topics.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TopicCard(
                          topic: topics[index],
                          index: index,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DifficultySelectionScreen(
                                country: country,
                                examType: examType,
                                subject: subject,
                                topic: topics[index],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔍', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text(
            'No topics available yet',
            style: AppTheme.sectionTitle,
          ),
          const SizedBox(height: 8),
          Text(
            'Check back soon!',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  final String topic;
  final int index;
  final VoidCallback onTap;

  const _TopicCard({
    required this.topic,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.radiusMd,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: AppTheme.radiusMd,
            boxShadow: AppTheme.softShadow,
          ),
          child: Row(
            children: [
              // Index bubble
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  topic,
                  style: AppTheme.cardTitle,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios,
                  size: 13,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}