import 'package:flutter/material.dart';
import '../widgets/exam_countryButton.dart';
import '../widgets/exam_typeButton.dart';
import 'subject_selection_screen.dart';

class CountrySelectionScreen extends StatelessWidget {
  const CountrySelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Select Your Education System',
          style: TextStyle(
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
              const Text(
                'Choose your country and exam type',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                  children: [
                    _buildCountryColumn(
                      context,
                      'UK',
                      [
                        ExamTypeData('IGCSE', const Color(0xFFFFE0B2)),
                        ExamTypeData('GCSE', const Color(0xFFFFE0B2)),
                        ExamTypeData('A-LEVEL', const Color(0xFFFFE0B2)),
                        ExamTypeData('EdEXCEL', const Color(0xFFFFE0B2)),
                      ],
                    ),
                    _buildCountryColumn(
                      context,
                      'US',
                      [
                        ExamTypeData('SAT', const Color(0xFFFFCC80)),
                        ExamTypeData('PSAT', const Color(0xFFFFCC80)),
                        ExamTypeData('ACT', const Color(0xFFFFCC80)),
                        ExamTypeData('AP', const Color(0xFFFFCC80)),
                      ],
                    ),
                    _buildCountryColumn(
                      context,
                      'Australia',
                      [
                        ExamTypeData('ATAR', const Color(0xFFFFE0B2)),
                        ExamTypeData('HSC', const Color(0xFFFFE0B2)),
                        ExamTypeData('VCE', const Color(0xFFFFE0B2)),
                        ExamTypeData('QCE', const Color(0xFFFFE0B2)),
                      ],
                    ),
                    _buildCountryColumn(
                      context,
                      'Malaysia',
                      [
                        ExamTypeData('SPM', const Color(0xFFFFCC80)),
                        ExamTypeData('STPM', const Color(0xFFFFCC80)),
                        ExamTypeData('Matrikulasi', const Color(0xFFFFCC80)),
                        ExamTypeData('UPSR', const Color(0xFFFFCC80)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountryColumn(
    BuildContext context,
    String country,
    List<ExamTypeData> examTypes,
  ) {
    return Column(
      children: [
        CountryButton(
          countryName: country,
          onTap: () {
            // Handle country selection if needed
          },
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: examTypes.map((examType) {
              return ExamTypeButton(
                examName: examType.name,
                color: examType.color,
                onTap: () {
                  // Navigate to subject selection screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SubjectSelectionScreen(
                        country: country,
                        examType: examType.name,
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class ExamTypeData {
  final String name;
  final Color color;

  ExamTypeData(this.name, this.color);
}