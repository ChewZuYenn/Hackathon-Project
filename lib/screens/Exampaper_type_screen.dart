import 'package:flutter/material.dart';
import '../utils (Helper Function)/app_theme.dart';
import '../widgets/exam_countryButton.dart';
import '../widgets/exam_typeButton.dart';
import 'subject_selection_screen.dart';

class CountrySelectionScreen extends StatelessWidget {
  const CountrySelectionScreen({super.key});

  static const _countries = [
    _CountryData('UK',        '🇬🇧', ['IGCSE', 'GCSE', 'A-LEVEL', 'EdEXCEL']),
    _CountryData('US',        '🇺🇸', ['SAT',   'PSAT',  'ACT',     'AP']),
    _CountryData('Australia', '🇦🇺', ['ATAR',  'HSC',   'VCE',     'QCE']),
    _CountryData('Malaysia',  '🇲🇾', ['SPM',   'STPM',  'Matrikulasi', 'UPSR']),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // Hero gradient header 
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.primaryDark,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: const Text(
                'Choose your exam',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 50),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🎓 AEexam',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Select your country and exam type to begin',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Country sections
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _CountrySection(
                    data: _countries[index],
                    onExamTap: (examType) => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubjectSelectionScreen(
                          country: _countries[index].name,
                          examType: examType,
                        ),
                      ),
                    ),
                  ),
                ),
                childCount: _countries.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Data

class _CountryData {
  final String name;
  final String flag;
  final List<String> exams;
  const _CountryData(this.name, this.flag, this.exams);
}

// Country Section 

class _CountrySection extends StatelessWidget {
  final _CountryData data;
  final void Function(String examType) onExamTap;

  const _CountrySection({required this.data, required this.onExamTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: AppTheme.radiusMd,
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Country header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Text(data.flag, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Text(
                  data.name,
                  style: AppTheme.sectionTitle,
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          // Exam type chips
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: data.exams.map((e) => _ExamChip(
                exam: e,
                onTap: () => onExamTap(e),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// Exam Chip

class _ExamChip extends StatelessWidget {
  final String exam;
  final VoidCallback onTap;

  const _ExamChip({required this.exam, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            exam,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}