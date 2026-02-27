import 'package:flutter/material.dart';
import '../utils (Helper Function)/app_theme.dart';
import '../utils (Helper Function)/exam_data.dart';
import 'topic_selection_screen.dart';

class SubjectSelectionScreen extends StatelessWidget {
  final String country;
  final String examType;

  const SubjectSelectionScreen({
    super.key,
    required this.country,
    required this.examType,
  });

  @override
  Widget build(BuildContext context) {
    final subjects = ExamDatabase.getSubjects(examType);
    final isTestSections = ExamDatabase.isTestSections(examType);

    if (subjects.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppTheme.gradientAppBar(title: '$examType — Error'),
        body: const Center(child: Text('No subjects found.')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppTheme.gradientAppBar(
        title: isTestSections ? '$examType — Sections' : '$examType — Subjects',
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sub-header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                isTestSections
                    ? 'Select your test section'
                    : 'Which subject would you like to practise?',
                style: AppTheme.caption,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: subjects.length,
                  itemBuilder: (context, index) =>
                      _SubjectCard(
                        subject: subjects[index],
                        index: index,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TopicSelectionScreen(
                              country: country,
                              examType: examType,
                              subject: subjects[index],
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
}

class _SubjectCard extends StatelessWidget {
  final String subject;
  final int index;
  final VoidCallback onTap;

  const _SubjectCard({
    required this.subject,
    required this.index,
    required this.onTap,
  });

  static const List<Color> _palette = [
    Color(0xFF6C5CE7),
    Color(0xFF00B894),
    Color(0xFF0984E3),
    Color(0xFFE17055),
    Color(0xFFD63031),
    Color(0xFF6C5CE7),
    Color(0xFF00CEC9),
    Color(0xFFFDAB00),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _palette[index % _palette.length];
    final icon = AppTheme.subjectIcon(subject);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.radiusMd,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: AppTheme.radiusMd,
            boxShadow: AppTheme.cardShadow,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    icon,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                subject,
                style: AppTheme.cardTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('Practise', style: TextStyle(fontSize: 12, color: color)),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_forward, size: 12, color: color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}