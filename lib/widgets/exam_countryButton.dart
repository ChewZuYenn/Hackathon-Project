import 'package:flutter/material.dart';
import '../widgets/exam_typeButton.dart';

class CountryButton extends StatelessWidget {
  final String countryName;
  final VoidCallback onTap;

  const CountryButton({
    super.key,
    required this.countryName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blueAccent, width: 2),
        ),
        child: Text(
          countryName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.blueAccent,
          ),
        ),
      ),
    );
  }
}

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
                'Choose your exam paper type',
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
                        ExamTypeData('UEC', const Color(0xFFFFCC80)),
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
                  // Navigate to exam papers screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Selected: $country - ${examType.name}'),
                      duration: const Duration(seconds: 1),
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