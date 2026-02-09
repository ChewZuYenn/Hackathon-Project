import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final difficulties = [
      {'level': 'Beginner', 'color': const Color(0xFFC8E6C9)},
      {'level': 'Intermediate', 'color': const Color(0xFFFFE082)},
      {'level': 'Advance', 'color': const Color(0xFFB3E5FC)},
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '$topic - Select Difficulty',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose difficulty level for $topic',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: difficulties.map((diff) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: _buildDifficultyCard(
                          context,
                          diff['level'] as String,
                          diff['color'] as Color,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyCard(
    BuildContext context,
    String level,
    Color color,
  ) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuestionScreen(
              country: country,
              examType: examType,
              subject: subject,
              topic: topic,
              difficulty: level,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.black26,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          level,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}