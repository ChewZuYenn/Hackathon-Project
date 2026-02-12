import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services (API call etc)/firebase_service.dart';
import 'screens/Exampaper_type_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Firebase
  await FirebaseService().initialize();

  // Sign in anonymously so Firestore writes work
  await FirebaseService().signInAnonymously();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Education App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const CountrySelectionScreen(),
    );
  }
}