import 'package:flutter/material.dart';
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
    // Get real topics for this exam type and subject
    final topics = ExamDatabase.getTopics(examType, subject);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '$subject - Select Topic',
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
                'Choose a topic in $subject',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: topics.isEmpty
                    ? const Center(
                        child: Text(
                          'No topics available for this subject yet.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: topics.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: _buildTopicCard(
                              context,
                              topics[index],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopicCard(BuildContext context, String topic) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DifficultySelectionScreen(
              country: country,
              examType: examType,
              subject: subject,
              topic: topic,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E5F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.purple.shade200,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                topic,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.black54,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}