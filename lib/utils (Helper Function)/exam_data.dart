class ExamData {
  final String title;
  final String country;
  final List<String> items;
  final bool isTestSections; // true for SAT/PSAT/ACT

  ExamData({
    required this.title,
    required this.country,
    required this.items,
    this.isTestSections = false,
  });
}

class ExamDatabase {
  static final Map<String, ExamData> _examMap = {
    // UK Exams
    'IGCSE': ExamData(
      title: 'IGCSE',
      country: 'UK',
      items: [
        'English Language',
        'English Literature',
        'Mathematics',
        'Additional Mathematics',
        'Biology',
        'Chemistry',
        'Physics',
        'Combined Science',
        'Computer Science/ICT',
        'Business',
        'Economics',
        'Accounting',
        'Geography',
        'History',
        'Art & Design',
        'Foreign Language',
      ],
    ),
    'GCSE': ExamData(
      title: 'GCSE',
      country: 'UK',
      items: [
        'English Language',
        'English Literature',
        'Mathematics',
        'Combined Science',
        'Biology',
        'Chemistry',
        'Physics',
        'Computer Science',
        'Business',
        'Economics',
        'Geography',
        'History',
        'Religious Studies',
        'Art & Design',
        'Design & Technology',
        'PE',
      ],
    ),
    'A-LEVEL': ExamData(
      title: 'A-Level',
      country: 'UK',
      items: [
        'Mathematics',
        'Further Mathematics',
        'Biology',
        'Chemistry',
        'Physics',
        'Computer Science',
        'Economics',
        'Business',
        'Accounting',
        'Psychology',
        'Law',
        'History',
        'Geography',
      ],
    ),
    'EdEXCEL': ExamData(
      title: 'Edexcel (International)',
      country: 'UK',
      items: [
        'IGCSE Subjects',
        'A-Level Subjects',
        'International GCSE',
      ],
    ),

    // US Exams
    'SAT': ExamData(
      title: 'SAT',
      country: 'US',
      items: [
        'Reading & Writing',
        'Math',
      ],
      isTestSections: true,
    ),
    'PSAT': ExamData(
      title: 'PSAT',
      country: 'US',
      items: [
        'Reading & Writing',
        'Math',
      ],
      isTestSections: true,
    ),
    'ACT': ExamData(
      title: 'ACT',
      country: 'US',
      items: [
        'English',
        'Math',
        'Reading',
        'Science',
        'Writing (optional)',
      ],
      isTestSections: true,
    ),
    'AP': ExamData(
      title: 'AP',
      country: 'US',
      items: [
        'AP Calculus',
        'AP Statistics',
        'AP Biology',
        'AP Chemistry',
        'AP Physics',
        'AP Computer Science',
        'AP Economics',
        'AP Psychology',
        'AP World History',
        'AP Government',
        'AP English',
      ],
    ),

    // Australia Exams
    'ATAR': ExamData(
      title: 'ATAR',
      country: 'Australia',
      items: [
        'English',
        'Mathematics (General)',
        'Mathematics (Methods)',
        'Mathematics (Specialist)',
        'Biology',
        'Chemistry',
        'Physics',
        'Economics',
        'Business',
        'Accounting',
        'Legal Studies',
        'Psychology',
        'Computer Science/IT',
      ],
    ),
    'HSC': ExamData(
      title: 'HSC (New South Wales)',
      country: 'Australia',
      items: [
        'English (Standard/Advanced)',
        'Mathematics (Standard/Advanced/Extension)',
        'Biology',
        'Chemistry',
        'Physics',
        'Economics',
        'Business Studies',
        'Legal Studies',
        'Psychology',
        'Software Design',
      ],
    ),
    'VCE': ExamData(
      title: 'VCE (Victoria)',
      country: 'Australia',
      items: [
        'English',
        'Mathematics (General/Methods/Specialist)',
        'Biology',
        'Chemistry',
        'Physics',
        'Economics',
        'Business Management',
        'Accounting',
        'Legal Studies',
        'Psychology',
        'Computing',
      ],
    ),
    'QCE': ExamData(
      title: 'QCE (Queensland)',
      country: 'Australia',
      items: [
        'English',
        'Mathematics (General/Methods/Specialist)',
        'Biology',
        'Chemistry',
        'Physics',
        'Economics',
        'Business',
        'Accounting',
        'Legal Studies',
        'Psychology',
        'Digital Solutions',
      ],
    ),

    // Malaysia Exams
    'SPM': ExamData(
      title: 'SPM',
      country: 'Malaysia',
      items: [
        'Bahasa Melayu',
        'English',
        'Mathematics',
        'Additional Mathematics',
        'Sejarah',
        'Biology',
        'Chemistry',
        'Physics',
        'Accounting',
        'Business',
        'Economics',
        'Computer Science',
      ],
    ),
    'STPM': ExamData(
      title: 'STPM',
      country: 'Malaysia',
      items: [
        'General Studies',
        'Mathematics',
        'Further Mathematics',
        'Biology',
        'Chemistry',
        'Physics',
        'Economics',
        'Business Studies',
        'Accounting',
      ],
    ),
    'Matrikulasi': ExamData(
      title: 'Matrikulasi',
      country: 'Malaysia',
      items: [
        'Mathematics',
        'Chemistry',
        'Physics',
        'Biology',
        'Accounting',
        'Economics',
        'Business',
      ],
    ),
    'UPSR': ExamData(
      title: 'UPSR',
      country: 'Malaysia',
      items: [
        'Bahasa Melayu',
        'English',
        'Mathematics',
        'Science',
      ],
    ),
  };

  static ExamData? getExamData(String examType) {
    return _examMap[examType];
  }

  static List<String> getSubjects(String examType) {
    return _examMap[examType]?.items ?? [];
  }

  static bool isTestSections(String examType) {
    return _examMap[examType]?.isTestSections ?? false;
  }
}