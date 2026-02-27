import 'package:flutter/material.dart';

class AppTheme {
  // Brand Palette 
  static const Color primary = Color(0xFF6C5CE7);       // vivid violet
  static const Color primaryDark = Color(0xFF4834D4);   // deep violet
  static const Color primaryLight = Color(0xFFEDE9FF);  // lavender tint

  static const Color success = Color(0xFF00B894);       // mint green
  static const Color warning = Color(0xFFFFAB00);       // warm amber
  static const Color error = Color(0xFFFF6584);         // soft coral

  static const Color surface = Colors.white;
  static const Color background = Color(0xFFF5F4FF);    // lavender-white
  static const Color cardBg = Colors.white;

  static const Color textPrimary = Color(0xFF2D3748);   // dark slate
  static const Color textSecondary = Color(0xFF718096); // medium grey
  static const Color textMuted = Color(0xFFA0AEC0);     // light grey

  // Difficulty Colours  
  static const Color beginnerColor = Color(0xFF00B894);
  static const Color intermediateColor = Color(0xFFFFAB00);
  static const Color advancedColor = Color(0xFFFF6584);

  // Gradients 
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFF8E7CF3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF4834D4), Color(0xFF6C5CE7), Color(0xFF8E7CF3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shadows 
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF6C5CE7).withOpacity(0.10),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // Border Radius 
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(20));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(14));
  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(10));

  // Card Decoration 
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: cardBg,
    borderRadius: radiusMd,
    boxShadow: cardShadow,
  );

  // Text Styles 
  static const TextStyle screenTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: -0.3,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.2,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    color: textPrimary,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 13,
    color: textSecondary,
  );

  // Difficulty helpers 
  static Color difficultyColor(String level) {
    switch (level.toLowerCase()) {
      case 'beginner':
        return beginnerColor;
      case 'intermediate':
        return intermediateColor;
      default:
        return advancedColor;
    }
  }

  static String difficultyEmoji(String level) {
    switch (level.toLowerCase()) {
      case 'beginner':
        return '🌱';
      case 'intermediate':
        return '⚡';
      default:
        return '🔥';
    }
  }

  static String difficultyDescription(String level) {
    switch (level.toLowerCase()) {
      case 'beginner':
        return 'Build your foundation';
      case 'intermediate':
        return 'Step up the challenge';
      default:
        return 'Push your limits';
    }
  }

  // Subject icon mapping 
  static String subjectIcon(String subject) {
    final s = subject.toLowerCase();
    if (s.contains('math'))       return '📐';
    if (s.contains('physics'))    return '⚛️';
    if (s.contains('chemistry'))  return '🧪';
    if (s.contains('biology'))    return '🧬';
    if (s.contains('english'))    return '📖';
    if (s.contains('history'))    return '🏛️';
    if (s.contains('geography'))  return '🌍';
    if (s.contains('economics'))  return '📊';
    if (s.contains('computer'))   return '💻';
    if (s.contains('science'))    return '🔬';
    if (s.contains('business'))   return '💼';
    if (s.contains('art'))        return '🎨';
    if (s.contains('music'))      return '🎵';
    if (s.contains('language'))   return '🗣️';
    if (s.contains('reading'))    return '📚';
    if (s.contains('writing'))    return '✍️';
    if (s.contains('essay'))      return '📝';
    return '📌';
  }

  // AppBar 
  static AppBar gradientAppBar({
    required String title,
    List<Widget>? actions,
    bool centerTitle = true,
  }) {
    return AppBar(
      title: Text(title, style: screenTitle),
      centerTitle: centerTitle,
      flexibleSpace: Container(decoration: const BoxDecoration(gradient: headerGradient)),
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: actions,
    );
  }
}
