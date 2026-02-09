import 'package:flutter/material.dart';
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
    // Get the correct subject list based on exam type
    final subjects = ExamDatabase.getSubjects(examType);
    final isTestSections = ExamDatabase.isTestSections(examType);
    

    // Handle case where exam type is not found
    if (subjects.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('$examType - Error'),
        ),
        body: Center(
          child: Text('No subjects found for $examType'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isTestSections 
            ? '$examType - Select Section' 
            : '$examType - Select Subject',
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
                isTestSections
                  ? 'Choose your test section for $examType'
                  : 'Choose your subject for $examType',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: subjects.length,
                  itemBuilder: (context, index) {
                    return _buildSubjectCard(
                      context,
                      subjects[index],
                      isTestSections,
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

  Widget _buildSubjectCard(
    BuildContext context, 
    String subject,
    bool isTestSection,
  ) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TopicSelectionScreen(
              country: country,
              examType: examType,
              subject: subject,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.blue.shade200,
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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              subject,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}